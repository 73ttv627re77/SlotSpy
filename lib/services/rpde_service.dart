import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/slot.dart';
import '../models/session_type.dart';
import '../models/gym.dart';
import 'database_service.dart';

/// Temporary holder for per-gym session data during parallel fetch.
class _GymSessionData {
  final String gymId;
  final String gymName;
  final Set<String> names = {};
  final List<Map<String, dynamic>> data = [];

  _GymSessionData(this.gymId, this.gymName);
}

class RpdeService {
  final DatabaseService _db;
  final String? backendUrl;
  static const String _slotsFeedUrl =
      'https://opendata.leisurecloud.live/api/feeds/EveryoneActive-live-slots';
  static const String _sessionSeriesFeedUrl =
      'https://opendata.leisurecloud.live/api/feeds/EveryoneActive-live-session-series';

  RpdeService(this.backendUrl, this._db);

  Future<List<Slot>> fetchSlots({void Function(int current, int total)? onProgress}) async {
    final allSlots = <Slot>[];
    String? nextUrl;
    int page = 0;

    do {
      final url = nextUrl ?? _slotsFeedUrl;
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) break;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        page++;

        for (final item in items) {
          if (item['state'] == 'updated' || item['data']?['remainingUses'] != null) {
            final slot = Slot.fromRpde(item as Map<String, dynamic>);
            if (slot.id.isNotEmpty) {
              allSlots.add(slot);
            }
          }
        }

        onProgress?.call(page, page);

        // Check if there are more pages
        final next = data['next'];
        if (next == null || next == url || items.isEmpty) {
          break;
        }
        nextUrl = next as String;
      } catch (e) {
        break;
      }
    } while (nextUrl != null);

    // Cache the slots
    if (allSlots.isNotEmpty) {
      await _db.upsertSlots(allSlots);
    }

    return allSlots;
  }

  /// Optional callback fired after each page is converted to SessionTypes.
  /// Use this for incremental UI updates while pagination is in progress.
  /// Callback signature: (pageNumber, cumulativeSessionTypesSoFar)
  void Function(int page, List<SessionType> sessionTypes)? onPageFetched;

  /// Fetch all session series pages in parallel.
  /// 1. Fetch page 1 to get the `next` cursor chain
  /// 2. Walk the chain sequentially to collect all page URLs (fast, cursor-based)
  /// 3. Fetch remaining pages in batches of 4 concurrently, process each immediately
  /// 4. Write per-gym session types to DB when done
  ///
  /// `onProgress(pageFetched, totalPages, gymsFound)` is called after each batch.
  Future<Map<String, List<String>>> fetchAndCacheAllSessionTypesPerGym({
    void Function(int pageFetched, int totalPages, int gymsFound)? onProgress,
    int timeoutSeconds = 60,
  }) async {
    // Use custom backend if configured
    if (backendUrl != null && backendUrl!.isNotEmpty) {
      return _fetchFromCustomBackend(onProgress: onProgress, timeoutSeconds: timeoutSeconds);
    }
    // Default: use OpenActive directly
    final gymData = <String, _GymSessionData>{};

    void processPage(Map<String, dynamic> data) {
      final items = data['items'] as List? ?? [];
      for (final item in items) {
        if (item['data'] == null) continue;
        try {
          final d = item['data'] as Map<String, dynamic>;
          final gym = Gym.fromSessionSeries(d);
          final st = SessionType.fromSessionSeries(d, gym);
          final gd = gymData.putIfAbsent(gym.id, () => _GymSessionData(gym.id, gym.name));
          gd.names.add(st.name);
          gd.data.add(d);
        } catch (_) {}
      }
    }

    // Step 1: fetch page 1
    final r1 = await http.get(Uri.parse(_sessionSeriesFeedUrl)).timeout(
      const Duration(seconds: 30),
    );
    if (r1.statusCode != 200) {
      throw Exception('Session series fetch failed: ${r1.statusCode}');
    }
    final page1Data = jsonDecode(r1.body) as Map<String, dynamic>;
    processPage(page1Data);

    // Step 2: walk the next chain to collect all remaining page URLs
    final pageUrls = <String>[];
    String? nextUrl = page1Data['next'] as String?;
    while (nextUrl != null && nextUrl.isNotEmpty && nextUrl != _sessionSeriesFeedUrl) {
      pageUrls.add(nextUrl);
      final r = await http.get(Uri.parse(nextUrl)).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) break;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      nextUrl = d['next'] as String?;
    }

    // Wrap the entire fetch with a top-level timeout
    await Future.any([
      _fetchAllPages(gymData, page1Data, pageUrls, onProgress),
      Future.delayed(Duration(seconds: timeoutSeconds), () {
        throw Exception('Network timeout \u2014 check your connection');
      }),
    ]);

    // Step 4: write all gyms to DB
    for (final gd in gymData.values) {
      await _db.saveSessionTypesForGym(
        gymId: gd.gymId,
        gymName: gd.gymName,
        sessionTypeNames: gd.names.toList(),
        allData: gd.data,
      );
    }

    return gymData.map((k, v) => MapEntry(k, v.names.toList()));
  }

  /// Fetch from a custom SlotSpyCloud backend.
  /// Backend API: GET {backendUrl}/gyms, GET {backendUrl}/session-types?gym_id=X
  Future<Map<String, List<String>>> _fetchFromCustomBackend({
    void Function(int pageFetched, int totalPages, int gymsFound)? onProgress,
    int timeoutSeconds = 60,
  }) async {
    final base = backendUrl!.replaceAll(RegExp(r'/$'), '');

    // 1. Fetch gym list
    final gymsRes = await http.get(Uri.parse('$base/gyms')).timeout(
      Duration(seconds: timeoutSeconds),
    );
    if (gymsRes.statusCode != 200) {
      throw Exception('Custom backend gyms fetch failed: ${gymsRes.statusCode}');
    }
    final gymsData = jsonDecode(gymsRes.body) as Map<String, dynamic>;
    final gymsList = gymsData['gyms'] as List? ?? [];

    final gymData = <String, _GymSessionData>{};
    int processed = 0;
    final total = gymsList.length;

    // 2. Fetch session types per gym
    for (final gymEntry in gymsList) {
      final gymId = gymEntry['id']?.toString() ?? '';
      final gymName = gymEntry['name']?.toString() ?? 'Unknown';
      if (gymId.isEmpty) continue;

      final typesRes = await http.get(
        Uri.parse('$base/session-types?gym_id=$gymId'),
      ).timeout(Duration(seconds: timeoutSeconds));

      if (typesRes.statusCode == 200) {
        final typesData = jsonDecode(typesRes.body) as Map<String, dynamic>;
        final typesList = typesData['session_types'] as List? ?? [];

        final gd = gymData.putIfAbsent(gymId, () => _GymSessionData(gymId, gymName));
        for (final typeEntry in typesList) {
          try {
            final d = typeEntry as Map<String, dynamic>;
            final gym = Gym.fromSessionSeries(d);
            final st = SessionType.fromSessionSeries(d, gym);
            gd.names.add(st.name);
            gd.data.add(d);
          } catch (_) {}
        }
      }

      processed++;
      onProgress?.call(processed, total, gymData.length);
    }

    return gymData.map((k, v) => MapEntry(k, v.names.toList()));
  }

  Future<void> _fetchAllPages(
    Map<String, _GymSessionData> gymData,
    Map<String, dynamic> page1Data,
    List<String> pageUrls,
    void Function(int pageFetched, int totalPages, int gymsFound)? onProgress,
  ) async {
    const batchSize = 4;

    void processPage(Map<String, dynamic> data) {
      final items = data['items'] as List? ?? [];
      for (final item in items) {
        if (item['data'] == null) continue;
        try {
          final d = item['data'] as Map<String, dynamic>;
          final gym = Gym.fromSessionSeries(d);
          final st = SessionType.fromSessionSeries(d, gym);
          final gd = gymData.putIfAbsent(gym.id, () => _GymSessionData(gym.id, gym.name));
          gd.names.add(st.name);
          gd.data.add(d);
        } catch (_) {}
      }
    }

    // Step 3: fetch remaining pages in bounded concurrent batches, process each immediately
    final totalPages = 1 + pageUrls.length;
    for (int i = 0; i < pageUrls.length; i += batchSize) {
      final urls = pageUrls.skip(i).take(batchSize).toList();
      final results = await Future.wait(urls.map(_fetchPage));
      for (final data in results) {
        if (data != null) processPage(data);
      }
      onProgress?.call(1 + i + batchSize, totalPages, gymData.length);
    }
  }

  Future<Map<String, dynamic>?> _fetchPage(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<SessionType>> fetchSessionSeries({
    void Function(int current, int total)? onProgress,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    String? nextUrl;
    int page = 0;
    bool morePages = true;

    while (morePages) {
      final url = nextUrl ?? _sessionSeriesFeedUrl;
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 15),
        );
        if (response.statusCode != 200) {
          morePages = false;
          break;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        page++;

        for (final item in items) {
          if (item['data'] != null) {
            allItems.add(item as Map<String, dynamic>);
          }
        }

        // Build cumulative SessionTypes so far and fire the callback
        if (onPageFetched != null) {
          final allSessionTypes = <SessionType>[];
          for (final it in allItems) {
            try {
              final gym = Gym.fromSessionSeries(it['data'] as Map<String, dynamic>);
              allSessionTypes.add(SessionType.fromSessionSeries(it['data'] as Map<String, dynamic>, gym));
            } catch (_) {}
          }
          onPageFetched!(page, allSessionTypes);
        }

        final next = data['next'];
        if (next == null || next == url || items.isEmpty) {
          morePages = false;
        } else {
          nextUrl = next as String;
        }
      } catch (e) {
        morePages = false;
      }
    }

    // Cache the full list
    await _db.cacheSessionSeriesList(allItems);

    // Build and return the complete list
    final sessionTypes = <SessionType>[];
    for (final item in allItems) {
      try {
        final gym = Gym.fromSessionSeries(item['data'] as Map<String, dynamic>);
        sessionTypes.add(SessionType.fromSessionSeries(item['data'] as Map<String, dynamic>, gym));
      } catch (_) {}
    }

    return sessionTypes;
  }

  Future<List<Gym>> fetchAndCacheGyms() async {
    final sessionTypes = await fetchSessionSeries();
    final gymMap = <String, Gym>{};
    for (final st in sessionTypes) {
      gymMap[st.gym.id] = st.gym;
    }
    return gymMap.values.toList();
  }

  Future<SessionType?> getSessionTypeForSlot(Slot slot) async {
    // Try to find session series from cache by matching facility prefix
    final allSeries = await _db.getAllSessionSeries();
    final facilityPrefix = _extractFacilityPrefix(slot.facilityUseUrl);

    for (final data in allSeries) {
      try {
        final seriesId = data['@id'] ?? '';
        final seriesPrefix = _extractSeriesPrefix(seriesId);
        if (facilityPrefix.isNotEmpty &&
            seriesPrefix.isNotEmpty &&
            facilityPrefix == seriesPrefix) {
          final gym = Gym.fromSessionSeries(data);
          return SessionType.fromSessionSeries(data, gym);
        }
      } catch (_) {}
    }
    return null;
  }

  String _extractFacilityPrefix(String url) {
    // e.g. "https://dev.myeveryoneactive.com/OpenActive/api/facility-uses/284NETB055SH002"
    final match = RegExp(r'/facility-uses/(\d+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  String _extractSeriesPrefix(String url) {
    // e.g. "https://dev.myeveryoneactive.com/OpenActive/api/session-series/0143B4308000921"
    final match = RegExp(r'/session-series/(\d+)').firstMatch(url);
    return match?.group(1) ?? '';
  }
}

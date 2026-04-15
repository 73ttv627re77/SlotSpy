import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/slot.dart';
import '../models/session_type.dart';
import '../models/gym.dart';
import 'database_service.dart';

class RpdeService {
  final DatabaseService _db;
  static const String _slotsFeedUrl =
      'https://opendata.leisurecloud.live/api/feeds/EveryoneActive-test-slots';
  static const String _sessionSeriesFeedUrl =
      'https://opendata.leisurecloud.live/api/feeds/EveryoneActive-test-session-series';

  RpdeService(this._db);

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

  Future<List<SessionType>> fetchSessionSeries({
    void Function(int current, int total)? onProgress,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    String? nextUrl;
    int page = 0;

    do {
      final url = nextUrl ?? _sessionSeriesFeedUrl;
      try {
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) break;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        page++;

        for (final item in items) {
          if (item['data'] != null) {
            allItems.add(item as Map<String, dynamic>);
          }
        }

        onProgress?.call(page, page);

        final next = data['next'];
        if (next == null || next == url || items.isEmpty) {
          break;
        }
        nextUrl = next as String;
      } catch (e) {
        break;
      }
    } while (nextUrl != null);

    // Cache session series
    await _db.cacheSessionSeriesList(allItems);

    // Convert to SessionType objects
    final sessionTypes = <SessionType>[];
    for (final item in allItems) {
      try {
        final data = item['data'] as Map<String, dynamic>;
        final gym = Gym.fromSessionSeries(data);
        sessionTypes.add(SessionType.fromSessionSeries(data, gym));
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

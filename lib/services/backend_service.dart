import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/slot.dart';
import '../models/watch.dart';

class BackendService {
  final String baseUrl;

  BackendService(this.baseUrl);

  String get _base => baseUrl.replaceAll(RegExp(r'/$'), '');

  /// Calls GET /health and returns true if the backend is reachable.
  Future<bool> testConnection() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// GET /gyms/ — returns raw gym list from backend.
  Future<List<Map<String, dynamic>>> fetchGyms() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/gyms/'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('Backend /gyms/ failed: ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['gyms'] as List? ?? []).cast<Map<String, dynamic>>();
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to fetch gyms: $e');
    }
  }

  /// GET /session-types?gym_id=X — returns raw session types for a gym.
  Future<List<Map<String, dynamic>>> fetchSessionTypes(String gymId) async {
    final res = await http
        .get(Uri.parse('$_base/session-types').replace(queryParameters: {'gym_id': gymId}))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Backend /session-types failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['session_types'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /slots or GET /slots?gym_id=X — returns available slots.
  Future<List<Slot>> fetchSlots({String? gymId}) async {
    final uri = gymId != null
        ? Uri.parse('$_base/slots').replace(queryParameters: {'gym_id': gymId})
        : Uri.parse('$_base/slots');
    final res = await http
        .get(uri)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Backend /slots failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final slotsList = data['slots'] as List? ?? [];
    return slotsList
        .map((s) => _slotFromBackend(s as Map<String, dynamic>))
        .toList();
  }

  Slot _slotFromBackend(Map<String, dynamic> s) {
    DateTime parseDate(String? v) =>
        v != null ? DateTime.tryParse(v) ?? DateTime.now() : DateTime.now();

    final startDate = parseDate(s['start_date']?.toString());
    final endDate = parseDate(s['end_date']?.toString());

    return Slot(
      id: s['id']?.toString() ?? '',
      sessionSeriesId: s['session_series_id']?.toString() ?? '',
      startDate: startDate,
      endDate: endDate,
      duration: endDate.difference(startDate),
      remainingUses: (s['remaining_uses'] as int?) ?? 0,
      maximumUses: (s['maximum_uses'] as int?) ?? 1,
      facilityUseUrl: s['facility_use_url']?.toString() ?? '',
      bookingUrl: s['booking_url']?.toString(),
    );
  }

  /// POST /watches/ — registers a watch on the backend.
  Future<void> registerWatch(Watch watch) async {
    final res = await http
        .post(
          Uri.parse('$_base/watches/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(watch.toJson()),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) {
      throw Exception('Backend /watches/ POST failed: ${res.statusCode}');
    }
  }

  /// GET /watches/ — lists watches registered on the backend.
  Future<List<Map<String, dynamic>>> listWatches() async {
    final res = await http
        .get(Uri.parse('$_base/watches/'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Backend /watches/ GET failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['watches'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /devices/ — registers an APNs device token with the backend.
  Future<void> registerDevice({required String token, required String platform}) async {
    final res = await http
        .post(
          Uri.parse('$_base/devices/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token, 'platform': platform}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) {
      throw Exception('Backend /devices/ POST failed: ${res.statusCode}');
    }
  }
}

import 'package:flutter/material.dart';

class Slot {
  final String id;
  final String sessionSeriesId;
  final DateTime startDate;
  final DateTime endDate;
  final Duration duration;
  final int remainingUses;
  final int maximumUses;
  final String facilityUseUrl;
  final String? bookingUrl;

  Slot({
    required this.id,
    required this.sessionSeriesId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.remainingUses,
    required this.maximumUses,
    required this.facilityUseUrl,
    this.bookingUrl,
  });

  factory Slot.fromRpde(Map<String, dynamic> item) {
    final data = item['data'] ?? {};
    final startDateStr = data['startDate'] ?? '';
    final endDateStr = data['endDate'] ?? '';
    final facilityUse = data['facilityUse'] ?? '';

    DateTime startDate;
    DateTime endDate;
    try {
      startDate = DateTime.parse(startDateStr);
      endDate = DateTime.parse(endDateStr);
    } catch (_) {
      startDate = DateTime.now();
      endDate = DateTime.now();
    }

    final durationStr = data['duration'] ?? 'PT1H';
    final duration = _parseDuration(durationStr);

    return Slot(
      id: data['@id'] ?? item['id'] ?? '',
      sessionSeriesId: _extractSessionSeriesId(facilityUse),
      startDate: startDate,
      endDate: endDate,
      duration: duration,
      remainingUses: data['remainingUses'] ?? 0,
      maximumUses: data['maximumUses'] ?? 1,
      facilityUseUrl: facilityUse,
    );
  }

  static Duration _parseDuration(String iso) {
    try {
      final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
      if (match == null) return const Duration(hours: 1);
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final mins = int.tryParse(match.group(2) ?? '0') ?? 0;
      return Duration(hours: hours, minutes: mins);
    } catch (_) {
      return const Duration(hours: 1);
    }
  }

  static String _extractSessionSeriesId(String facilityUseUrl) {
    // e.g. "https://dev.myeveryoneactive.com/OpenActive/api/facility-uses/284NETB055SH002"
    // Extract the numeric prefix (first 3 digits of facility use id)
    final match = RegExp(r'/facility-uses/(\d+)').firstMatch(facilityUseUrl);
    if (match != null) {
      return match.group(1) ?? '';
    }
    return '';
  }

  String get formattedTime {
    final start = TimeOfDay.fromDateTime(startDate);
    final end = TimeOfDay.fromDateTime(endDate);
    return '${_fmt(start)} - ${_fmt(end)}';
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${startDate.day} ${months[startDate.month - 1]} ${startDate.year}';
  }

  bool get isAvailable => remainingUses >= 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Slot && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

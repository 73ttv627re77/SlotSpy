import 'package:flutter/material.dart' show TimeOfDay;
import 'package:uuid/uuid.dart';

class Watch {
  final String id;
  final String? gymId;
  final String? gymName;
  final String? sessionNamePattern; // single pattern (backward compat)
  final List<String>? sessionPatterns; // list of exact session names to watch
  final Set<int>? daysOfWeek; // 1=Monday, 7=Sunday
  final TimeOfDay? earliestTime;
  final TimeOfDay? latestTime;
  final bool enabled;
  final bool notificationsEnabled;
  final DateTime createdAt;

  Watch({
    String? id,
    this.gymId,
    this.gymName,
    this.sessionNamePattern,
    this.sessionPatterns,
    this.daysOfWeek,
    this.earliestTime,
    this.latestTime,
    this.enabled = true,
    this.notificationsEnabled = true,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Watch copyWith({
    String? gymId,
    String? gymName,
    String? sessionNamePattern,
    List<String>? sessionPatterns,
    Set<int>? daysOfWeek,
    TimeOfDay? earliestTime,
    TimeOfDay? latestTime,
    bool? enabled,
    bool? notificationsEnabled,
  }) {
    return Watch(
      id: id,
      gymId: gymId ?? this.gymId,
      gymName: gymName ?? this.gymName,
      sessionNamePattern: sessionNamePattern ?? this.sessionNamePattern,
      sessionPatterns: sessionPatterns ?? this.sessionPatterns,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      earliestTime: earliestTime ?? this.earliestTime,
      latestTime: latestTime ?? this.latestTime,
      enabled: enabled ?? this.enabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gymId': gymId,
      'gymName': gymName,
      'sessionNamePattern': sessionNamePattern,
      'sessionPatterns': sessionPatterns,
      'daysOfWeek': daysOfWeek?.toList(),
      'earliestTimeHour': earliestTime?.hour,
      'earliestTimeMinute': earliestTime?.minute,
      'latestTimeHour': latestTime?.hour,
      'latestTimeMinute': latestTime?.minute,
      'enabled': enabled,
      'notificationsEnabled': notificationsEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Watch.fromJson(Map<String, dynamic> json) {
    TimeOfDay? earliest;
    if (json['earliestTimeHour'] != null) {
      earliest = TimeOfDay(
        hour: json['earliestTimeHour'] as int,
        minute: json['earliestTimeMinute'] as int? ?? 0,
      );
    }
    TimeOfDay? latest;
    if (json['latestTimeHour'] != null) {
      latest = TimeOfDay(
        hour: json['latestTimeHour'] as int,
        minute: json['latestTimeMinute'] as int? ?? 0,
      );
    }
    return Watch(
      id: json['id'] as String,
      gymId: json['gymId'] as String?,
      gymName: json['gymName'] as String?,
      sessionNamePattern: json['sessionNamePattern'] as String?,
      sessionPatterns: (json['sessionPatterns'] as List?)?.map((e) => e as String).toList(),
      daysOfWeek: (json['daysOfWeek'] as List?)?.map((e) => e as int).toSet(),
      earliestTime: earliest,
      latestTime: latest,
      enabled: json['enabled'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  String get summary {
    final parts = <String>[];
    if (gymName != null && gymName!.isNotEmpty) {
      parts.add(gymName!);
    } else {
      parts.add('Any gym');
    }
    if (sessionNamePattern != null && sessionNamePattern!.isNotEmpty) {
      parts.add(sessionNamePattern!);
    }
    if (sessionPatterns != null && sessionPatterns!.isNotEmpty) {
      parts.add(sessionPatterns!.join(', '));
    }
    if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
      parts.add(_daysSummary(daysOfWeek!));
    }
    if (earliestTime != null || latestTime != null) {
      parts.add(_timeSummary());
    }
    return parts.join(' • ');
  }

  String _daysSummary(Set<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayNames[d - 1]).join(', ');
  }

  String _timeSummary() {
    final start = earliestTime != null
        ? '${earliestTime!.hour.toString().padLeft(2, '0')}:${earliestTime!.minute.toString().padLeft(2, '0')}'
        : '00:00';
    final end = latestTime != null
        ? '${latestTime!.hour.toString().padLeft(2, '0')}:${latestTime!.minute.toString().padLeft(2, '0')}'
        : '23:59';
    return '$start - $end';
  }
}

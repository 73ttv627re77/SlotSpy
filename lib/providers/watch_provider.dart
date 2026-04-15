import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay, DayPeriod;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/watch.dart';
import '../models/slot.dart';
import '../models/session_type.dart';
import '../models/gym.dart';
import '../services/database_service.dart';
import '../services/rpde_service.dart';
import '../services/notification_service.dart';
import '../data/gym_link_bank.dart';

class WatchProvider extends ChangeNotifier {
  final DatabaseService _db;
  final RpdeService _rpde;
  final NotificationService _notifications;

  List<Watch> _watches = [];
  bool _loading = false;

  WatchProvider(this._db, this._rpde, this._notifications);

  List<Watch> get watches => _watches;
  List<Watch> get activeWatches => _watches.where((w) => w.enabled).toList();
  bool get loading => _loading;

  Future<void> loadWatches() async {
    _loading = true;
    notifyListeners();
    try {
      _watches = await _db.getAllWatches();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addWatch(Watch watch) async {
    await _db.saveWatch(watch);
    _watches.insert(0, watch);
    notifyListeners();
  }

  Future<void> updateWatch(Watch watch) async {
    await _db.saveWatch(watch);
    final idx = _watches.indexWhere((w) => w.id == watch.id);
    if (idx >= 0) {
      _watches[idx] = watch;
      notifyListeners();
    }
  }

  Future<void> deleteWatch(String id) async {
    await _db.deleteWatch(id);
    _watches.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  Future<void> toggleWatch(String id) async {
    final idx = _watches.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      final w = _watches[idx];
      final updated = w.copyWith(enabled: !w.enabled);
      await _db.saveWatch(updated);
      _watches[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> clearAllWatches() async {
    await _db.clearAllWatches();
    _watches.clear();
    notifyListeners();
  }
}

class SlotProvider extends ChangeNotifier {
  final DatabaseService _db;
  final RpdeService _rpde;

  List<Slot> _slots = [];
  List<SessionType> _sessionTypes = [];
  List<Gym> _gyms = [];
  bool _loading = false;
  bool _loadingSessionSeries = false;
  String? _error;
  int _pollPage = 0;

  SlotProvider(this._db, this._rpde);

  List<Slot> get slots => _slots;
  List<SessionType> get sessionTypes => _sessionTypes;
  List<Gym> get gyms => _gyms;
  bool get loading => _loading;
  bool get loadingSessionSeries => _loadingSessionSeries;
  String? get error => _error;
  int get pollPage => _pollPage;

  List<Slot> get availableSlots =>
      _slots.where((s) => s.remainingUses >= 1).toList();

  Future<void> fetchSlots() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _slots = await _rpde.fetchSlots(
        onProgress: (current, total) {
          _pollPage = current;
          notifyListeners();
        },
      );
      _pollPage = 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSessionSeries() async {
    _loadingSessionSeries = true;
    notifyListeners();
    try {
      _sessionTypes = await _rpde.fetchSessionSeries();
      _gyms = _sessionTypes.map((s) => s.gym).toSet().toList();
    } finally {
      _loadingSessionSeries = false;
      notifyListeners();
    }
  }

  Future<void> loadCachedSlots() async {
    _slots = await _db.getAvailableSlots();
    notifyListeners();
  }

  Future<void> loadCachedSessionSeries() async {
    final data = await _db.getAllSessionSeries();
    _sessionTypes = [];
    for (final d in data) {
      try {
        final gym = Gym.fromSessionSeries(d);
        _sessionTypes.add(SessionType.fromSessionSeries(d, gym));
      } catch (_) {}
    }
    _gyms = _sessionTypes.map((s) => s.gym).toSet().toList();
    notifyListeners();
  }

  SessionType? getSessionTypeForSlot(Slot slot) {
    final facilityPrefix = _extractPrefix(slot.facilityUseUrl);
    for (final st in _sessionTypes) {
      final seriesPrefix = _extractSeriesPrefix(st.id);
      if (facilityPrefix.isNotEmpty &&
          seriesPrefix.isNotEmpty &&
          facilityPrefix == seriesPrefix) {
        return st;
      }
    }
    return null;
  }

  String _extractPrefix(String url) {
    final match = RegExp(r'/facility-uses/(\d+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  String _extractSeriesPrefix(String url) {
    final match = RegExp(r'/session-series/(\d+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  List<SessionType> searchSessionTypes(String query) {
    if (query.isEmpty) return _sessionTypes;
    final q = query.toLowerCase();
    return _sessionTypes.where((st) {
      return st.name.toLowerCase().contains(q) ||
          st.activity.toLowerCase().contains(q) ||
          st.gym.name.toLowerCase().contains(q);
    }).toList();
  }

  List<Gym> searchGyms(String query) {
    if (query.isEmpty) return _gyms;
    final q = query.toLowerCase();
    return _gyms.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.address.toLowerCase().contains(q);
    }).toList();
  }
}

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  static const _keyPollInterval = 'poll_interval_minutes';
  static const _keyAlertSound = 'alert_sound_enabled';
  static const _keyKeepAwake = 'keep_awake_enabled';
  static const _keyAutoOpenBooking = 'auto_open_booking_enabled';
  static const _keyCountdownDuration = 'countdown_duration_seconds';

  SettingsProvider(this._prefs);

  int get pollIntervalMinutes => _prefs.getInt(_keyPollInterval) ?? 2;
  bool get alertSoundEnabled => _prefs.getBool(_keyAlertSound) ?? true;
  bool get keepAwakeEnabled => _prefs.getBool(_keyKeepAwake) ?? true;
  bool get autoOpenBookingEnabled => _prefs.getBool(_keyAutoOpenBooking) ?? true;
  int get countdownDurationSeconds => _prefs.getInt(_keyCountdownDuration) ?? 30;

  Future<void> setPollInterval(int minutes) async {
    await _prefs.setInt(_keyPollInterval, minutes);
    notifyListeners();
  }

  Future<void> setAlertSound(bool enabled) async {
    await _prefs.setBool(_keyAlertSound, enabled);
    notifyListeners();
  }

  Future<void> setKeepAwake(bool enabled) async {
    await _prefs.setBool(_keyKeepAwake, enabled);
    notifyListeners();
    if (enabled) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<void> setAutoOpenBooking(bool enabled) async {
    await _prefs.setBool(_keyAutoOpenBooking, enabled);
    notifyListeners();
  }

  Future<void> setCountdownDuration(int seconds) async {
    await _prefs.setInt(_keyCountdownDuration, seconds);
    notifyListeners();
  }
}

class PollingService extends ChangeNotifier {
  Timer? _timer;
  final DatabaseService _db;
  final RpdeService _rpde;
  final NotificationService _notifications;

  bool _isPolling = false;
  int _intervalMinutes = 2;
  DateTime? _lastPoll;

  SlotProvider? _slotProvider;
  WatchProvider? _watchProvider;

  PollingService(this._db, this._rpde, this._notifications);

  bool get isPolling => _isPolling;
  DateTime? get lastPoll => _lastPoll;

  void setProviders(SlotProvider slotProvider, WatchProvider watchProvider) {
    _slotProvider = slotProvider;
    _watchProvider = watchProvider;
  }

  void setInterval(int minutes) {
    _intervalMinutes = minutes;
    if (_isPolling) {
      stop();
      start();
    }
  }

  void start() {
    if (_isPolling) return;
    _isPolling = true;
    _doPoll();
    _timer = Timer.periodic(
      Duration(minutes: _intervalMinutes),
      (_) => _doPoll(),
    );
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isPolling = false;
    notifyListeners();
  }

  Future<void> _updateHomeWidget(bool hasAlerts) async {
    try {
      await HomeWidget.saveWidgetData<String>('status', hasAlerts ? 'Slot open!' : 'All clear');
      await HomeWidget.saveWidgetData<String>('statusColor', hasAlerts ? 'red' : 'green');
      await HomeWidget.updateWidget(
        iOSName: 'SlotSpyWidget',
        qualifiedAndroidName: 'es.antonborri.home_widget.HomeWidgetProvider',
      );
    } catch (_) {
      // Widget not available
    }
  }

  Future<void> _doPoll() async {
    if (_slotProvider == null || _watchProvider == null) return;

    await _slotProvider!.fetchSlots();
    _lastPoll = DateTime.now();

    // Check for matching slots
    final availableSlots = _slotProvider!.availableSlots;
    final activeWatches = _watchProvider!.activeWatches;
    bool hasAlerts = false;

    for (final watch in activeWatches) {
      for (final slot in availableSlots) {
        if (_slotMatches(watch, slot, _slotProvider!)) {
          final shouldAlert = await _db.shouldAlert(watch.id, slot.id);
          if (shouldAlert) {
            await _db.recordAlert(watch.id, slot.id);
            final sessionType = _slotProvider!.getSessionTypeForSlot(slot);
            hasAlerts = true;

            // Build the best booking URL using GymLinkBank
            final bookingUrl = GymLinkBank.buildBestBookingUrl(
              slotId: slot.id,
              facilityUseUrl: slot.facilityUseUrl,
              fallbackUrl: sessionType?.url,
            );

            await _notifications.showSlotAvailableNotification(
              title: '🏋️ Slot available!',
              body: '${sessionType?.name ?? 'Session'} at ${sessionType?.gym.name ?? 'Gym'} — ${slot.formattedTime}',
              slotId: slot.id,
            );
            _onSlotFoundController.add(SlotMatch(watch, slot, sessionType, bookingUrl));
          }
        }
      }
    }

    // Update home widget after each poll
    await _updateHomeWidget(hasAlerts);
    notifyListeners();
  }

  bool _slotMatches(Watch watch, Slot slot, SlotProvider slotProvider) {
    final now = DateTime.now();
    final inFuture = slot.startDate.isAfter(now);
    final within7Days = slot.startDate.isBefore(now.add(const Duration(days: 7)));
    if (!inFuture || !within7Days) return false;

    // Gym match
    if (watch.gymId != null && watch.gymId!.isNotEmpty) {
      final sessionType = slotProvider.getSessionTypeForSlot(slot);
      if (sessionType == null) return false;
      if (sessionType.gym.id != watch.gymId) return false;
    }

    // Session patterns match — list of exact session names (new flow)
    if (watch.sessionPatterns != null && watch.sessionPatterns!.isNotEmpty) {
      final sessionType = slotProvider.getSessionTypeForSlot(slot);
      if (sessionType == null) return false;
      if (!watch.sessionPatterns!.any(
          (p) => sessionType.name.toLowerCase() == p.toLowerCase())) {
        return false;
      }
    }

    // Session name pattern match (backward compat with legacy single-pattern watches)
    if (watch.sessionNamePattern != null &&
        watch.sessionNamePattern!.isNotEmpty) {
      final sessionType = slotProvider.getSessionTypeForSlot(slot);
      if (sessionType == null) return false;
      if (!sessionType.name
          .toLowerCase()
          .contains(watch.sessionNamePattern!.toLowerCase())) {
        return false;
      }
    }

    // Day of week match
    if (watch.daysOfWeek != null && watch.daysOfWeek!.isNotEmpty) {
      final dow = slot.startDate.weekday;
      if (!watch.daysOfWeek!.contains(dow)) return false;
    }

    // Time window match
    if (watch.earliestTime != null) {
      final slotTime = TimeOfDay.fromDateTime(slot.startDate);
      final watchStart = watch.earliestTime!;
      final slotMinutes = slotTime.hour * 60 + slotTime.minute;
      final watchStartMinutes = watchStart.hour * 60 + watchStart.minute;
      if (slotMinutes < watchStartMinutes) return false;
    }

    if (watch.latestTime != null) {
      final slotTime = TimeOfDay.fromDateTime(slot.startDate);
      final watchEnd = watch.latestTime!;
      final slotMinutes = slotTime.hour * 60 + slotTime.minute;
      final watchEndMinutes = watchEnd.hour * 60 + watchEnd.minute;
      if (slotMinutes > watchEndMinutes) return false;
    }

    return true;
  }

  // Stream controller for slot matches
  final _onSlotFoundController = StreamController<SlotMatch>.broadcast();
  Stream<SlotMatch> get onSlotFound => _onSlotFoundController.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _onSlotFoundController.close();
    super.dispose();
  }
}

class SlotMatch {
  final Watch watch;
  final Slot slot;
  final SessionType? sessionType;
  final String bookingUrl;

  SlotMatch(this.watch, this.slot, this.sessionType, [this.bookingUrl = '']);
}

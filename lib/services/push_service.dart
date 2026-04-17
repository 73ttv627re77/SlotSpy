import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';
import 'backend_service.dart';

/// Handles APNs device token registration and incoming push notification routing.
/// Uses a native MethodChannel — no Firebase dependency required.
class PushService {
  static const _channel = MethodChannel('com.slotspy.push');
  static const _keyRegisteredToken = 'apns_registered_token';

  final NotificationService _notifications;
  BackendService? _backend;

  PushService(this._notifications);

  void setBackend(BackendService? backend) {
    _backend = backend;
  }

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      await _channel.invokeMethod('requestPermissionAndRegister');
    } catch (_) {
      // Not running on a real iOS device or channel not available — skip silently
    }
    // Check if app was launched by tapping a push notification (cold start)
    try {
      final initial = await _channel.invokeMethod<Map>('getInitialMessage');
      if (initial != null) {
        await _onNotificationTap(Map<String, String>.from(
          initial.map((k, v) => MapEntry(k.toString(), v.toString())),
        ));
      }
    } catch (_) {}
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onToken':
        final token = call.arguments as String?;
        if (token != null) await _onToken(token);
        break;
      case 'onForegroundMessage':
        final raw = call.arguments as Map?;
        if (raw != null) {
          await _onForegroundMessage(Map<String, String>.from(
            raw.map((k, v) => MapEntry(k.toString(), v.toString())),
          ));
        }
        break;
      case 'onNotificationTap':
        final raw = call.arguments as Map?;
        if (raw != null) {
          await _onNotificationTap(Map<String, String>.from(
            raw.map((k, v) => MapEntry(k.toString(), v.toString())),
          ));
        }
        break;
    }
  }

  Future<void> _onToken(String token) async {
    if (_backend == null) {
      // Backend not configured — skip (will re-register next launch when configured)
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final registeredToken = prefs.getString(_keyRegisteredToken);
    if (registeredToken == token) return; // Already registered with this token

    try {
      await _backend!.registerDevice(token: token, platform: 'ios');
      await prefs.setString(_keyRegisteredToken, token);
    } catch (_) {
      // Best-effort — don't crash if backend is unavailable
    }
  }

  Future<void> _onForegroundMessage(Map<String, String> payload) async {
    final title = payload['title'] ?? 'Slot Available!';
    final body = payload['body'] ??
        (payload['session_type_name'] != null && payload['gym_name'] != null
            ? '${payload['session_type_name']} at ${payload['gym_name']}'
            : 'A gym slot is now available');
    final bookingUrl = payload['booking_url'];
    final slotId = payload['slot_id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    await _notifications.showSlotAvailableNotification(
      title: title,
      body: body,
      slotId: slotId,
      payload: bookingUrl,
    );
  }

  Future<void> _onNotificationTap(Map<String, String> payload) async {
    final bookingUrl = payload['booking_url'];
    if (bookingUrl == null || bookingUrl.isEmpty) return;
    final uri = Uri.tryParse(bookingUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

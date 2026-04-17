import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('http')) {
      _launchUrl(payload);
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> requestPermissions() async {
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showSlotAvailableNotification({
    required String title,
    required String body,
    required String slotId,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'slot_available',
      'Slot Available',
      channelDescription: 'Notifications when a gym slot becomes available',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      slotId.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> playAlertSound() async {
    try {
      // Play a system alert sound (notification handles the sound)
      // This method can be used for additional custom sounds
    } catch (_) {
      // Silently fail if audio can't play
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

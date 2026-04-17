import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var methodChannel: FlutterMethodChannel?
  private var pendingToken: String?
  private var pendingLaunchPayload: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self

    // Capture launch-from-push payload (app was terminated when notification arrived)
    if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingLaunchPayload = extractPayload(notification)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    methodChannel = FlutterMethodChannel(
      name: "com.slotspy.push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    methodChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestPermissionAndRegister":
        self?.requestAPNsPermission()
        result(nil)
      case "getInitialMessage":
        result(self?.pendingLaunchPayload)
        self?.pendingLaunchPayload = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Deliver token that arrived before the channel was ready
    if let token = pendingToken {
      methodChannel?.invokeMethod("onToken", arguments: token)
      pendingToken = nil
    }
  }

  private func requestAPNsPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    if methodChannel != nil {
      methodChannel?.invokeMethod("onToken", arguments: tokenString)
    } else {
      pendingToken = tokenString
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[SlotSpy] APNs registration failed: \(error.localizedDescription)")
  }

  // MARK: - UNUserNotificationCenterDelegate

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Remote (APNs) push arriving while app is in foreground
    if notification.request.trigger is UNPushNotificationTrigger {
      let payload = extractPayload(notification.request.content.userInfo)
      methodChannel?.invokeMethod("onForegroundMessage", arguments: payload)
      completionHandler([]) // Suppress system banner — Flutter shows a local notification
    } else {
      // Local notifications (from flutter_local_notifications) — let system display them
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.trigger is UNPushNotificationTrigger {
      let payload = extractPayload(response.notification.request.content.userInfo)
      if methodChannel != nil {
        methodChannel?.invokeMethod("onNotificationTap", arguments: payload)
      } else {
        pendingLaunchPayload = payload
      }
    }
    completionHandler()
  }

  // MARK: - Helpers

  private func extractPayload(_ userInfo: [AnyHashable: Any]) -> [String: String] {
    var result: [String: String] = [:]

    // Custom data keys sent by the backend
    for key in ["gym_id", "gym_name", "session_type_name", "slot_id", "booking_url"] {
      if let value = userInfo[key] {
        result[key] = "\(value)"
      }
    }

    // Extract human-readable title and body from aps.alert
    if let aps = userInfo["aps"] as? [String: Any],
       let alert = aps["alert"] as? [String: Any] {
      if let title = alert["title"] as? String { result["title"] = title }
      if let body = alert["body"] as? String { result["body"] = body }
    }

    return result
  }
}

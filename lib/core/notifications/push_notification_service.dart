import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';

/// Closes the actual gap Socket.IO can never close on its own: a real system
/// push notification that reaches the vendor even when the app is fully
/// closed, not just backgrounded. Socket.IO (see `core/socket/socket_service.dart`)
/// already gives a louder, looping in-app alert while the app is *running*
/// (foreground or backgrounded-but-alive) — this is the complementary path
/// for when nothing is running at all.
///
/// Deliberately scoped, not a platform-wide notification overhaul: only the
/// `procurement_alerts` Android channel (created here) carries the vendor's
/// own custom sound. The backend's shared `sendPush()` still defaults every
/// other notification type to its existing generic channel/sound — this app
/// asks specifically for the loud one only on `request_published` pushes
/// (`ProcurementNotifier.requestPublished`), matching the same
/// alert-vs-plain-toast split already built for the in-app Socket.IO path.
class PushNotificationService {
  PushNotificationService._();

  static const channelId = 'procurement_alerts';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Creates the Android notification channel with the vendor's own alert
  /// sound (a bundled raw resource, `android/app/src/main/res/raw/`) and
  /// requests notification permission (required on Android 13+ for any
  /// notification to show at all). Call once, early in `main()`.
  ///
  /// The channel must exist on the device *before* a push referencing it
  /// arrives — Android silently falls back to a channel's own already-set
  /// sound/importance if the channel already existed with different
  /// settings from an earlier app version; this call is idempotent and only
  /// takes effect for channels not yet created on this device.
  static Future<void> initialize() async {
    const androidChannel = AndroidNotificationChannel(
      channelId,
      'New Requirements',
      description: 'Alerts when a new procurement requirement is published to you',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('new_requirement_alert'),
    );

    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (_) {
      // A channel-creation failure must never block app startup — worst
      // case, that one push falls back to the OS default sound/channel.
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Same reasoning — permission can be asked again later; startup must
      // not depend on it.
    }
  }

  /// Fetches this device's FCM token and registers it with the backend
  /// (`POST /notifications/tokens`, the same generic endpoint every other
  /// client already uses — no vendor-specific registration route needed).
  /// Call after a successful login. Swallows all failures: a push token
  /// that never registered just means this one device won't get pushes
  /// while closed — it must never block or break login itself.
  static Future<void> registerToken(ApiClient api) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await api.post('/notifications/tokens', body: {'token': token, 'platform': 'android', 'app': 'vendor'});
    } catch (_) {
      // Fire-and-forget by design — see the doc comment above.
    }
  }
}

/// Must be a top-level (or static) function annotated exactly like this —
/// FCM invokes it in a separate background isolate when a push arrives
/// while the app is backgrounded/terminated, which has no access to any
/// state from the main isolate, including whatever `Firebase.initializeApp()`
/// already did there.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No further action needed here: the backend sends a real FCM
  // "notification" payload block (not data-only), so the Android FCM SDK
  // itself displays the system tray notification using the channelId the
  // payload specifies — as long as that channel was already created on
  // this device (PushNotificationService.initialize, called on every app
  // launch), which supplies the custom sound automatically.
}

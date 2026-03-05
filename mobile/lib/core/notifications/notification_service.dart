import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_provider.dart';

/// Top-level background handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.messageId}');
  // Note: Hive is not available in the background isolate here.
  // Background messages are stored when the app next opens via getInitialMessage.
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Container gives us access to the provider outside of Widget trees
  static ProviderContainer? _container;

  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  static Future<void> initialize() async {
    // 1. Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM permission granted');
    } else {
      debugPrint('FCM permission denied');
    }

    // 2. Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Get + log FCM token (can be sent to backend later)
    final token = await _fcm.getToken();
    debugPrint('FCM Token: $token');

    // 4. Foreground messages → store in provider
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground FCM: ${message.messageId}');
      _storeMessage(message);
    });

    // 5. App opened from a notification tap (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.messageId}');
      _storeMessage(message);
    });

    // 6. App launched from a terminated state via notification tap
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _storeMessage(initialMessage);
    }
  }

  static void _storeMessage(RemoteMessage message) {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] as String? ?? 'SnapKhata';
    final body = notification?.body ?? message.data['body'] as String? ?? '';

    _container?.read(notificationProvider.notifier).addFromFirebase(
          title: title,
          body: body,
          data: Map<String, dynamic>.from(message.data),
        );
  }
}

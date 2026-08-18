import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:flutter/foundation.dart';

// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Request permissions (important for Android 13+ and iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Initialize local notifications for foreground popups
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

    // Create a notification channel for Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle messages while the app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showForegroundNotification(message.notification!, channel);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get FCM token and register it
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print("FCM Token: $token");
      await sendTokenToServer(token);
    }

    // Berlangganan ke saluran global untuk menerima notifikasi feed baru
    await _firebaseMessaging.subscribeToTopic('global_feeds');
    print("Subscribed to global_feeds topic");

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print("FCM Token refreshed: $newToken");
      sendTokenToServer(newToken);
    });
  }

  static void _showForegroundNotification(
      RemoteNotification notification, AndroidNotificationChannel channel) {
    _localNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          priority: Priority.high,
          importance: Importance.max,
        ),
      ),
    );
  }

  static Future<void> sendTokenToServer(String token) async {
    if (!AuthService.isLoggedIn) return;

    try {
      final uri = Uri.parse('https://titc.or.id/wp-json/titc-mobile/v1/device-token');
      final headers = Map<String, String>.from(ApiService.authHeaders);
      headers['Content-Type'] = 'application/json';

      final response = await ApiService.client.post(
        uri,
        headers: headers,
        body: json.encode({'token': token}),
      );

      print('Send FCM token response: ${response.statusCode}');
    } catch (e) {
      print('Error sending FCM token: $e');
    }
  }
}

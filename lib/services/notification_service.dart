import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'session_service.dart';
import 'firebase_service.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> _storeFCMToken(String token) async {
    final user = await SessionService.getCurrentUser();

    // Validate token before storing
    if (token.isEmpty || token == 'null') {
      print('Warning: Attempted to store invalid FCM token: "$token"');
      return;
    }

    if (user != null) {
      await FirebaseService.storeFCMToken(user.id, token);
      print('FCM token stored for user ${user.id}');
    } else {
      print(
        'Warning: No user session found to store FCM token. Token: "$token"',
      );
    }
  }

  static Future<void> initialize() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        print("Initializing Firebase...");
        await Firebase.initializeApp();
      } else {
        print("Firebase is already initialized.");
      }

      // Request platform-specific notification permissions
      if (!kIsWeb && Platform.isAndroid) {
        print(
          'Android device detected, requesting Android-specific notification permissions...',
        );
        await _requestAndroidNotificationPermission();
      } else {
        // For iOS and web, use Firebase's requestPermission
        print(
          'iOS/Web device detected, requesting standard notification permissions...',
        );
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print(
          'Notification permission status: ${settings.authorizationStatus}',
        );
      }

      // Initialize local notifications
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: androidInitializationSettings,
            iOS: iosInitializationSettings,
          );

      await _localNotifications.initialize(initializationSettings);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Get the FCM token for this device and store it
      final String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Store the token for notifications
      if (token != null) {
        await _storeFCMToken(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('FCM token refreshed: $newToken');
        await _storeFCMToken(newToken);
      });
    } catch (e) {
      print('Error initializing notification service: $e');
      // Don't rethrow the error to prevent app from crashing
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'wewire_maintenance_channel',
          'Maintenance Notifications',
          channelDescription:
              'Notifications for maintenance issues and updates',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    if (message.notification != null) {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message.notification!.title ?? 'New Notification',
        message.notification!.body ?? 'You have a new notification',
        platformChannelSpecifics,
      );
    }
  }

  static Future<String?> getDeviceToken() async {
    return await _firebaseMessaging.getToken();
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      // This method is not supported on web, so we'll just log it
      print('Would subscribe to topic: $topic (not supported on web)');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // This method is not supported on web, so we'll just log it
      print('Would unsubscribe from topic: $topic (not supported on web)');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // Request Android notification permission (required for Android 13+)
  static Future<void> _requestAndroidNotificationPermission() async {
    try {
      // Check if we're on Android
      if (Platform.isAndroid) {
        print('Requesting Android notification permission...');
        // Request Firebase permissions for notifications
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print(
          'Android notification permission status: ${settings.authorizationStatus}',
        );
      }
    } catch (e) {
      print('Error requesting Android notification permission: $e');
    }
  }

  // Test function to send a notification
  static Future<void> testSendNotification() async {
    await FirebaseService.sendNotificationToTechnicians(
      'Test Notification',
      'This is a test notification to verify the notification system.',
    );
  }
}

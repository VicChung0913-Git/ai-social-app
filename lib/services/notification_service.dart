import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channel for chat messages
  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
    playSound: true,
  );

  // Notification channel for incoming calls
  static const AndroidNotificationChannel _callChannel =
      AndroidNotificationChannel(
    'incoming_calls',
    'Incoming Calls',
    description: 'Notifications for incoming voice and video calls',
    importance: Importance.max,
    playSound: true,
  );

  // Callback for handling notification taps
  Function(String chatRoomId)? onNotificationTap;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('Notification permission granted');

      // Initialize local notifications
      await _initLocalNotifications();

      // Get and save FCM token
      await _saveToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_updateToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle notification tap from terminated state
      RemoteMessage? initialMessage =
          await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          String chatRoomId = data['chatRoomId'] ?? '';
          if (chatRoomId.isNotEmpty && onNotificationTap != null) {
            onNotificationTap!(chatRoomId);
          }
        }
      },
    );

    // Create notification channels (Android)
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_chatChannel);
      await androidPlugin.createNotificationChannel(_callChannel);
    }
  }

  Future<void> _saveToken() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _updateToken(token);
    }
  }

  Future<void> _updateToken(String token) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannel.id,
            _chatChannel.name,
            channelDescription: _chatChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    String chatRoomId = message.data['chatRoomId'] ?? '';
    if (chatRoomId.isNotEmpty && onNotificationTap != null) {
      onNotificationTap!(chatRoomId);
    }
  }

  // Show local notification for chat messages
  Future<void> showChatNotification({
    required String title,
    required String body,
    required String chatRoomId,
  }) async {
    await _localNotifications.show(
      chatRoomId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({'chatRoomId': chatRoomId}),
    );
  }

  // Show incoming call notification
  Future<void> showCallNotification({
    required String callerName,
    required String callId,
    required bool isVideo,
  }) async {
    await _localNotifications.show(
      callId.hashCode,
      isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
      '$callerName is calling...',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          _callChannel.name,
          channelDescription: _callChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'type': 'call',
        'callId': callId,
        'isVideo': isVideo,
      }),
    );
  }

  // Cancel call notification
  Future<void> cancelCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  // Remove FCM token on logout
  Future<void> removeToken() async {
    String? token = await _messaging.getToken();
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (token != null && currentUser != null) {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }
  }
}

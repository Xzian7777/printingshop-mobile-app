import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/customer_chat_screen.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Background Firebase init error: $e");
  }
  debugPrint("Handling background FCM message: ${message.messageId}");
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _currentUserEmail;
  bool _isInitialized = false;

  static const String _channelId = 'kcz_chat_channel';
  static const String _channelName = 'KCZ Printing Shop Chat';
  static const String _channelDesc = 'Notifications for chat messages from KCZ Printing Shop admin.';

  /// Initialize FCM, local notification plugin, permissions, and event listeners
  Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
    if (_isInitialized) return;
    _navigatorKey = navKey;
    _isInitialized = true;

    // 1. Request notification permissions (POST_NOTIFICATIONS on Android 13+)
    await requestPermission();

    // 2. Setup Android notification channel & local notifications
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint("Error decoding notification payload: $e");
          }
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }

    // 3. Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground message received: ${message.messageId}");
      _showLocalNotification(message);
    });

    // 4. Background message opened listener (when user taps notification and app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM notification opened app: ${message.data}");
      _handleNotificationClick(message.data);
    });

    // 5. Terminated state message (when app was opened from terminated state via notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("FCM app opened from terminated state: ${initialMessage.data}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationClick(initialMessage.data);
      });
    }

    // 6. Listen to token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      if (_currentUserEmail != null && _currentUserEmail!.isNotEmpty) {
        _saveTokenToFirestore(_currentUserEmail!, newToken);
      }
    });
  }

  /// Request permissions
  Future<void> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint("FCM authorization status: ${settings.authorizationStatus}");
    } catch (e) {
      debugPrint("Error requesting FCM permissions: $e");
    }
  }

  /// Register current customer's FCM token in Firestore and associate with customer ID
  Future<void> registerUserToken(String userEmail) async {
    if (userEmail.isEmpty) return;
    _currentUserEmail = userEmail;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint("FCM token retrieved: $token for $userEmail");
        await _saveTokenToFirestore(userEmail, token);
      }
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }
  }

  /// Save token to Firestore matching web backend fcm_tokens schema
  Future<void> _saveTokenToFirestore(String email, String token) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final nowIso = DateTime.now().toIso8601String();

      // Primary token document matching web backend lookup: fcm_tokens/{token_doc_id}
      final tokenDocId = token.length > 40
          ? token.substring(token.length - 40).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          : token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final fcmTokenRef = FirebaseFirestore.instance.collection('fcm_tokens').doc(tokenDocId);
      await fcmTokenRef.set({
        'token': token,
        'email': cleanEmail,
        'role': 'customer',
        'device': 'Android Mobile App',
        'updatedAt': nowIso,
        'createdAt': nowIso,
        'active': true,
      }, SetOptions(merge: true));

      // Also save in artifacts/printcraft-pro/public/data/notification_tokens for fallback
      final customerId = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
      final legacyTokenRef = FirebaseFirestore.instance
          .collection('artifacts')
          .doc('printcraft-pro')
          .collection('public')
          .doc('data')
          .collection('notification_tokens')
          .doc(customerId);

      await legacyTokenRef.set({
        'token': token,
        'email': cleanEmail,
        'customerId': customerId,
        'lastUpdated': FieldValue.serverTimestamp(),
        'platform': 'android',
      }, SetOptions(merge: true)).catchError((_) {});

      debugPrint("Successfully registered FCM token in Firestore for $cleanEmail");
    } catch (e) {
      debugPrint("Error saving FCM token to Firestore: $e");
    }
  }

  /// Remove user token on sign-out to prevent notifications going to wrong user
  Future<void> removeUserToken(String userEmail) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final tokenDocId = token.length > 40
            ? token.substring(token.length - 40).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await FirebaseFirestore.instance.collection('fcm_tokens').doc(tokenDocId).delete().catchError((_) {});
      }

      final cleanEmail = userEmail.trim().toLowerCase();
      final customerId = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;

      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('printcraft-pro')
          .collection('public')
          .doc('data')
          .collection('notification_tokens')
          .doc(customerId)
          .delete()
          .catchError((_) {});

      _currentUserEmail = null;
      debugPrint("Successfully deleted FCM token for $cleanEmail");
    } catch (e) {
      debugPrint("Error removing FCM token from Firestore: $e");
    }
  }

  /// Show a Heads-Up local notification when a message arrives while app is in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'New Message from Support';
    final body = notification?.body ?? data['body'] ?? 'You have received a new chat message.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: jsonEncode(data),
    );
  }

  /// Navigate directly to CustomerChatScreen on notification tap
  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint("Handling notification click with data: $data");

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint("NavigatorState not available yet.");
      return;
    }

    final senderEmail = data['sender_email']?.toString() ?? data['senderEmail']?.toString();
    final userEmail = _currentUserEmail ?? senderEmail ?? 'Customer';

    nav.push(
      MaterialPageRoute(
        builder: (context) => CustomerChatScreen(
          userEmail: userEmail,
        ),
      ),
    );
  }
}

import 'auth_service.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/dashboard_screen.dart';
import 'notification_destination.dart';
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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _currentUserEmail;
  bool _isInitialized = false;
  bool _navigationReady = false;
  String _currentRole = 'customer';
  Map<String, dynamic>? _pendingData;

  static const String _channelId = 'kcz_chat_channel';
  static const String _channelName = 'KCZ Printing Shop Updates';
  static const String _channelDesc =
      'Order updates and messages from KCZ Printing Shop.';

  /// Initialize FCM, local notification plugin, permissions, and event listeners
  Future<void> initialize(GlobalKey<NavigatorState> navKey) async {
    if (_isInitialized) return;
    _navigatorKey = navKey;
    _isInitialized = true;

    // 1. Request notification permissions (POST_NOTIFICATIONS on Android 13+)
    await requestPermission();

    // 2. Setup Android notification channel & local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

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

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
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
      debugPrint(
          "FCM app opened from terminated state: ${initialMessage.data}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationClick(initialMessage.data);
      });
    }

    final localLaunch =
        await _localNotifications.getNotificationAppLaunchDetails();
    final payload = localLaunch?.notificationResponse?.payload;
    if (localLaunch?.didNotificationLaunchApp == true && payload != null) {
      try {
        _handleNotificationClick(
            Map<String, dynamic>.from(jsonDecode(payload) as Map));
      } catch (e) {
        debugPrint('Invalid notification launch payload: $e');
      }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        user.email?.toLowerCase() != userEmail.trim().toLowerCase()) {
      return;
    }
    await AuthService.readyProfile(user);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    _currentUserEmail = userEmail.trim().toLowerCase();
    _currentRole = 'customer';

    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      _currentRole =
          (profile.data()?['role'] ?? 'customer').toString().toLowerCase();
      final token = await _messaging.getToken();
      if (token != null) {
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null ||
          user.email?.toLowerCase() != cleanEmail ||
          _currentUserEmail != cleanEmail || !AuthService.isReady(user.uid)) {
        return;
      }
      final nowIso = DateTime.now().toIso8601String();

      // Primary token document matching web backend lookup: fcm_tokens/{token_doc_id}
      final tokenDocId = token.length > 40
          ? token
              .substring(token.length - 40)
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          : token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final fcmTokenRef =
          FirebaseFirestore.instance.collection('fcm_tokens').doc(tokenDocId);
      await fcmTokenRef.set({
        'token': token,
        'email': cleanEmail,
        'role': _currentRole,
        'uid': user.uid,
        'platform': 'android',
        'device': 'Android Mobile App',
        'updatedAt': nowIso,
        'createdAt': nowIso,
        'active': true,
      }, SetOptions(merge: true));

      // Also save in artifacts/printcraft-pro/public/data/notification_tokens for fallback
      final customerId =
          cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
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

      debugPrint(
          "Successfully registered FCM token in Firestore for $cleanEmail");
    } catch (e) {
      debugPrint("Error saving FCM token to Firestore: $e");
    }
  }

  /// Remove user token on sign-out to prevent notifications going to wrong user
  Future<void> removeUserToken(String userEmail) async {
    _currentUserEmail = null;
    _navigationReady = false;
    _pendingData = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final tokenDocId = token.length > 40
            ? token
                .substring(token.length - 40)
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(tokenDocId)
            .delete()
            .catchError((_) {});
      }

      final cleanEmail = userEmail.trim().toLowerCase();
      final customerId =
          cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;

      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('printcraft-pro')
          .collection('public')
          .doc('data')
          .collection('notification_tokens')
          .doc(customerId)
          .delete()
          .catchError((_) {});

      await _localNotifications.cancelAll();
      await _messaging.deleteToken();
      debugPrint("Successfully deleted FCM token for $cleanEmail");
    } catch (e) {
      debugPrint("Error removing FCM token from Firestore: $e");
    }
  }

  /// Show a Heads-Up local notification when a message arrives while app is in foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final recipient = message.data['recipient_email']?.toString().toLowerCase();
    if (recipient != null && recipient != user.email?.toLowerCase()) return;
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'KCZ Printing Shop';
    final body = notification?.body ?? data['body'] ?? 'You have a new update.';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_notification',
      tag: data['event_id']?.toString(),
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: (data['event_id'] ?? message.messageId ?? message.hashCode).hashCode &
          0x7fffffff,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: jsonEncode(data),
    );
  }

  /// Called after the authenticated dashboard is mounted, including cold starts.
  void activateNavigation() {
    _navigationReady = true;
    final pending = _pendingData;
    if (pending != null) _handleNotificationClick(pending);
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    final user = FirebaseAuth.instance.currentUser;
    if (!_navigationReady || nav == null || user == null || user.email == null || !AuthService.isReady(user.uid)) {
      _pendingData = data;
      return;
    }
    _pendingData = null;
    final email = user.email!;
    final recipient = data['recipient_email']?.toString().toLowerCase();
    if (recipient != null && recipient != email.toLowerCase()) return;
    final destination = notificationDestination(data);
    final isAdmin = _currentRole == 'admin' || _currentRole == 'staff';
    nav.push(MaterialPageRoute(builder: (context) {
      if (destination == 'chat' && !isAdmin) {
        return CustomerChatScreen(userEmail: email);
      }
      return DashboardScreen(
        userEmail: email,
        isAdmin: isAdmin,
        initialNavIndex: isAdmin ? 2 : 3,
        initialAdminTab: destination == 'chat' ? 1 : 0,
      );
    }));
  }
}

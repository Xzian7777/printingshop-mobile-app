import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/fcm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize FCM notification services with the root navigatorKey
    FcmService().initialize(navigatorKey).catchError((Object error) {
      debugPrint('Notification initialization failed: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kez C-Em Zek Printing Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        fontFamily: null,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Root authentication gate that checks Firebase Authentication state on app launch.
/// If an authenticated user session exists, it restores the session and routes directly
/// to DashboardScreen without flashing the login screen.
/// If no session exists, it routes to HomeScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Map<String, dynamic>> _fetchUserRole(User user) async {
    final profile = await AuthService.readyProfile(user);
    return {'isAdmin': profile['role'] == 'admin', 'email': profile['email']};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for initial Firebase auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF070A14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }

        final user = snapshot.data;

        // If no user is logged in, show HomeScreen
        if (user == null) {
          final message = AuthService.restorationError;
          AuthService.restorationError = null;
          if (message != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            });
          }
          return const HomeScreen();
        }

        // Authenticated user found: retrieve role and route to DashboardScreen
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchUserRole(user),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF070A14),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                  body: Center(
                      child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(googleSignInError(roleSnapshot.error!)),
              )));
            }

            final userInfo = roleSnapshot.data ??
                {
                  'isAdmin': false,
                  'email': user.email ?? 'Customer',
                };

            return DashboardScreen(
              userEmail: userInfo['email'] as String,
              isAdmin: userInfo['isAdmin'] as bool,
            );
          },
        );
      },
    );
  }
}

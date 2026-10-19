import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final role = data?['role']?.toString().toLowerCase();
        return {
          'isAdmin': role == 'admin',
          'email': user.email ?? data?['email'] ?? 'Customer',
        };
      }
    } catch (e) {
      debugPrint("AuthGate: error fetching user role (offline or network): $e");
    }

    // Graceful fallback for offline / missing profile document
    return {
      'isAdmin': false,
      'email': user.email ?? 'Customer',
    };
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

            final userInfo = roleSnapshot.data ?? {
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
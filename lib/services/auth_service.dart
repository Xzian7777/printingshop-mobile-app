import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'loyalty_api.dart';

class SignInFailure implements Exception {
  const SignInFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String googleSignInError(Object error) {
  if (error is SignInFailure) return error.message;
  if (error is GoogleSignInException) {
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Google sign-in is not configured for this app. Contact the shop administrator.';
    }
    return 'Google sign-in was interrupted. Check your connection and try again.';
  }
  if (error is FirebaseAuthException) {
    if ([
      'account-exists-with-different-credential',
      'credential-already-in-use',
      'email-already-in-use'
    ].contains(error.code)) {
      return 'Sign in using your existing account method first. Contact the shop administrator to link Google to that account.';
    }
    if (['wrong-password', 'invalid-credential'].contains(error.code)) {
      return 'The existing account password is incorrect. Please try again.';
    }
    if (error.code == 'user-disabled') {
      return 'This account is disabled. Contact the shop administrator.';
    }
    if (error.code == 'operation-not-allowed') {
      return 'Google sign-in is unavailable. Contact the shop administrator.';
    }
    if (error.code == 'network-request-failed') {
      return 'Unable to connect. Check your internet connection and try again.';
    }
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'Unable to reach the shop server. Check your connection and try Continue with Google again.';
  }
  return 'Unable to finish Google sign-in. Please try Continue with Google again.';
}

Map<String, dynamic> googleProfileResponse(http.Response response, String uid) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    throw const SignInFailure(
        'The shop server returned an invalid response. Please try again later.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const SignInFailure(
        'The shop server returned an invalid response. Please try again later.');
  }
  if (response.statusCode != 200 || decoded['success'] != true) {
    throw SignInFailure(decoded['message'] is String
        ? decoded['message'] as String
        : 'Unable to synchronize your account. Please try again later.');
  }
  final profile = decoded['user'];
  if (profile is! Map<String, dynamic> ||
      profile['uid'] != uid ||
      !['admin', 'customer'].contains(profile['role']) ||
      profile['email'] is! String) {
    throw const SignInFailure(
        'Your account could not be synchronized. Contact the shop administrator.');
  }
  return profile;
}

Future<UserCredential> authenticateGoogleCredential(
  FirebaseAuth authentication,
  AuthCredential credential,
  String email,
  Future<String?> Function(String email) confirmExistingPassword,
) async {
  UserCredential result;
  try {
    result = await authentication.signInWithCredential(credential);
  } on FirebaseAuthException catch (error) {
    if (error.code != 'account-exists-with-different-credential') rethrow;
    final password = await confirmExistingPassword(email);
    if (password == null) {
      throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled);
    }
    final existing = await authentication.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final owner = existing.user;
    if (owner == null || owner.email?.toLowerCase() != email.toLowerCase()) {
      throw const SignInFailure(
          'Sign in with the existing account before linking Google.');
    }
    await owner.linkWithCredential(credential);
    // Establish a Google-provider token for the verified backend bootstrap.
    result = await authentication.signInWithCredential(credential);
    if (result.user?.uid != owner.uid) {
      throw const SignInFailure(
          'Google could not be linked to your existing account. Contact the shop administrator.');
    }
  }
  return result;
}

/// Google sessions are usable only after the server confirms the canonical profile.
class AuthService {
  static String? restorationError;
  static Future<void>? _initialization;
  static Completer<Map<String, dynamic>?>? _pending;
  static final Map<String, Future<Map<String, dynamic>>> _restoring = {};
  static final Map<String, Map<String, dynamic>> _profiles = {};

  static bool get signingIn => _pending != null;

  static bool isReady(String uid) =>
      _pending == null && _profiles.containsKey(uid);

  static Future<void> _initializeGoogle() async {
    try {
      await (_initialization ??= GoogleSignIn.instance.initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _synchronize(User user) async {
    if (LoyaltyApi.baseUrl.isEmpty) {
      throw const SignInFailure(
          'The shop server URL is missing. Contact the shop administrator.');
    }
    final token = await user.getIdToken(true);
    final response = await http
        .post(
          Uri.parse(
              '${LoyaltyApi.baseUrl.replaceFirst(RegExp(r"/$"), "")}/api/google-login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': token}),
        )
        .timeout(const Duration(seconds: 25));
    final profile = googleProfileResponse(response, user.uid);
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const SignInFailure('Your session changed. Please sign in again.');
    }
    _profiles[user.uid] = profile;
    return profile;
  }

  static Future<Map<String, dynamic>?> signInWithGoogle({
    required Future<String?> Function(String email) confirmExistingPassword,
  }) async {
    if (_pending != null) return null;
    final attempt = Completer<Map<String, dynamic>?>();
    _pending = attempt;
    try {
      await _initializeGoogle();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
          idToken: googleUser.authentication.idToken);
      final result = await authenticateGoogleCredential(
        FirebaseAuth.instance,
        credential,
        googleUser.email,
        confirmExistingPassword,
      );
      final user = result.user;
      if (user == null) {
        throw const SignInFailure(
            'Google sign-in did not complete. Please try again.');
      }
      final profile = await _synchronize(user);
      attempt.complete(profile);
      return profile;
    } catch (error) {
      try {
        await signOut();
      } finally {
        attempt.complete(null);
      }
      if (error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw SignInFailure(googleSignInError(error));
    } finally {
      _pending = null;
    }
  }

  static Future<Map<String, dynamic>> readyProfile(User user) async {
    final pending = _pending;
    if (pending != null) {
      final result = await pending.future;
      if (result == null || result['uid'] != user.uid) {
        throw const SignInFailure(
            'Sign-in was not completed. Please try again.');
      }
      return result;
    }
    final cached = _profiles[user.uid];
    if (cached != null) return cached;
    return _restoring.putIfAbsent(user.uid, () => _restore(user));
  }

  static Future<Map<String, dynamic>> _restore(User user) async {
    try {
      if (user.providerData
          .any((provider) => provider.providerId == 'google.com')) {
        final token = await user.getIdTokenResult();
        if (token.signInProvider == 'google.com') {
          return await _synchronize(user);
        }
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? {};
      if (data['archived'] == true ||
          data['isArchived'] == true ||
          data['disabled'] == true) {
        throw const SignInFailure(
            'This account is archived or disabled. Contact the shop administrator.');
      }
      final profile = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? data['email'] ?? '',
        'role': data['role'] == 'admin' ? 'admin' : 'customer'
      };
      _profiles[user.uid] = profile;
      return profile;
    } catch (error) {
      restorationError = googleSignInError(error);
      if (FirebaseAuth.instance.currentUser?.uid == user.uid) await signOut();
      throw SignInFailure(googleSignInError(error));
    } finally {
      _restoring.remove(user.uid);
    }
  }

  static Future<void> signOut() async {
    _profiles.clear();
    _restoring.clear();
    try {
      await _initializeGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase sign-out must still complete when the Google SDK is unavailable.
    } finally {
      await FirebaseAuth.instance.signOut();
    }
  }
}

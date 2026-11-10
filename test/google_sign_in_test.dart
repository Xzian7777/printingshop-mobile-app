import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:printingshop/services/auth_service.dart';
import 'package:printingshop/widgets/google_sign_in_button.dart';
import 'package:printingshop/screens/login_screen.dart';
import 'package:printingshop/screens/register_screen.dart';

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User? user;
}

class _ExistingUser extends Fake implements User {
  _ExistingUser(this.calls,
      {this.uid = 'existing-uid', this.email = 'person@example.com'});
  final List<String> calls;
  @override
  final String uid;
  @override
  final String? email;
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    calls.add('link');
    return _Credential(this);
  }
}

class _Authentication extends Fake implements FirebaseAuth {
  final calls = <String>[];
  bool wrongPassword = false;
  bool differentUid = false;
  String email = 'person@example.com';
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    calls.add('google');
    if (calls.length == 1) {
      throw FirebaseAuthException(
          code: 'account-exists-with-different-credential');
    }
    return _Credential(
        _ExistingUser(calls, uid: differentUid ? 'wrong-uid' : 'existing-uid'));
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    calls.add('password');
    if (wrongPassword) throw FirebaseAuthException(code: 'wrong-password');
    return _Credential(_ExistingUser(calls, email: this.email));
  }
}

void main() {
  test(
      'Linking authenticates the existing owner before linking and preserves UID',
      () async {
    final authentication = _Authentication();
    final result = await authenticateGoogleCredential(
        authentication,
        GoogleAuthProvider.credential(idToken: 'google-token'),
        'person@example.com', (email) async {
      expect(email, 'person@example.com');
      authentication.calls.add('confirm');
      return 'existing-password';
    });
    expect(authentication.calls,
        ['google', 'confirm', 'password', 'link', 'google']);
    expect(result.user!.uid, 'existing-uid');
  });

  test(
      'Cancelling password verification never authenticates or links an account',
      () async {
    final authentication = _Authentication();
    await expectLater(
        authenticateGoogleCredential(
            authentication,
            GoogleAuthProvider.credential(idToken: 'google-token'),
            'person@example.com',
            (_) async => null),
        throwsA(isA<GoogleSignInException>().having(
            (e) => e.code, 'code', GoogleSignInExceptionCode.canceled)));
    expect(authentication.calls, ['google']);
  });

  test('Wrong passwords and conflicting identities cannot complete linking',
      () async {
    for (final authentication in [
      _Authentication()..wrongPassword = true,
      _Authentication()..email = 'another@example.com',
      _Authentication()..differentUid = true,
    ]) {
      await expectLater(
          authenticateGoogleCredential(
              authentication,
              GoogleAuthProvider.credential(idToken: 'google-token'),
              'person@example.com',
              (_) async => 'password'),
          throwsA(anyOf(isA<FirebaseAuthException>(), isA<SignInFailure>())));
      if (!authentication.differentUid) {
        expect(authentication.calls, isNot(contains('link')));
      }
    }
  });

  test('Only a synchronized canonical profile completes sign-in', () {
    final profile = {
      'uid': 'u1',
      'email': 'person@example.com',
      'role': 'customer'
    };
    expect(
        googleProfileResponse(
            http.Response(jsonEncode({'success': true, 'user': profile}), 200),
            'u1'),
        profile);
    for (final user in [
      {...profile, 'uid': 'another'},
      {...profile, 'role': 'owner'},
      {...profile, 'email': null},
      null,
    ]) {
      expect(
          () => googleProfileResponse(
              http.Response(jsonEncode({'success': true, 'user': user}), 200),
              'u1'),
          throwsA(isA<SignInFailure>()));
    }
  });

  test('Backend failures and malformed responses produce readable messages',
      () {
    for (final response in [
      http.Response('<html>Unavailable</html>', 503),
      http.Response('[]', 200),
      http.Response('{}', 200)
    ]) {
      expect(() => googleProfileResponse(response, 'u1'),
          throwsA(isA<SignInFailure>()));
    }
    expect(
        () => googleProfileResponse(
            http.Response(
                jsonEncode(
                    {'success': false, 'message': 'This account is archived.'}),
                403),
            'u1'),
        throwsA(isA<SignInFailure>()
            .having((e) => e.message, 'message', 'This account is archived.')));
  });

  test('Configuration, linking and connection errors have English guidance',
      () {
    expect(
        googleSignInError(const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError)),
        contains('not configured'));
    expect(
        googleSignInError(FirebaseAuthException(
            code: 'account-exists-with-different-credential')),
        contains('existing account method'));
    expect(googleSignInError(FirebaseAuthException(code: 'user-disabled')),
        contains('disabled'));
    expect(
        googleSignInError(
            FirebaseAuthException(code: 'network-request-failed')),
        contains('connection'));
    expect(AuthService.isReady('not-synchronized'), isFalse);
  });

  testWidgets('Google button requires Terms and fits a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var busyChanges = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(24),
      child: GoogleSignInButton(
          busy: false,
          termsAccepted: false,
          onBusyChanged: (_) => busyChanges++),
    ))));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(
        find.text(
            'Please accept the Terms & Conditions to continue with Google.'),
        findsOneWidget);
    expect(busyChanges, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google action is disabled while authentication is processing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GoogleSignInButton(
      busy: true,
      termsAccepted: true,
      onBusyChanged: (_) => fail('Overlapping authentication'),
    ))));
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });
  for (final screen in [const LoginScreen(), const RegisterScreen()]) {
    testWidgets('${screen.runtimeType} shows Google sign-in on a small screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: screen));
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.pump();
    });
  }
  testWidgets(
      'Account linking requires the existing password and can be cancelled',
      (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () async {
            submitted =
                await confirmGoogleAccountLink(context, 'person@example.com');
          },
          child: const Text('Link account')),
    ))));
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify and link Google'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your existing password.'), findsOneWidget);
    expect(submitted, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Link your existing account'), findsNothing);
    expect(submitted, isNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Link account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'existing-password');
    await tester.tap(find.text('Verify and link Google'));
    await tester.pumpAndSettle();
    expect(submitted, 'existing-password');
    expect(tester.takeException(), isNull);
  });
}

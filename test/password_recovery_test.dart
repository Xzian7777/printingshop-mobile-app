import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:printingshop/screens/forgot_password_screen.dart';
import 'package:printingshop/services/password_reset_service.dart';

void main() {
  test('Reset password validation matches the server policy', () {
    for (final value in [
      '',
      'short',
      'alllowercase8',
      'ALLUPPERCASE8',
      'Has Space9',
      'Has\tTab9',
      'personSecret8',
      'A' * 33
    ]) {
      expect(validateResetPassword(value, 'person@gmail.com'), isNotNull);
    }
    expect(validateResetPassword('ValidSecret7!', 'person@gmail.com'), isNull);
  });

  test(
      'Recovery calls are unauthenticated and send the entered code to the server',
      () async {
    final paths = <String>[];
    final service = PasswordResetService(
        baseUrl: 'http://localhost:5000',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers.containsKey('Authorization'), isFalse);
          final data = jsonDecode(request.body);
          expect(data['email'], 'person@gmail.com');
          if (request.url.path != '/api/forgot-password') {
            expect(data['otp'], '123456');
          }
          return http.Response('{"success":true}', 200);
        }));
    addTearDown(service.close);
    await service.requestCode('person@gmail.com');
    await service.verifyCode('person@gmail.com', '123456');
    await service.resetPassword('person@gmail.com', '123456', 'ValidSecret7!');
    expect(paths, [
      '/api/forgot-password',
      '/api/verify-reset-otp',
      '/api/reset-password'
    ]);
  });

  test('Server and invalid-response failures remain failures', () async {
    for (final response in [
      http.Response('{"success":false,"message":"The code expired."}', 400),
      http.Response('<html>Unavailable</html>', 503),
      http.Response('[]', 200)
    ]) {
      final service = PasswordResetService(
          baseUrl: 'http://localhost',
          client: MockClient((_) async => response));
      await expectLater(
          service.resetPassword('person@gmail.com', '123456', 'ValidSecret7!'),
          throwsStateError);
      service.close();
    }
  });

  testWidgets(
      'Recovery reports completion only after the server confirms the password update',
      (tester) async {
    final saved = Completer<http.Response>();
    final requests = <String>[];
    final service = PasswordResetService(
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/reset-password') return saved.future;
          return http.Response('{"success":true}', 200);
        }));
    addTearDown(service.close);
    bool? result;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Builder(
          builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                            initialEmail: 'person@gmail.com',
                            service: service)));
              },
              child: const Text('Recover account')),
        ))));
    await tester.tap(find.text('Recover account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'ValidSecret7!');
    await tester.enterText(find.byType(TextFormField).last, 'ValidSecret7!');
    await tester.ensureVisible(find.text('Save new password'));
    await tester.tap(find.text('Save new password'));
    await tester.pump();
    expect(result, isNull);
    expect(find.text('Please wait…'), findsOneWidget);
    saved.complete(http.Response('{"success":true}', 200));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(requests, [
      '/api/forgot-password',
      '/api/verify-reset-otp',
      '/api/reset-password'
    ]);
  });

  testWidgets(
      'An incorrect code keeps the verification step open with an English error',
      (tester) async {
    final service = PasswordResetService(
        baseUrl: 'http://localhost',
        client: MockClient((request) async => request.url.path ==
                '/api/forgot-password'
            ? http.Response('{"success":true}', 200)
            : http.Response(
                '{"success":false,"message":"Incorrect verification code."}',
                400)));
    addTearDown(service.close);
    await tester.pumpWidget(MaterialApp(
        home: ForgotPasswordScreen(
            initialEmail: 'person@gmail.com', service: service)));
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '654321');
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect verification code.'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

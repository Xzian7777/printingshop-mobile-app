import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/main.dart';
import 'package:printingshop/screens/login_screen.dart';
import 'package:printingshop/screens/home_screen.dart';
import 'package:printingshop/screens/register_screen.dart';
import 'package:printingshop/screens/place_order_screen.dart';
import 'package:printingshop/services/payment_eligibility.dart';
import 'package:printingshop/theme/dashboard_theme.dart';
import 'package:printingshop/widgets/google_sign_in_button.dart';
import 'package:printingshop/widgets/points_selector.dart';

class _BuildContext extends Fake implements BuildContext {}

double contrast(Color text, Color background) {
  final foreground = Color.alphaBlend(text, background).computeLuminance();
  final surface = background.computeLuminance();
  return foreground > surface
      ? (foreground + .05) / (surface + .05)
      : (surface + .05) / (foreground + .05);
}

void main() {
  test(
      'root app uses readable light surfaces for pushed authentication and order routes',
      () {
    // Inspect the root theme without starting live Firebase and notification services.
    // ignore: invalid_use_of_protected_member
    final material =
        const MyApp().createState().build(_BuildContext()) as MaterialApp;
    expect(material.theme!.brightness, Brightness.light);
    expect(contrast(material.theme!.colorScheme.onSurface, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(
        contrast(material.theme!.inputDecorationTheme.helperStyle!.color!,
            const Color(0xFFF0FDF4)),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('home cards use readable text on their light surfaces',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: DashboardTheme.light, home: const HomeScreen()));
    for (final label in [
      'Unparalleled\nQuality Proofing',
      '99.4%',
      '100% Guaranteed'
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(contrast(text.style!.color!, Colors.white),
          greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'login heading and registration inputs have visible text on light cards',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: DashboardTheme.light, home: const LoginScreen()));
    final heading = tester.widget<Text>(find.text('Welcome Back'));
    expect(contrast(heading.style!.color!, DashboardTheme.canvas),
        greaterThanOrEqualTo(4.5));
    await tester.pumpWidget(
        MaterialApp(theme: DashboardTheme.light, home: const RegisterScreen()));
    expect(find.byType(TextField), findsWidgets);
    for (final input in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(contrast(input.style!.color!, const Color(0xFFF0FDF4)),
          greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets(
      'busy Google button keeps a readable label and progress indicator',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: GoogleSignInButton(
          busy: true,
          termsAccepted: true,
          onBusyChanged: (_) {},
        ))));
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    final states = <WidgetState>{WidgetState.disabled};
    final foreground = button.style!.foregroundColor!.resolve(states)!;
    final background = button.style!.backgroundColor!.resolve(states)!;
    expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'printing payment labels and points remain readable on a small light screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: PlaceOrderScreen(
          userEmail: 'customer@example.com',
          paymentEligibility: Future.value(const PaymentEligibility(
              cashOnPickupAllowed: false, hasOrders: false)),
        )));
    await tester.pumpAndSettle();
    final reference = tester.widget<TextField>(find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'GCash Reference Number'));
    final fieldTheme =
        Theme.of(tester.element(find.byWidget(reference))).inputDecorationTheme;
    expect(contrast(fieldTheme.labelStyle!.color!, const Color(0xFFF0FDF4)),
        greaterThanOrEqualTo(4.5));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: PointsSelector(
          subtotal: 250,
          customer: const {'uid': 'u1', 'available': 0, 'pointValueCents': 100},
          onChanged: (_) {},
        ))));
    await tester.pumpAndSettle();
    for (final label in [
      'Use Points',
      'Subtotal ₱250.00',
      'Points discount ₱0.00'
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(contrast(text.style!.color!, const Color(0xFFF0FDF4)),
          greaterThanOrEqualTo(4.5));
    }
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_cancellation.dart';
import 'package:printingshop/services/order_workflow.dart';
import 'package:printingshop/widgets/customer_order_card.dart';
import 'package:printingshop/widgets/order_cancel_dialog.dart';
import 'package:printingshop/theme/dashboard_theme.dart';

void main() {
  test(
      'customer cancellation stops at approval, including stock and approval flags',
      () {
    for (final status in ['Order Submitted', 'For Approval']) {
      expect(canCancelOrder({'status': status}), isTrue);
      expect(
          canCancelOrder({'status': status, 'stockDeducted': true}), isFalse);
      expect(canCancelOrder({'status': status, 'approvedAt': 'approved'}),
          isFalse);
    }
    for (final status in [
      'Approved',
      'Printing',
      'Preparing',
      'Ready for Pickup',
      'Completed',
      'Rejected',
      'Cancelled'
    ]) {
      expect(canCancelOrder({'status': status}), isFalse);
      expect(validOrderTransition('Cancelled', status), isFalse);
    }
  });
  testWidgets(
      'only pending cards offer cancellation, with cancelled records retained',
      (tester) async {
    Future<void> render(String status) async {
      await tester.pumpWidget(MaterialApp(
          theme: DashboardTheme.light,
          home: Scaffold(
              body: SingleChildScrollView(
            child: CustomerOrderCard(
                reference: 'PRNT-123456',
                order: {'status': status, 'service': 'Printing', 'total': 19},
                dateLabel: 'Today',
                specsLabel: 'A4',
                timeline: const Text('Timeline'),
                onAction: (_) {}),
          ))));
      await tester.tap(find.byTooltip('Order Options'));
      await tester.pumpAndSettle();
    }

    await render('Order Submitted');
    expect(find.text('Cancel Order'), findsOneWidget);
    expect(find.text('Delete Order'), findsNothing);
    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();
    await render('Approved');
    expect(find.text('Cancel Order'), findsNothing);
    expect(find.text('This order can no longer be cancelled because it has been approved.'),
        findsOneWidget);
    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();
    await render('Cancelled');
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Timeline'), findsNothing);
    expect(find.text('Cancel Order'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'confirmation accepts an optional reason with a 500-character limit',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
        theme: DashboardTheme.light,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showDialog<String>(
                            context: context,
                            builder: (_) => const OrderCancelDialog(
                                reference: 'PRNT-123456'));
                      },
                      child: const Text('Open'),
                    )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed plans');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel Order'));
    await tester.pumpAndSettle();
    expect(result, 'Changed plans');
    expect(tester.takeException(), isNull);
  });
}

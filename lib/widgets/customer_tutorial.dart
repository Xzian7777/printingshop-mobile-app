import 'package:flutter/material.dart';
import '../theme/dashboard_theme.dart';

class CustomerTutorial extends StatefulWidget {
  const CustomerTutorial({super.key});

  @override
  State<CustomerTutorial> createState() => _CustomerTutorialState();
}

class _CustomerTutorialState extends State<CustomerTutorial> {
  int step = 0;
  static const steps = [
    (
      Icons.waving_hand_outlined,
      'Welcome to Kez C-Em Zek',
      'Order printing services and Store Supplies, track your orders, and contact the shop from your account.'
    ),
    (
      Icons.print_outlined,
      'Choose your service or supplies',
      'Open Order Services to select printing specifications and upload your file. In Store, tap a product to choose the quantity, review its total, and add it to your cart.'
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Your first payment',
      'Use GCash for your first paid order. Check the merchant details and amount, then enter your payment reference. The shop verifies payment manually. Cash on Pickup unlocks after your first payment-verified, completed order.'
    ),
    (
      Icons.receipt_long_outlined,
      'Track orders and get help',
      'Open My Orders to check approval, processing, and pickup status. You can cancel before admin approval. Use the notification bell and chat to follow updates and contact the shop.'
    ),
    (
      Icons.stars_outlined,
      'Earn points and redeem rewards',
      'Earn one point per eligible paid and completed order. Open Rewards to check your balance and available rewards. Points discounts cover up to 50% of the order subtotal.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = steps[step];
    final last = step == steps.length - 1;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(page.$1, color: DashboardTheme.green),
        const SizedBox(width: 12),
        Expanded(
            child: Text(page.$2,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: DashboardTheme.ink))),
      ]),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${step + 1} of ${steps.length}',
              style: const TextStyle(color: DashboardTheme.green)),
          const SizedBox(height: 12),
          Text(page.$3,
              style: const TextStyle(color: DashboardTheme.ink, height: 1.6)),
        ],
      )),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip tutorial')),
        if (step > 0)
          TextButton(
              onPressed: () => setState(() => step--),
              child: const Text('Back')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DashboardTheme.green),
          onPressed: () {
            if (last) {
              Navigator.pop(context, true);
            } else {
              setState(() => step++);
            }
          },
          child: Text(last ? 'Get started' : 'Next'),
        ),
      ],
    );
  }
}

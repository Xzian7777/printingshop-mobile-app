import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loyalty_api.dart';
import '../theme/dashboard_theme.dart';

class PointsSelector extends StatefulWidget {
  final double subtotal;
  final ValueChanged<int> onChanged;
  final Map<String, dynamic>? customer;
  final ValueChanged<double>? onDiscountChanged;
  const PointsSelector(
      {super.key,
      required this.subtotal,
      required this.onChanged,
      this.customer,
      this.onDiscountChanged});
  @override
  State<PointsSelector> createState() => _PointsSelectorState();
}

class _PointsSelectorState extends State<PointsSelector> {
  final controller = TextEditingController();
  Map<String, dynamic>? account;
  String? error;
  bool enabled = false;
  StreamSubscription? subscription;
  @override
  void initState() {
    super.initState();
    load();
    if (widget.customer == null && LoyaltyApi.baseUrl.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null)
        subscription = FirebaseFirestore.instance
            .collection('loyalty_accounts')
            .doc(uid)
            .snapshots()
            .skip(1)
            .listen((_) => load(), onError: (_) {});
    }
  }

  @override
  void didUpdateWidget(covariant PointsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer?['uid'] != widget.customer?['uid']) {
      account = null;
      enabled = false;
      controller.clear();
      load();
    }
    if (int.tryParse(controller.text) != null &&
        int.parse(controller.text) > limit) {
      controller.text = '$limit';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) change();
      });
    }
  }

  Future<void> load() async {
    try {
      final result =
          widget.customer ?? await LoyaltyApi.call('/api/loyalty/me');
      if (mounted) {
        setState(() {
          account = result;
          error = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) change();
        });
      }
    } catch (_) {
      if (mounted)
        setState(() =>
            error = 'Points unavailable. Check the shop server connection.');
    }
  }

  int get available => (account?['available'] as num?)?.toInt() ?? 0;
  int get rate => (account?['pointValueCents'] as num?)?.toInt() ?? 100;
  int get limit =>
      max(0, min(available, (widget.subtotal * 100 / (2 * rate)).floor()));
  void change() {
    final value = enabled ? min(limit, int.tryParse(controller.text) ?? 0) : 0;
    widget.onChanged(value);
    widget.onDiscountChanged?.call(value * rate / 100);
  }

  @override
  Widget build(BuildContext context) {
    final points = enabled ? min(limit, int.tryParse(controller.text) ?? 0) : 0;
    final discount = points * rate / 100;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Points'),
                subtitle: Text(error ??
                    '$available available · maximum $limit points (50%)'),
                value: enabled,
                onChanged: account == null || limit == 0
                    ? null
                    : (value) => setState(() {
                          enabled = value;
                          change();
                        }))),
        if (error != null)
          TextButton(
              onPressed: load, child: const Text('Retry points balance')),
        if (enabled)
          TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16)
              ],
              decoration: InputDecoration(
                  labelText: 'Points to use',
                  helperText: 'Whole points from 0 to $limit'),
              onChanged: (_) => setState(() {
                    if ((int.tryParse(controller.text) ?? 0) > limit)
                      controller.text = '$limit';
                    change();
                  })),
        Text('Subtotal ₱${widget.subtotal.toStringAsFixed(2)}'),
        Text('Points discount ₱${discount.toStringAsFixed(2)}'),
        Text('To pay ₱${(widget.subtotal - discount).toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: DashboardTheme.green)),
        if (account != null)
          Text('Available after reservation ${available - points} points'),
      ]),
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    controller.dispose();
    super.dispose();
  }
}

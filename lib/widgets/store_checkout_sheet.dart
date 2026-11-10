import 'points_selector.dart';
import '../services/store_price.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/admin_catalog_view.dart' show sharedImage;
import '../services/order_validation.dart';
import '../services/supabase_storage_service.dart';
import '../theme/dashboard_theme.dart';
import 'customer_order_card.dart' show orderAmount;

class StorePaymentDetails {
  final String method, reference, merchantAccount, receiptName;
  final File? receipt;
  final int pointsUsed;
  final double pointsDiscount;
  const StorePaymentDetails(
      {required this.method,
      this.pointsUsed = 0,
      this.pointsDiscount = 0,
      this.reference = '',
      this.merchantAccount = '',
      this.receipt,
      this.receiptName = ''});
}

String gcashQrSource(Map<String, dynamic> settings) {
  if (settings['qrImageSource'] == settings['qrUrl'] &&
      (settings['qrImageData'] ?? '').toString().isNotEmpty) {
    return settings['qrImageData'].toString();
  }
  return (settings['qrUrl'] ?? '').toString();
}

class StoreCheckoutSheet extends StatefulWidget {
  final Map<String, int> cart;
  final Map<String, Map<String, dynamic>> products;
  final Stream<Map<String, dynamic>> merchantSettings;
  final ValueChanged<Map<String, int>> onCartChanged;
  final Future<void> Function(BuildContext, List<MapEntry<String, int>>, double,
      StorePaymentDetails) onCheckout;
  const StoreCheckoutSheet(
      {super.key,
      required this.cart,
      required this.products,
      required this.merchantSettings,
      required this.onCartChanged,
      required this.onCheckout});
  @override
  State<StoreCheckoutSheet> createState() => _StoreCheckoutSheetState();
}

class _StoreCheckoutSheetState extends State<StoreCheckoutSheet> {
  late final Map<String, int> cart = Map.of(widget.cart);
  final reference = TextEditingController();
  String method = 'Cash on Pickup';
  int pointsUsed = 0;
  double pointsDiscount = 0;
  File? receipt;
  String receiptName = '';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  void changeQuantity(String id, int quantity) {
    setState(() {
      if (quantity <= 0) {
        cart.remove(id);
      } else {
        cart[id] = quantity;
      }
    });
    widget.onCartChanged(Map.of(cart));
  }

  Future<void> pickReceipt() async {
    try {
      final files = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
      if (files == null || files.files.single.path == null) return;
      final selected = files.files.single;
      final file = File(selected.path!);
      final issue = SupabaseStorageService.validateFile(file, selected.name);
      if (issue != null) throw StateError(issue);
      if (mounted)
        setState(() {
          receipt = file;
          receiptName = selected.name;
          error = null;
        });
    } catch (issue) {
      if (mounted) setState(() => error = issue.toString());
    }
  }

  Future<void> checkout(Map<String, dynamic> merchant,
      List<MapEntry<String, int>> entries, double total) async {
    if (busy) return;
    final issue = OrderValidation.validatePayment(method, reference.text);
    if (issue != null) {
      setState(() => error = issue);
      return;
    }
    if (method == 'GCash' &&
        (merchant['isActive'] == false ||
            (merchant['accountNumber'] ?? '').toString().isEmpty)) {
      setState(() => error = 'GCash is unavailable. Choose Cash on Pickup.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onCheckout(
          context,
          entries,
          total,
          StorePaymentDetails(
              method: method,
              pointsUsed: pointsUsed,
              pointsDiscount: pointsDiscount,
              reference: method == 'GCash' ? reference.text.trim() : '',
              merchantAccount:
                  method == 'GCash' ? '${merchant['accountNumber']}' : '',
              receipt: method == 'GCash' ? receipt : null,
              receiptName: receiptName));
    } catch (issue) {
      if (mounted)
        setState(
            () => error = issue.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
      stream: widget.merchantSettings,
      builder: (context, snapshot) {
        final merchant = snapshot.data ?? {};
        final gcashReady = snapshot.hasData &&
            !snapshot.hasError &&
            merchant['isActive'] != false &&
            (merchant['accountNumber'] ?? '').toString().isNotEmpty;
        final entries = cart.entries
            .where((entry) =>
                entry.value > 0 && widget.products.containsKey(entry.key))
            .toList();
        final validPrices = entries.every((entry) =>
            storePrice(widget.products[entry.key]!['price']) != null);
        final total = entries.fold<double>(
            0,
            (sum, entry) =>
                sum +
                (storePrice(widget.products[entry.key]!['price']) ?? 0) *
                    entry.value);
        final validTotal = total.isFinite && total > 0 && total <= 5000000;
        final displayError = !validPrices
            ? 'A product price needs to be updated by the shop.'
            : total > 5000000
                ? 'Order total cannot exceed 5,000,000.'
                : error;
        return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.9),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(22))),
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Your Cart',
                              style: TextStyle(
                                  color: DashboardTheme.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700))),
                      IconButton(
                          tooltip: 'Close cart',
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              color: DashboardTheme.muted))
                    ]),
                    const Divider(),
                    Flexible(
                        child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                          if (entries.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Your cart is empty.',
                                    style: TextStyle(
                                        color: DashboardTheme.muted))),
                          ...entries.map((entry) {
                            final item = widget.products[entry.key]!;
                            final stock = int.tryParse('${item['stock']}') ?? 0;
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['name'] ?? 'Product'}',
                                          style: const TextStyle(
                                              color: DashboardTheme.ink,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                      Text(
                                          storePrice(item['price']) == null
                                              ? 'Price unavailable'
                                              : '${orderAmount(storePrice(item['price']))} each',
                                          style: const TextStyle(
                                              color: DashboardTheme.muted,
                                              fontSize: 12)),
                                      Row(children: [
                                        IconButton(
                                            tooltip: 'Decrease quantity',
                                            onPressed: busy || entry.value <= 1
                                                ? null
                                                : () => changeQuantity(
                                                    entry.key, entry.value - 1),
                                            icon: const Icon(
                                                Icons.remove_circle_outline)),
                                        Text('${entry.value}',
                                            style: const TextStyle(
                                                color: DashboardTheme.ink)),
                                        IconButton(
                                            tooltip: 'Increase quantity',
                                            onPressed: busy ||
                                                    entry.value >= stock
                                                ? null
                                                : () => changeQuantity(
                                                    entry.key, entry.value + 1),
                                            icon: const Icon(
                                                Icons.add_circle_outline)),
                                        Expanded(
                                            child: Text(
                                                storePrice(item['price']) ==
                                                        null
                                                    ? '—'
                                                    : orderAmount(storePrice(
                                                            item['price'])! *
                                                        entry.value),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                    color: DashboardTheme.ink,
                                                    fontWeight:
                                                        FontWeight.w700))),
                                        IconButton(
                                            tooltip: 'Remove item',
                                            onPressed: busy
                                                ? null
                                                : () => changeQuantity(
                                                    entry.key, 0),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFBE123C))),
                                      ]),
                                      const Divider(),
                                    ]));
                          }),
                          const Text('Payment Method',
                              style: TextStyle(
                                  color: DashboardTheme.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['GCash', 'Cash on Pickup']
                                  .map((payment) => ChoiceChip(
                                      label: Text(payment),
                                      selected: method == payment,
                                      onSelected: busy ||
                                              (payment == 'GCash' &&
                                                  !gcashReady)
                                          ? null
                                          : (_) => setState(() {
                                                method = payment;
                                                error = null;
                                              }),
                                      selectedColor: const Color(0xFFDCFCE7),
                                      labelStyle: TextStyle(
                                          color: method == payment
                                              ? DashboardTheme.green
                                              : DashboardTheme.muted),
                                      backgroundColor: const Color(0xFFF1F5F3)))
                                  .toList()),
                          if (!gcashReady)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    snapshot.connectionState ==
                                            ConnectionState.waiting
                                        ? 'Loading GCash details…'
                                        : 'GCash is currently unavailable.',
                                    style: const TextStyle(
                                        color: DashboardTheme.muted,
                                        fontSize: 12))),
                          if (method == 'GCash' && gcashReady) ...[
                            const SizedBox(height: 16),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Send payment to',
                                          style: TextStyle(
                                              color: DashboardTheme.muted,
                                              fontSize: 12)),
                                      SelectableText(
                                          '${merchant['accountName'] ?? 'GCash'}',
                                          style: const TextStyle(
                                              color: DashboardTheme.ink,
                                              fontWeight: FontWeight.w700)),
                                      SelectableText(
                                          '${merchant['accountNumber']}',
                                          style: const TextStyle(
                                              color: DashboardTheme.ink,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700)),
                                      if (gcashQrSource(merchant).isNotEmpty)
                                        Center(
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                child: sharedImage(
                                                    gcashQrSource(merchant),
                                                    height: 170))),
                                    ])),
                            const SizedBox(height: 12),
                            TextField(
                                controller: reference,
                                onChanged: (_) {
                                  if (error != null)
                                    setState(() => error = null);
                                },
                                enabled: !busy,
                                keyboardType: TextInputType.number,
                                maxLength: 16,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style:
                                    const TextStyle(color: DashboardTheme.ink),
                                decoration: const InputDecoration(
                                    labelText: 'GCash Reference Number',
                                    helperText: '8–16 digits, usually 13.',
                                    border: OutlineInputBorder())),
                            OutlinedButton.icon(
                                onPressed: busy ? null : pickReceipt,
                                icon: const Icon(Icons.receipt_outlined),
                                label: Text(
                                    receipt == null
                                        ? 'Attach receipt (optional)'
                                        : receiptName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                            if (receipt != null)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() {
                                            receipt = null;
                                            receiptName = '';
                                          }),
                                  child: const Text('Remove receipt')),
                          ],
                          const SizedBox(height: 16),
                        ]))),
                    PointsSelector(subtotal: total, onChanged: (value) => setState(() => pointsUsed = value), onDiscountChanged: (value) => setState(() => pointsDiscount = value)),
                    const Divider(),
                    if (displayError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(displayError,
                                style: const TextStyle(
                                    color: Color(0xFFBE123C), fontSize: 12))),
                      ),
                    Row(children: [
                      const Expanded(
                          child: Text('Subtotal',
                              style: TextStyle(
                                  color: DashboardTheme.ink,
                                  fontWeight: FontWeight.w700))),
                      Flexible(
                          child: Text(
                              validPrices && total <= 5000000
                                  ? orderAmount(total)
                                  : '—',
                              style: const TextStyle(
                                  color: DashboardTheme.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)))
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: !validPrices ||
                                    !validTotal ||
                                    busy ||
                                    entries.isEmpty
                                ? null
                                : () => checkout(merchant, entries, total),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    busy ? 'Submitting…' : 'Checkout Order')))),
                  ])),
            ));
      });
}

import '../services/display_text.dart';
import 'package:flutter/material.dart';
import '../theme/dashboard_theme.dart';
import 'dashboard_controls.dart';
import '../services/order_cancellation.dart' show canCancelOrder;

bool isStoreSupplyOrder(Map<String, dynamic> order) {
  final service =
      (order['service'] ?? order['serviceName'] ?? '').toString().toLowerCase();
  final paper = (order['paperSize'] ?? '').toString().toLowerCase();
  return paper.contains('store') ||
      service.startsWith('in-store') ||
      service.contains('store suppl') ||
      (order['items'] is List && (order['items'] as List).isNotEmpty);
}

String orderAmount(dynamic value) {
  final amount =
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final parts = amount.toStringAsFixed(2).split('.');
  final whole =
      parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$whole.${parts.last}';
}

class CustomerOrderCard extends StatelessWidget {
  final String reference;
  final Map<String, dynamic> order;
  final String dateLabel;
  final String specsLabel;
  final Widget timeline;
  final ValueChanged<String> onAction;

  const CustomerOrderCard(
      {super.key,
      required this.reference,
      required this.order,
      required this.dateLabel,
      required this.specsLabel,
      required this.timeline,
      required this.onAction});

  Widget badge(String label, Color foreground, Color background) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: foreground, fontSize: 11, fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    final store = isStoreSupplyOrder(order);
    final service =
        (order['service'] ?? order['serviceName'] ?? 'Document Printing')
            .toString();
    final payment =
        (order['payment'] ?? order['payment_method'] ?? '').toString();
    final status = (order['status'] ?? 'Order Submitted').toString();
    final stopped =
        RegExp('reject|cancel', caseSensitive: false).hasMatch(status);
    final note = (order['customerNote'] ?? order['specialInstructions'] ?? '')
        .toString()
        .trim();
    final file = systemDisplayText(order['fileName'] ?? order['file'] ?? '');
    final url = (order['fileUrl'] ?? order['file_url'] ?? order['url'] ?? '')
        .toString();
    final hasFile = url.startsWith('https://') || url.startsWith('http://');
    final items = order['items'] is List
        ? (order['items'] as List).whereType<Map>().toList()
        : const <Map>[];
    final units = items.fold<int>(
        0,
        (total, item) =>
            total +
            (int.tryParse('${item['qty'] ?? item['quantity'] ?? 1}') ?? 1));
    final summary = store
        ? (items.isEmpty
            ? 'Store Supplies'
            : '${items.length} ${items.length == 1 ? 'item' : 'items'} · $units ${units == 1 ? 'unit' : 'units'}')
        : specsLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE9DF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A172B24), blurRadius: 12, offset: Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(reference,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: DashboardTheme.ink,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13)))),
          const SizedBox(width: 8),
          OrderOptionsButton(
              hasFile: hasFile,
              canReject: false,
              canCancel: canCancelOrder(order),
              onSelected: onAction),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          badge(store ? 'Store Supplies' : 'Print Job', DashboardTheme.green,
              const Color(0xFFDCFCE7)),
          if (payment.isNotEmpty)
            badge(payment, const Color(0xFF1E40AF), const Color(0xFFEFF6FF)),
          badge(
              status.startsWith('Rejected:') ? 'Rejected' : status,
              status == 'Cancelled'
                  ? const Color(0xFF334155)
                  : stopped
                      ? const Color(0xFFBE123C)
                      : DashboardTheme.muted,
              status == 'Cancelled'
                  ? const Color(0xFFE2E8F0)
                  : stopped
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF1F5F3)),
        ]),
        const SizedBox(height: 14),
        if (order.containsKey('pointsUsed')) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(
          'Subtotal ${orderAmount(order['subtotal'] ?? order['total'])} · ${order['pointsUsed']} points used · Discount ${orderAmount(order['pointsDiscount'] ?? 0)} · Earned ${order['pointsEarned'] ?? 0}',
          style: const TextStyle(color: DashboardTheme.muted, fontSize: 11))),
        Text(service,
            style: const TextStyle(
                color: DashboardTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(summary,
            style: const TextStyle(color: DashboardTheme.muted, fontSize: 12)),
        if (hasFile && file.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.attach_file_rounded,
                size: 14, color: DashboardTheme.muted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(file,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: DashboardTheme.muted, fontSize: 12)))
          ]),
        ],
        const SizedBox(height: 12),
        Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  orderAmount(
                      order['total'] ?? order['price'] ?? order['amount']),
                  style: const TextStyle(
                      color: DashboardTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              Text(dateLabel,
                  style: const TextStyle(
                      color: DashboardTheme.muted, fontSize: 11)),
            ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Note: $note',
                  style:
                      const TextStyle(color: Color(0xFF854D0E), fontSize: 12))),
        ],
        const SizedBox(height: 14),
        if (stopped)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  status.startsWith('Rejected:')
                      ? status
                      : 'This order is $status.',
                  style:
                      const TextStyle(color: Color(0xFF9F1239), fontSize: 12)))
        else ...[
          timeline,
          if (!canCancelOrder(order))
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('This order can no longer be cancelled because it has been approved.',
                    style:
                        TextStyle(color: DashboardTheme.muted, fontSize: 12))),
        ],
        if (status == 'Cancelled' &&
            '${order['cancellationReason'] ?? ''}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Reason: ${order['cancellationReason']}',
                  style: const TextStyle(
                      color: DashboardTheme.muted, fontSize: 12))),
      ]),
    );
  }
}

class OrderTimeline extends StatelessWidget {
  final int currentStage;
  final bool store;
  const OrderTimeline(
      {super.key, required this.currentStage, this.store = false});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Submitted',
      'Approved',
      store ? 'Preparing' : 'Printing',
      'Ready',
      'Completed'
    ];
    final icons = [
      Icons.receipt_long_outlined,
      Icons.check_circle_outline,
      store ? Icons.shopping_bag_outlined : Icons.print_outlined,
      Icons.inventory_2_outlined,
      Icons.flag_outlined
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (index) {
            final done = index <= currentStage;
            return Expanded(
                child: Column(children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: done ? DashboardTheme.green : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: done
                              ? DashboardTheme.green
                              : const Color(0xFFCBD5CE))),
                  child: Icon(
                      index < currentStage ? Icons.check_rounded : icons[index],
                      size: 15,
                      color: done ? Colors.white : DashboardTheme.muted)),
              const SizedBox(height: 6),
              Text(labels[index],
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.3,
                      color: done ? DashboardTheme.green : DashboardTheme.muted,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w500)),
            ]));
          })),
    );
  }
}

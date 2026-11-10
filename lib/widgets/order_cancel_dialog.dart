import 'package:flutter/material.dart';

class OrderCancelDialog extends StatefulWidget {
  final String reference;
  const OrderCancelDialog({super.key, required this.reference});
  @override
  State<OrderCancelDialog> createState() => _OrderCancelDialogState();
}

class _OrderCancelDialogState extends State<OrderCancelDialog> {
  final _reason = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                  'Cancel ${widget.reference}? Cancellation is available before admin approval.'),
              const SizedBox(height: 16),
              TextField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder())),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Order')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _reason.text.trim()),
              child: const Text('Cancel Order')),
        ],
      );
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }
}

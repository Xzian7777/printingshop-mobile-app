import 'package:flutter/material.dart';
import '../services/loyalty_api.dart';

Future<Map<String, dynamic>?> pickLoyaltyCustomer(BuildContext context) =>
    showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _CustomerPicker());

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final search = TextEditingController();
  List<dynamic> customers = [];
  bool busy = false;
  String? error;
  Future<void> load() async {
    if (search.text.trim().length < 2) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await LoyaltyApi.call(
          '/api/admin/loyalty/customers?q=${Uri.encodeQueryComponent(search.text.trim())}');
      if (mounted)
        setState(() => customers = result['customers'] as List? ?? []);
    } catch (issue) {
      if (mounted) setState(() => error = '$issue');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Link customer account'),
        content: SizedBox(
            width: 400,
            height: 360,
            child: Column(children: [
              TextField(
                  controller: search,
                  onSubmitted: (_) => load(),
                  decoration: InputDecoration(
                      labelText: 'Name, email or RFID',
                      suffixIcon: IconButton(
                          onPressed: busy ? null : load,
                          icon: const Icon(Icons.search)))),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              Expanded(
                  child: ListView(children: [
                for (final raw in customers)
                  ListTile(
                      title: Text('${raw['name']}'),
                      subtitle: Text(
                          '${raw['email']}\n${raw['available']} available points'),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(
                          context, Map<String, dynamic>.from(raw as Map)))
              ])),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}

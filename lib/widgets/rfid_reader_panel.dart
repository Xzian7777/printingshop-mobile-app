import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loyalty_api.dart';
import '../theme/dashboard_theme.dart';

class RfidReaderPanel extends StatefulWidget {
  const RfidReaderPanel({super.key, this.request = LoyaltyApi.call});
  final Future<Map<String, dynamic>> Function(String,
      {String method, Map<String, dynamic>? data}) request;

  @override
  State<RfidReaderPanel> createState() => _RfidReaderPanelState();
}

class _RfidReaderPanelState extends State<RfidReaderPanel> {
  final readerId = TextEditingController();
  final privateKey = TextEditingController();
  final search = TextEditingController();
  List<Map<String, dynamic>> readers = [];
  List<Map<String, dynamic>> customers = [];
  String? selectedReader;
  String? selectedCustomer;
  String? message;
  bool failed = false;
  bool busy = false;
  bool refreshing = false;
  bool rotateKey = false;
  bool replaceCard = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    readerId.dispose();
    privateKey.dispose();
    search.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get reader {
    for (final item in readers) {
      if (item['readerId'] == selectedReader) return item;
    }
    return null;
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final result = await widget.request('/api/admin/rfid/readers');
      if (!mounted) return;
      setState(() {
        readers = [for (final value in result['readers'] as List) Map<String, dynamic>.from(value as Map)];
        if (!readers.any((item) => item['readerId'] == selectedReader)) {
          selectedReader = readers.isEmpty ? null : readers.first['readerId'] as String;
        }
      });
    } catch (error) {
      if (mounted) setState(() { message = loyaltyErrorMessage(error); failed = true; });
    } finally {
      refreshing = false;
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; failed = false; message = null; });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() { message = loyaltyErrorMessage(error); failed = true; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pair() => perform(() async {
    final result = await widget.request('/api/admin/rfid/readers', method: 'POST', data: {
      'readerId': readerId.text.trim(), 'name': 'Counter reader', 'rotateKey': rotateKey,
    });
    if (!mounted) return;
    setState(() { privateKey.text = result['readerKey'] as String; message = 'Reader paired. Copy the private key into PC bridge setup.'; });
    await refresh();
    if (mounted) setState(() => selectedReader = result['readerId'] as String);
  });

  Future<void> captureCard() => perform(() async {
    if (selectedReader == null) throw StateError('Pair and select a reader first.');
    await widget.request('/api/admin/rfid/capture', method: 'POST', data: {'readerId': selectedReader});
    await refresh();
  });

  Future<void> findCustomers() => perform(() async {
    final query = search.text.trim();
    if (query.length < 2) throw StateError('Enter at least two characters.');
    final result = await widget.request('/api/admin/loyalty/customers?q=${Uri.encodeQueryComponent(query)}');
    if (!mounted) return;
    setState(() {
      customers = [for (final value in result['customers'] as List) Map<String, dynamic>.from(value as Map)];
      selectedCustomer = customers.isEmpty ? null : customers.first['uid'] as String;
      if (customers.isEmpty) message = 'No matching eligible customer accounts.';
    });
  });

  Future<void> enroll() => perform(() async {
    final capture = reader?['capture'] as Map?;
    if (capture?['cardUid'] == null || selectedCustomer == null) {
      throw StateError('Capture a card and select the customer first.');
    }
    final result = await widget.request('/api/admin/rfid/cards', method: 'POST', data: {
      'readerId': selectedReader, 'captureId': capture!['id'], 'uid': selectedCustomer,
      'replaceExisting': replaceCard,
    });
    if (mounted) setState(() => message = 'Card ${result['cardUid']} enrolled. Remove it and tap again after the bridge is ready.');
    await refresh();
  });

  @override
  Widget build(BuildContext context) {
    final capture = reader?['capture'] as Map? ?? {};
    final scan = reader?['lastScan'] as Map? ?? {};
    final expires = DateTime.tryParse('${capture['expiresAt']}');
    final capturing = capture['id'] != null && capture['used'] != true &&
        expires != null && expires.isAfter(DateTime.now());
    final status = capturing
        ? capture['cardUid'] != null
            ? 'Captured ${capture['cardUid']}. Select the customer and enroll.'
            : 'Tap after the bridge console shows “capture card”.'
        : scan['eventId'] != null
            ? '${scan['cardUid']}: ${scan['outcome']} (+${scan['pointsAdded']} point)'
            : 'Connect the paired USB bridge to begin.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('USB RFID reader', style: TextStyle(
            fontWeight: FontWeight.bold, color: DashboardTheme.ink))),
          IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh))]),
        const Text('Each new tap earns 1 point. Remove the card before tapping again.', style: TextStyle(fontSize: 12)),
        TextField(controller: readerId, maxLength: 12, decoration: const InputDecoration(labelText: '12-character reader ID')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: rotateKey,
            title: const Text('Replace existing reader key', style: TextStyle(fontSize: 12)),
            onChanged: busy ? null : (value) => setState(() => rotateKey = value ?? false)),
        ElevatedButton(onPressed: busy ? null : pair, child: const Text('Pair reader')),
        if (privateKey.text.isNotEmpty) ...[
          TextField(controller: privateKey, readOnly: true, obscureText: true,
              decoration: const InputDecoration(labelText: 'Private bridge key')),
          TextButton(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: privateKey.text));
            if (mounted) setState(() => message = 'Private bridge key copied. Save it in PC bridge setup.');
          }, child: const Text('Copy private key')),
        ],
        if (readers.isNotEmpty) DropdownButtonFormField<String>(value: selectedReader,
            isExpanded: true, decoration: const InputDecoration(labelText: 'Registered reader'),
            items: [for (final item in readers) DropdownMenuItem(value: item['readerId'] as String,
              child: Text('${item['name']} (${item['readerId']})', overflow: TextOverflow.ellipsis))],
            onChanged: busy ? null : (value) => setState(() => selectedReader = value)),
        const SizedBox(height: 10),
        Text(status, style: const TextStyle(fontSize: 12)),
        TextButton(onPressed: busy ? null : captureCard, child: const Text('Capture card')),
        TextField(controller: search, decoration: const InputDecoration(labelText: 'Customer email or name')),
        TextButton(onPressed: busy ? null : findCustomers, child: const Text('Find customer')),
        if (customers.isNotEmpty) DropdownButtonFormField<String>(value: selectedCustomer,
            isExpanded: true, decoration: const InputDecoration(labelText: 'Customer account'),
            items: [for (final item in customers) DropdownMenuItem(value: item['uid'] as String,
              child: Text('${item['name']} (${item['email']})', overflow: TextOverflow.ellipsis))],
            onChanged: busy ? null : (value) => setState(() => selectedCustomer = value)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: replaceCard,
            title: const Text("Replace customer's existing physical card", style: TextStyle(fontSize: 12)),
            onChanged: busy ? null : (value) => setState(() => replaceCard = value ?? false)),
        ElevatedButton(onPressed: busy ? null : enroll, child: const Text('Enroll captured card')),
        if (busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!,
            style: TextStyle(fontSize: 12, color: failed ? const Color(0xFFBE123C) : DashboardTheme.green))),
      ])),
    );
  }
}

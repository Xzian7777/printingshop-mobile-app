import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/loyalty_api.dart';
import '../services/local_db_service.dart';
import '../services/supabase_storage_service.dart';
import '../theme/dashboard_theme.dart';

class RewardsScreen extends StatefulWidget {
  final bool isAdmin;
  const RewardsScreen({super.key, this.isAdmin = false});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  Map<String, dynamic> account = {};
  List<dynamic> rewards = [];
  bool busy = false;
  String? error;
  Map<String, dynamic>? pending;
  StreamSubscription? subscription;
  @override
  void initState() {
    super.initState();
    load();
    if (!widget.isAdmin && LoyaltyApi.baseUrl.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null)
        subscription = FirebaseFirestore.instance
            .collection('loyalty_accounts')
            .doc(uid)
            .snapshots()
            .skip(1)
            .listen((_) {
          if (mounted && !busy) load();
        }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await LoyaltyApi.call(widget.isAdmin
          ? '/api/admin/loyalty/rewards'
          : '/api/loyalty/rewards');
      final summary = await LoyaltyApi.call(
          widget.isAdmin ? '/api/admin/loyalty/settings' : '/api/loyalty/me');
      final saved = widget.isAdmin
          ? null
          : await LocalDbService.instance
              .getLoyaltyPending(FirebaseAuth.instance.currentUser!.uid);
      if (mounted)
        setState(() {
          rewards = data['rewards'];
          account = summary;
          pending = saved;
        });
    } catch (issue) {
      if (mounted) setState(() => error = loyaltyErrorMessage(issue));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retry() async {
    setState(() => busy = true);
    try {
      final result = await LoyaltyApi.submitOrder(pending!);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order ${result['orderId']} confirmed.')));
    } catch (issue) {
      if (mounted) {
        await load();
        setState(() => error = loyaltyErrorMessage(issue));
      }
      return;
    }
    await load();
  }

  Future<void> claim(Map<String, dynamic> reward) async {
    if (!canRedeemReward(reward, account)) {
      setState(() =>
          error = 'You do not have enough available points for this reward.');
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text('${reward['name']}'),
                content: Text(
                    'Reserve ${reward['pointsCost']} points for ${reward['quantity']} unit(s)? Points are deducted on approval. Printing rewards require a file.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Continue'))
                ]));
    if (confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{
        'submissionId': LoyaltyApi.submissionId(),
        'rewardId': reward['id'],
        'rewardVersion': reward['updatedAt'],
        'pointsUsed': 0
      };
      if (reward['kind'] == 'service') {
        final selected = await FilePicker.platform.pickFiles();
        if (selected == null || selected.files.single.path == null) return;
        final file = selected.files.single;
        payload['file'] = file.name;
        payload['fileUrl'] = await SupabaseStorageService.uploadFile(
            file: File(file.path!),
            originalFilename: file.name,
            orderId: payload['submissionId']);
      }
      final result = await LoyaltyApi.submitOrder(payload);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Reward order ${result['orderId']} submitted.')));
    } catch (issue) {
      if (mounted) {
        await load();
        setState(() => error = loyaltyErrorMessage(issue));
      }
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await load();
  }

  Future<void> edit([Map<String, dynamic>? reward]) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RewardEditor(initial: reward)));
    await load();
  }

  Future<void> changeRate() async {
    final controller = TextEditingController(
        text: '${(account['settings']?['pointValueCents'] ?? 100) / 100}');
    final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Value of one point'),
                content: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso value')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Save'))
                ]));
    controller.dispose();
    if (value == null) return;
    try {
      await LoyaltyApi.call('/api/admin/loyalty/settings',
          method: 'PUT', data: {'pointValue': value});
      await load();
    } catch (issue) {
      if (mounted) setState(() => error = loyaltyErrorMessage(issue));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: DashboardTheme.light,
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.isAdmin ? 'Rewards Management' : 'My Rewards'),
            actions: [
              IconButton(
                  onPressed: busy ? null : load,
                  tooltip: 'Refresh rewards',
                  icon: const Icon(Icons.refresh))
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!,
                    style: const TextStyle(
                        color: Color(0xFFBE123C), fontSize: 14, height: 1.4))),
          if (!widget.isAdmin)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${account['available'] ?? '—'} available points',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                          Text(
                              '${account['reserved'] ?? 0} reserved · ${account['balance'] ?? 0} total'),
                          const Text(
                              'Earn 1 point per paid completed order. Points discounts cover up to 50%.'),
                        ]))),
          if (pending != null)
            Card(
                child: ListTile(
                    title: const Text('Checkout needs confirmation'),
                    subtitle: const Text(
                        'Retry the saved request before starting another redemption.'),
                    trailing: TextButton(
                        onPressed: busy ? null : retry,
                        child: const Text('Retry')))),
          if (widget.isAdmin)
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  onPressed: busy ? null : () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add reward')),
              OutlinedButton(
                  onPressed: busy ? null : changeRate,
                  child: Text(
                      '1 point = ₱${(account['settings']?['pointValueCents'] ?? 100) / 100}'))
            ]),
          const SizedBox(height: 16),
          const Text('Rewards catalog',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (!busy && rewards.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No rewards available yet.')),
          for (final raw in rewards)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${raw['name']}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('${raw['description'] ?? ''}'),
                          Text(
                              '${raw['quantity']} unit(s) · ${raw['pointsCost']} points${raw['active'] == true ? '' : ' · Disabled'}'),
                          Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                  onPressed: busy ||
                                          (!widget.isAdmin &&
                                              !canRedeemReward(
                                                  Map<String, dynamic>.from(
                                                      raw),
                                                  account))
                                      ? null
                                      : () => widget.isAdmin
                                          ? edit(Map<String, dynamic>.from(raw))
                                          : claim(
                                              Map<String, dynamic>.from(raw)),
                                  child: Text(widget.isAdmin
                                      ? 'Edit reward'
                                      : canRedeemReward(
                                              Map<String, dynamic>.from(raw),
                                              account)
                                          ? 'Redeem reward'
                                          : 'Not enough points'))),
                        ]))),
          if (!widget.isAdmin) ...[
            const SizedBox(height: 20),
            const Text('Points history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            for (final event in account['events'] as List? ?? [])
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${event['type']} · ${event['points']} point(s)'),
                  subtitle: Text(
                      '${event['orderId'] ?? ''}\n${event['createdAt'] ?? ''}'),
                  isThreeLine: true),
          ],
        ]),
      ));
}

class RewardEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const RewardEditor({super.key, this.initial});
  @override
  State<RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends State<RewardEditor> {
  final name = TextEditingController(),
      description = TextEditingController(),
      cost = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      pages = TextEditingController(text: '1'),
      width = TextEditingController(),
      height = TextEditingController();
  List<Map<String, dynamic>> catalog = [];
  Map<String, dynamic>? selected;
  Map<String, dynamic> requirements = {}, specifications = {};
  bool active = true, busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await LoyaltyApi.call('/api/admin/loyalty/catalog');
      final rows = <Map<String, dynamic>>[
        for (final kind in ['product', 'service'])
          for (final raw in data[kind == 'product' ? 'products' : 'services'])
            {...Map<String, dynamic>.from(raw), 'kind': kind}
      ];
      final initial = widget.initial;
      if (initial != null) {
        name.text = '${initial['name']}';
        description.text = '${initial['description'] ?? ''}';
        cost.text = '${initial['pointsCost']}';
        quantity.text = '${initial['quantity']}';
        pages.text = '${initial['pages'] ?? 1}';
        active = initial['active'] == true;
        requirements = Map<String, dynamic>.from(initial['requirements'] ?? {});
        specifications =
            Map<String, dynamic>.from(initial['specifications'] ?? {});
        final dimensions = '${specifications['dimensions'] ?? ''}'
            .replaceAll('ft', '')
            .split('x');
        if (dimensions.length == 2) {
          width.text = dimensions[0].trim();
          height.text = dimensions[1].trim();
        }
        final matches = rows.where((row) =>
            row['kind'] == initial['kind'] &&
            row['id'] == initial['catalogId']);
        if (matches.isNotEmpty) selected = matches.first;
      }
      if (mounted)
        setState(() {
          catalog = rows;
          busy = false;
        });
    } catch (issue) {
      if (mounted)
        setState(() {
          error = loyaltyErrorMessage(issue);
          busy = false;
        });
    }
  }

  Future<void> save() async {
    if (selected == null) {
      setState(() => error = 'Select a catalog item.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (selected!['id'] == 'tarpaulins')
        specifications['dimensions'] = '${width.text}ft x ${height.text}ft';
      final initial = widget.initial;
      await LoyaltyApi.call(
          '/api/admin/loyalty/rewards${initial == null ? '' : '/${initial['id']}'}',
          method: initial == null ? 'POST' : 'PUT',
          data: {
            'name': name.text.trim(),
            'description': description.text.trim(),
            'pointsCost': cost.text,
            'quantity': quantity.text,
            'pages': pages.text,
            'kind': selected!['kind'],
            'catalogId': selected!['id'],
            'active': active,
            'requirements': requirements,
            'specifications': specifications,
          });
      if (mounted) Navigator.pop(context);
    } catch (issue) {
      if (mounted)
        setState(() {
          error = loyaltyErrorMessage(issue);
          busy = false;
        });
    }
  }

  Widget number(TextEditingController controller, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7)
          ],
          decoration: InputDecoration(labelText: label)));
  Widget requirement(Map<String, dynamic> req) {
    final label = '${req['label']}';
    final choices = req['options'] is List
        ? List<String>.from(req['options'])
        : '${req['options'] ?? ''}'
            .split(',')
            .where((x) => x.isNotEmpty)
            .toList();
    if (req['type'] == 'checkboxes') {
      final values = List<String>.from(requirements[label] as List? ?? []);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        Wrap(spacing: 6, children: [
          for (final option in choices)
            FilterChip(
                label: Text(option),
                selected: values.contains(option),
                onSelected: (on) => setState(() {
                      if (on) {
                        values.add(option);
                      } else {
                        values.remove(option);
                      }
                      requirements[label] = values;
                    }))
        ])
      ]);
    }
    if (choices.isNotEmpty)
      return DropdownButtonFormField<String>(
          initialValue: choices.contains(requirements[label])
              ? requirements[label]
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final value in choices)
              DropdownMenuItem(value: value, child: Text(value))
          ],
          onChanged: (value) => requirements[label] = value);
    return TextFormField(
        initialValue: '${requirements[label] ?? ''}',
        maxLength: 150,
        keyboardType:
            req['type'] == 'number' ? TextInputType.number : TextInputType.text,
        inputFormatters: req['type'] == 'number'
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)
              ]
            : [],
        decoration: InputDecoration(labelText: label),
        onChanged: (value) => requirements[label] = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reward details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: selected,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Catalog product or service'),
            items: [
              for (final row in catalog)
                DropdownMenuItem(
                    value: row,
                    child: Text('${row['name']} (${row['kind']})',
                        overflow: TextOverflow.ellipsis))
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                      selected = value;
                      requirements = {};
                      specifications = {};
                    })),
        TextField(
            controller: name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Reward name')),
        TextField(
            controller: description,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Description / package details')),
        number(cost, 'Points cost'),
        number(quantity, 'Quantity'),
        if (selected?['kind'] == 'service') ...[
          number(pages, 'Pages per package'),
          if (selected?['id'] == 'tarpaulins') ...[
            number(width, 'Width in feet'),
            number(height, 'Height in feet')
          ],
          for (final raw in selected!['requirements'] as List? ?? [])
            requirement(Map<String, dynamic>.from(raw)),
        ],
        SwitchListTile(
            title: const Text('Available for redemption'),
            value: active,
            onChanged: busy ? null : (value) => setState(() => active = value)),
        FilledButton(
            onPressed: busy ? null : save, child: const Text('Save reward')),
      ]));
  @override
  void dispose() {
    for (final c in [name, description, cost, quantity, pages, width, height]) {
      c.dispose();
    }
    super.dispose();
  }
}

class LoyaltyBalance extends StatelessWidget {
  const LoyaltyBalance({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text('— PTS');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('loyalty_accounts')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final available = ((data?['balance'] as num?)?.toInt() ?? 0) -
              ((data?['reserved'] as num?)?.toInt() ?? 0);
          return Text(snapshot.hasError ? '— PTS' : '$available PTS',
              style: const TextStyle(
                  color: DashboardTheme.green, fontWeight: FontWeight.w800));
        });
  }
}

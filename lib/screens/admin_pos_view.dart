import '../services/loyalty_api.dart';
import '../widgets/customer_picker.dart';
import '../widgets/points_selector.dart';
import '../services/store_price.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pos_repository.dart';
import '../services/pos_rules.dart';
import '../theme/dashboard_theme.dart';
import '../widgets/customer_order_card.dart' show orderAmount;

class AdminPosView extends StatefulWidget {
  final PosRepository? repository;
  const AdminPosView({super.key, this.repository});
  @override
  State<AdminPosView> createState() => _AdminPosViewState();
}

class _SaleLine {
  final String id, kind, name;
  final TextEditingController qty, price, note;
  _SaleLine(Map<String, dynamic> data)
      : id = '${data['id']}',
        kind = '${data['kind']}',
        name = '${data['name']}',
        qty = TextEditingController(text: '${data['qty'] ?? 1}'),
        price = TextEditingController(
            text: '${data['unitPrice'] ?? data['price'] ?? 0}'),
        note = TextEditingController(text: '${data['note'] ?? ''}');
  Map<String, dynamic> payload() => {
        'id': id,
        'kind': kind,
        'name': name,
        'qty': qty.text,
        'unitPrice': price.text,
        'note': note.text
      };
  void dispose() {
    qty.dispose();
    price.dispose();
    note.dispose();
  }
}

class _AdminPosViewState extends State<AdminPosView> {
  Map<String, dynamic>? _customer, _reward;
  int _pointsUsed = 0;
  double _pointsDiscount = 0;
  Future<void> _chooseCustomer() async {
    final value = await pickLoyaltyCustomer(context);
    if (value != null && mounted) setState(() { _customer = value; _pointsUsed = 0; _pointsDiscount = 0; });
  }
  Future<void> _chooseReward() async {
    try {
      final result = await LoyaltyApi.call('/api/loyalty/rewards');
      if (!mounted) return;
      final reward = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Free reward claim'),
        content: SizedBox(width: 400, height: 300, child: ListView(children: [
          const Text('This starts a separate reward claim. Existing sale lines will be cleared.'),
          for (final row in result['rewards']) ListTile(title: Text('${row['name']}'), subtitle: Text('${row['pointsCost']} points'),
            onTap: () => Navigator.pop(ctx, Map<String, dynamic>.from(row))),
        ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))]));
      if (reward != null && mounted) setState(() { for (final line in _lines) { line.dispose(); } _lines.clear(); _reward = reward; _pointsUsed = 0; _pointsDiscount = 0; });
    } catch (issue) { if (mounted) setState(() => _error = '$issue'); }
  }
  late final _repo = widget.repository ?? PosRepository();
  final _buyer = TextEditingController(),
      _cash = TextEditingController(),
      _reference = TextEditingController();
  final _lines = <_SaleLine>[];
  List<Map<String, dynamic>> _catalog = [], _sales = [];
  Map<String, dynamic>? _pending, _receipt;
  bool _busy = true, _confirmed = false;
  String _payment = 'Cash', _error = '', _search = '', _category = 'all';
  bool get _locked => _busy || _pending != null || _receipt != null;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final pending = await _repo.getDraft();
      if (!mounted) return;
      if (pending != null) {
        _pending = pending;
        _lines.addAll((pending['items'] as List)
            .map((x) => _SaleLine(Map<String, dynamic>.from(x))));
        _buyer.text = '${pending['buyerName'] ?? ''}';
        _cash.text = '${pending['cashReceived'] ?? 0}';
        _reference.text = '${pending['gcashRef'] ?? ''}';
        _payment = '${pending['payment']}';
        _confirmed = pending['paymentConfirmed'] == true;
        _error =
            'A previous sale needs confirmation. Retry it to retrieve the receipt.';
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.catalog(), _repo.history()]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _sales = results[1];
        _busy = false;
        if (_pending == null) {
          for (final line in _lines.where((x) => x.kind == 'product')) {
            final matches = _catalog
                .where((x) => x['kind'] == 'product' && x['id'] == line.id);
            if (matches.isNotEmpty) {
              final current = '${matches.first['price']}';
              if (posCents(current) != posCents(line.price.text)) {
                _error = 'Product prices refreshed. Review the total.';
              }
              line.price.text = current;
            }
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  int _lineTotal(_SaleLine line) {
    try {
      return posCents(line.price.text) * (int.tryParse(line.qty.text) ?? 0);
    } on FormatException {
      return 0;
    }
  }

  int get _total => _lines.fold(0, (value, line) => value + _lineTotal(line));
  int get _change {
    try {
      return max(0, posCents(_cash.text.isEmpty ? 0 : _cash.text) - _total + (_pointsDiscount * 100).round());
    } on FormatException {
      return 0;
    }
  }

  void _add(Map<String, dynamic> item) {
    if (_locked) return;
    if (item['kind'] == 'product' && storePrice(item['price']) == null) {
      setState(() => _error =
          'Update the product price in Store Catalog before selling it.');
      return;
    }
    final matches =
        _lines.where((x) => x.id == item['id'] && x.kind == item['kind']);
    final limit = item['kind'] == 'product'
        ? int.tryParse('${item['stock']}') ?? 0
        : 100000;
    final current =
        matches.isEmpty ? 0 : int.tryParse(matches.first.qty.text) ?? 0;
    if (current >= limit) {
      setState(() => _error = 'The available stock is already in this sale.');
      return;
    }
    if (matches.isEmpty && _lines.length >= 50) {
      setState(() => _error = 'A sale can contain up to 50 items.');
      return;
    }
    setState(() {
      _error = '';
      if (matches.isEmpty) {
        _lines.add(_SaleLine(item));
      } else {
        matches.first.qty.text = '${current + 1}';
      }
    });
  }

  Future<void> _complete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_pending == null) {
        final payload = {
          'submissionId': List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join(),
          'actorUid': _repo.cashier,
          'buyerName': _buyer.text.trim(),
          'customerUid': _customer?['uid'],
          'pointsUsed': _pointsUsed,
          'expectedDiscount': _pointsDiscount,
          'rewardId': _reward?['id'],
          'rewardVersion': _reward?['updatedAt'],
          'items': _lines.map((x) => x.payload()).toList(),
          'expectedTotal': _total / 100,
          'cashReceived': _cash.text.isEmpty ? '0' : _cash.text,
          'payment': _payment,
          'gcashRef': _reference.text.trim(),
          'paymentConfirmed': _confirmed
        };
        if (_reward == null) validatePosSale(
            payload, {for (final x in _catalog) '${x['kind']}/${x['id']}': x}, discountCents: (_pointsDiscount * 100).round());
        // Persist before submitting so connection failures can retry the same sale.
        await _repo.saveDraft(payload);
        _pending = payload;
      }
      final result = await _repo.complete(_pending!);
      await _repo.clearDraft();
      if (!mounted) return;
      setState(() {
        _receipt = result;
        _pending = null;
      });
      await _load();
    } on FormatException catch (error) {
      try {
        if (_pending != null) await _repo.clearDraft();
        if (mounted) {
          setState(() {
            _pending = null;
            _error = error.message;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _error =
              'Unable to clear the rejected attempt. Retry this same sale.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Connection interrupted. Retry this same sale when online to confirm its receipt.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _newSale() {
    for (final line in _lines) {
      line.dispose();
    }
    setState(() {
      _lines.clear();
      _customer = null; _reward = null; _pointsUsed = 0; _pointsDiscount = 0;
      _buyer.clear();
      _cash.clear();
      _reference.clear();
      _payment = 'Cash';
      _confirmed = false;
      _receipt = null;
      _error = '';
    });
  }

  List<String> _receiptLines(Map<String, dynamic> sale) => [
        '${sale['id']} · ${sale['createdAt']}',
        'Buyer: ${sale['buyerName']}',
        '',
        for (final item in sale['items'] as List) ...[
          '${item['name']} x ${item['qty']}',
          '${orderAmount(item['unitPrice'])} each = ${orderAmount(item['lineTotal'])}',
          if ('${item['note'] ?? ''}'.isNotEmpty) '${item['note']}',
        ],
        '',
        'Subtotal: ${orderAmount(sale['subtotal'] ?? sale['total'])}',
        'Points used: ${sale['pointsUsed'] ?? 0} / Discount: ${orderAmount(sale['pointsDiscount'] ?? 0)}',
        'TOTAL: ${orderAmount(sale['total'])}',
        'Points earned: ${sale['pointsEarned'] ?? 0}',
        'Payment: ${sale['payment']}',
        if ('${sale['gcashRef'] ?? ''}'.isNotEmpty)
          'GCash reference: ${sale['gcashRef']}',
        'Received: ${orderAmount(sale['cashReceived'])}',
        'Change: ${orderAmount(sale['change'])}',
      ];

  Future<void> _printReceipt(Map<String, dynamic> sale) async {
    try {
      await const MethodChannel('printingshop/job_ticket')
          .invokeMethod('print', {
        'title': 'POS Receipt ${sale['id']}',
        'lines': _receiptLines(sale),
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to open Android printing.');
    }
  }

  Widget _panel(Widget child) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE5DF))),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: double.infinity, child: child)));

  Widget _catalogView() {
    final visible = _catalog.where((x) =>
        '${x['name']}'.toLowerCase().contains(_search.toLowerCase()) &&
        (_category == 'all' || x['kind'] == _category));
    return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
              labelText: 'Search products or services',
              prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        for (final entry in {
          'all': 'All',
          'product': 'Products',
          'service': 'Services'
        }.entries)
          ChoiceChip(
              label: Text(entry.value),
              selected: _category == entry.key,
              onSelected: (_) => setState(() => _category = entry.key))
      ]),
      const SizedBox(height: 10),
      SizedBox(
          height: 260,
          child: ListView(children: [
            if (_catalog.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Refresh the catalog to load items.')),
            for (final item in visible)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${storePrice(item['price']) == null ? 'Price unavailable' : orderAmount(storePrice(item['price']))} · ${item['kind'] == 'product' ? '${item['stock']} available' : 'Service · set unit price'}'),
                trailing: const Icon(Icons.add_circle_outline,
                    color: DashboardTheme.green),
                enabled: !_locked &&
                    (item['kind'] != 'product' ||
                        (int.tryParse('${item['stock']}') ?? 0) > 0),
                onTap: () => _add(item),
              ),
          ])),
    ]));
  }

  Widget _saleView() =>
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(contentPadding: EdgeInsets.zero,
          title: Text(_customer == null ? 'Guest purchase · no points' : '${_customer!['name']}'),
          subtitle: Text(_customer == null ? 'Link an account to earn or use points.' : '${_customer!['email']}'),
          trailing: TextButton(onPressed: _locked ? null : _chooseCustomer, child: const Text('Link account'))),
        if (_customer != null) TextButton(onPressed: _locked ? null : () => setState(() { _customer = null; _reward = null; _pointsUsed = 0; _pointsDiscount = 0; }), child: const Text('Use guest purchase')),
        if (_customer != null && !_locked) OutlinedButton(onPressed: _chooseReward, child: const Text('Redeem a free reward')),
        if (_reward != null) ListTile(title: Text('${_reward!['name']}'), subtitle: Text('${_reward!['pointsCost']} points · no cash payment'),
          trailing: IconButton(onPressed: _locked ? null : () => setState(() => _reward = null), icon: const Icon(Icons.close))),
        TextField(
            controller: _buyer,
            enabled: !_locked,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: 'Buyer name', hintText: 'Walk-in Customer')),
        if (_lines.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Select an item to start a sale.')),
        for (final line in _lines)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text(line.name,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: 'Remove item',
                      onPressed: _locked
                          ? null
                          : () => setState(() {
                                _lines.remove(line);
                                line.dispose();
                              }),
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFBE123C)))
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: TextField(
                          controller: line.qty,
                          enabled: !_locked,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration:
                              const InputDecoration(labelText: 'Quantity'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: line.kind == 'service'
                          ? TextField(
                              controller: line.price,
                              enabled: !_locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                                LengthLimitingTextInputFormatter(10)
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                  labelText: 'Service unit price'))
                          : Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                  '${orderAmount(double.tryParse(line.price.text) ?? 0)} each'))),
                ]),
                if (line.kind == 'service')
                  TextField(
                      controller: line.note,
                      enabled: !_locked,
                      maxLength: 500,
                      decoration: const InputDecoration(
                          labelText: 'Job details',
                          hintText: 'e.g. A4 black and white, 10 pages')),
                Align(
                    alignment: Alignment.centerRight,
                    child: Text(orderAmount(_lineTotal(line) / 100),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                const Divider(),
              ])),
        const Text('For services, enter the agreed unit price and job details.',
            style: TextStyle(color: DashboardTheme.muted, fontSize: 12)),
        const SizedBox(height: 12),
        _totalRow('Subtotal', _total / 100),
        if (_customer != null && _reward == null && !_locked) PointsSelector(subtotal: _total / 100, customer: _customer, onChanged: (value) => setState(() => _pointsUsed = value), onDiscountChanged: (value) => setState(() => _pointsDiscount = value)),
        _totalRow('To pay', _reward == null ? (_total / 100 - _pointsDiscount) : 0),
        DropdownButtonFormField<String>(
            initialValue: _payment,
            items: [
              for (final value in ['Cash', 'GCash'])
                DropdownMenuItem(value: value, child: Text(value))
            ],
            decoration: const InputDecoration(labelText: 'Payment method'),
            onChanged:
                _locked ? null : (value) => setState(() => _payment = value!)),
        if (_payment == 'Cash') ...[
          TextField(
              controller: _cash,
              enabled: !_locked,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(10)
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Cash received')),
          _totalRow('Change', _change / 100),
        ] else ...[
          TextField(
              controller: _reference,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16)
              ],
              decoration: const InputDecoration(
                  labelText: 'GCash reference number',
                  helperText: '8–16 digits')),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('GCash payment received'),
              value: _confirmed,
              onChanged: _locked
                  ? null
                  : (value) => setState(() => _confirmed = value!)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy || _receipt != null ? null : _complete,
            icon: const Icon(Icons.point_of_sale),
            label: Text(_busy
                ? 'Please wait…'
                : _pending != null
                    ? 'Retry same sale'
                    : 'Complete sale')),
      ]));

  Widget _totalRow(String label, num amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(
            child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(orderAmount(amount),
                        style: const TextStyle(
                            color: DashboardTheme.green,
                            fontSize: 22,
                            fontWeight: FontWeight.w800))))),
      ]));

  Widget _receiptView(Map<String, dynamic> sale, {bool completed = false}) =>
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('KCZ Printing Shop',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 12),
        SelectableText(_receiptLines(sale).join('\n'),
            style: const TextStyle(height: 1.6)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => _printReceipt(sale),
            icon: const Icon(Icons.print),
            label: const Text('Print receipt')),
        if (completed)
          TextButton(
              onPressed: _busy ? null : _newSale,
              child: const Text('New sale')),
      ]));

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('Point of Sale',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Refresh catalog',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        const Text('Counter sales · products and printing services',
            style: TextStyle(color: DashboardTheme.muted)),
        if (_error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error,
                  style: const TextStyle(
                      color: Color(0xFFBE123C), fontWeight: FontWeight.w600))),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        _catalogView(),
        const SizedBox(height: 12),
        _receipt == null
            ? _saleView()
            : _receiptView(_receipt!, completed: true),
        const SizedBox(height: 16),
        _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent counter sales',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (_sales.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No counter sales yet.')),
          for (final sale in _sales)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${sale['id']} · ${sale['buyerName']}'),
                subtitle: Text(orderAmount(sale['total'])),
                trailing: const Icon(Icons.receipt_long),
                onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                        child:
                            SingleChildScrollView(child: _receiptView(sale))))),
        ])),
      ]));

  @override
  void dispose() {
    _buyer.dispose();
    _cash.dispose();
    _reference.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }
}

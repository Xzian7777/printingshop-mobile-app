int posCents(dynamic value) {
  final number = double.tryParse('$value');
  if (number == null || !number.isFinite || number < 0 || number > 5000000) {
    throw const FormatException('Amounts must be between 0 and 5,000,000.');
  }
  return (number * 100 + 0.50000001).floor();
}

Map<String, dynamic> validatePosSale(
    Map<String, dynamic> request, Map<String, Map<String, dynamic>> catalog, {int discountCents = 0}) {
  final buyer = '${request['buyerName'] ?? ''}'.trim();
  final name = buyer.isEmpty ? 'Walk-in Customer' : buyer;
  if (name.runes.length > 100 || name.runes.any((c) => c < 32)) {
    throw const FormatException('Buyer name must be at most 100 characters.');
  }
  final rawLines = request['items'];
  if (rawLines is! List || rawLines.isEmpty || rawLines.length > 50) {
    throw const FormatException('Add between 1 and 50 items.');
  }
  final lines = <Map<String, dynamic>>[];
  final seen = <String>{};
  var total = 0, productTotal = 0, serviceTotal = 0;
  for (final raw in rawLines) {
    if (raw is! Map) throw const FormatException('Invalid POS item.');
    final kind = raw['kind'], id = '${raw['id'] ?? ''}';
    if (!['product', 'service'].contains(kind) ||
        id.isEmpty ||
        id.contains('/') ||
        id.length > 100) {
      throw const FormatException('Invalid POS item.');
    }
    final key = '$kind/$id';
    if (!seen.add(key)) {
      throw const FormatException('Combine repeated items into one line.');
    }
    final item = catalog[key];
    if (item == null ||
        item['archived'] == true ||
        item['isArchived'] == true) {
      throw const FormatException(
          'An item was removed or archived. Refresh the catalog.');
    }
    final text = '${raw['qty']}';
    final qty = int.tryParse(text);
    if (!RegExp(r'^[0-9]{1,6}$').hasMatch(text) ||
        qty == null ||
        qty < 1 ||
        qty > 100000) {
      throw const FormatException(
          'Quantity must be a whole number from 1 to 100,000.');
    }
    final price = kind == 'product'
        ? posCents(item['price'] ?? 0)
        : posCents(raw['unitPrice']);
    if (price <= 0) {
      throw const FormatException('Unit price must be greater than zero.');
    }
    if (kind == 'product') {
      if (posCents(raw['unitPrice']) != price) {
        throw const FormatException(
            'A product price changed. Refresh the catalog.');
      }
      if (qty > (int.tryParse('${item['stock'] ?? 0}') ?? 0)) {
        throw FormatException('Insufficient stock for ${item['name'] ?? id}.');
      }
    }
    final note = '${raw['note'] ?? ''}'.trim();
    if (note.runes.length > 500) {
      throw const FormatException(
          'Service details must be at most 500 characters.');
    }
    total += price * qty;
    if (kind == 'product') {
      productTotal += price * qty;
    } else {
      serviceTotal += price * qty;
    }
    lines.add({
      'kind': kind,
      'id': id,
      'name': item['name'] ?? id,
      'qty': qty,
      'price': price / 100,
      'unitPrice': price / 100,
      'lineTotal': price * qty / 100,
      'note': note,
      'pricingSource': kind == 'product' ? 'catalog' : 'counter_quote'
    });
  }
  if (total <= 0 ||
      total > 500000000 ||
      posCents(request['expectedTotal']) != total) {
    throw const FormatException(
        'The sale total changed or exceeds 5,000,000. Review your items.');
  }
  if (discountCents < 0 || discountCents > total) throw const FormatException('Invalid points discount.');
  total -= discountCents;
  final payment = request['payment'];
  if (!['Cash', 'GCash'].contains(payment)) {
    throw const FormatException('Choose Cash or GCash.');
  }
  final reference = '${request['gcashRef'] ?? ''}'.trim();
  if (payment == 'GCash' &&
      (!RegExp(r'^[0-9]{8,16}$').hasMatch(reference) ||
          request['paymentConfirmed'] != true)) {
    throw const FormatException(
        'Enter the GCash reference and confirm payment was received.');
  }
  final tendered =
      payment == 'Cash' ? posCents(request['cashReceived']) : total;
  if (tendered < total) {
    throw const FormatException('Cash received must cover the total.');
  }
  return {
    'buyerName': name,
    'items': lines,
    'total': total / 100,
    'payment': payment,
    'cashReceived': tendered / 100,
    'change': (tendered - total) / 100,
    'gcashRef': payment == 'GCash' ? reference : '',
    'productTotal': productTotal / 100,
    'serviceTotal': serviceTotal / 100
  };
}

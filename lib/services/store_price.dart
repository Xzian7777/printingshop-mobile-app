/// Existing product prices are limited to five million pesos on both backends.
double? storePrice(dynamic value) {
  if (value == null || value is bool) return null;
  final price = double.tryParse('$value');
  if (price == null || !price.isFinite || price < 0 || price > 5000000) {
    return null;
  }
  return price;
}

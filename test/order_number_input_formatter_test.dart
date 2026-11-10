import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_number_input_formatter.dart';

void main() {
  const old = TextEditingValue(text: '3');
  test('dimensions reject huge pasted values and malformed decimals', () {
    final formatter =
        OrderNumberInputFormatter(maximum: 100, allowDecimals: true);
    for (final text in [
      '9' * 100,
      '0' * 100,
      '101',
      '100.01',
      '-2',
      '1e2',
      '1.234',
      '1..2',
      'abc'
    ]) {
      expect(formatter.formatEditUpdate(old, TextEditingValue(text: text)), old,
          reason: text);
    }
    for (final text in ['', '0', '0.', '0.25', '99.99', '100', '100.00']) {
      expect(formatter.formatEditUpdate(old, TextEditingValue(text: text)).text,
          text);
    }
  });
  test('quantity and pages enforce their limits during typing and paste', () {
    for (final maximum in [5000, 100000]) {
      final formatter = OrderNumberInputFormatter(maximum: maximum);
      for (final text in ['${maximum + 1}', '1.5', '-1', 'a', '1' * 100]) {
        expect(
            formatter.formatEditUpdate(old, TextEditingValue(text: text)), old);
      }
      expect(
          formatter
              .formatEditUpdate(old, TextEditingValue(text: '$maximum'))
              .text,
          '$maximum');
      expect(formatter.formatEditUpdate(old, TextEditingValue.empty),
          TextEditingValue.empty);
    }
  });
}

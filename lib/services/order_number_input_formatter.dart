import 'package:flutter/services.dart';

/// Rejects oversized and malformed edits, including pasted input.
class OrderNumberInputFormatter extends TextInputFormatter {
  final int maximum;
  final bool allowDecimals;

  OrderNumberInputFormatter(
      {required this.maximum, this.allowDecimals = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final digits = maximum.toString().length;
    final pattern = allowDecimals
        ? RegExp('^[0-9]{1,$digits}(\\.[0-9]{0,2})?\$')
        : RegExp('^[0-9]{1,$digits}\$');
    final number = double.tryParse(text);
    if (!pattern.hasMatch(text) || number == null || number > maximum) {
      return oldValue;
    }
    return newValue;
  }
}

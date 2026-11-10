import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_validation.dart';
import 'package:printingshop/services/supabase_storage_service.dart';

void main() {
  String? validate({
    String quantity = '1',
    String pages = '1',
    bool usesPages = true,
    bool isTarpaulin = false,
    String width = '3',
    String height = '4',
    double total = 3,
    String payment = 'GCash Online',
    String reference = '1234567890123',
    String note = '',
  }) =>
      OrderValidation.validate(
        quantity: quantity,
        pages: pages,
        usesPages: usesPages,
        isTarpaulin: isTarpaulin,
        width: width,
        height: height,
        total: total,
        paymentMethod: payment,
        gcashReference: reference,
        note: note,
      );

  test('valid boundaries match the website API', () {
    expect(
        validate(
            quantity: '100000',
            pages: '5000',
            total: 5000000,
            reference: '12345678',
            note: 'a' * 500),
        isNull);
    expect(validate(reference: '1234567890123456'), isNull);
    expect(validate(isTarpaulin: true, width: '0.5', height: '100'), isNull);
  });

  test('invalid quantities and pages never become default values', () {
    for (final value in ['', '0', '-1', '1.5', 'abc', 'NaN', 'Infinity']) {
      expect(validate(quantity: value), isNotNull, reason: 'quantity=$value');
      expect(validate(pages: value), isNotNull, reason: 'pages=$value');
    }
    expect(validate(quantity: '100001'), isNotNull);
    expect(validate(pages: '5001'), isNotNull);
    expect(validate(pages: '', usesPages: false), isNull);
  });

  test('dimensions and totals reject malformed or excessive values', () {
    for (final value in ['', '0', '-1', '101', 'abc', 'NaN', 'Infinity']) {
      expect(validate(isTarpaulin: true, width: value), isNotNull);
      expect(validate(isTarpaulin: true, height: value), isNotNull);
    }
    for (final value in [0.0, -1.0, 5000001.0, double.nan, double.infinity]) {
      expect(validate(total: value), isNotNull);
    }
  });

  test('GCash requires a numeric reference; cash does not', () {
    for (final value in [
      '',
      '1234567',
      '12345678901234567',
      'abcdefgh',
      '1234-5678'
    ]) {
      expect(validate(reference: value), isNotNull);
    }
    expect(validate(payment: 'Cash on Pickup', reference: ''), isNull);
    expect(validate(note: 'a' * 501), isNotNull);
  });

  test('file checks reject missing, empty, oversized and unsupported files',
      () {
    final directory = Directory.systemTemp.createTempSync('order-validation-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/design.pdf');
    expect(SupabaseStorageService.validateFile(file, 'design.pdf'), isNotNull);
    file.writeAsBytesSync([]);
    expect(SupabaseStorageService.validateFile(file, 'design.pdf'), isNotNull);
    file.writeAsBytesSync([1]);
    expect(SupabaseStorageService.validateFile(file, 'design.pdf'), isNull);
    expect(SupabaseStorageService.validateFile(file, 'design.exe'), isNotNull);
    expect(SupabaseStorageService.validateFile(file, '${'a' * 147}.pdf'),
        isNotNull);
    file.openSync(mode: FileMode.append)
      ..truncateSync(SupabaseStorageService.maxFileSizeBytes + 1)
      ..closeSync();
    expect(SupabaseStorageService.validateFile(file, 'design.pdf'), isNotNull);
  });
}

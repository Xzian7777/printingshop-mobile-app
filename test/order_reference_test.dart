import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/order_reference.dart';

class FixedRandom implements Random {
  final int value;
  FixedRandom(this.value);

  @override
  int nextInt(int max) {
    expect(max, 1000000);
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('reference always has six digits including leading zeroes', () {
    expect(generateOrderReference(random: FixedRandom(0)), 'PRNT-000000');
    expect(generateOrderReference(random: FixedRandom(42)), 'PRNT-000042');
    expect(generateOrderReference(random: FixedRandom(999999)), 'PRNT-999999');
    expect(generateOrderReference(), matches(RegExp(r'^PRNT-\d{6}$')));
  });

  test('retry of the same submitted order is idempotent', () {
    final order = <String, dynamic>{
      'email': 'customer@example.com',
      'submissionId': 'original-operation',
    };
    expect(
        isSameOrderSubmission({...order, 'status': 'Approved'}, order), isTrue);
  });

  test('six digit collision from the same customer is a different order', () {
    expect(
        isSameOrderSubmission(
            {'email': 'customer@example.com', 'submissionId': 'first'},
            {'email': 'customer@example.com', 'submissionId': 'second'}),
        isFalse);
    expect(
        isSameOrderSubmission({'email': 'customer@example.com'},
            {'email': 'customer@example.com', 'submissionId': 'new-order'}),
        isFalse);
  });

  test('another customers order cannot be treated as a retry', () {
    expect(
        isSameOrderSubmission(
            {'email': 'first@example.com', 'submissionId': 'operation'},
            {'email': 'second@example.com', 'submissionId': 'operation'}),
        isFalse);
  });

  test('orders queued by previous versions remain compatible', () {
    expect(
        isSameOrderSubmission({'email': 'customer@example.com'},
            {'email': 'customer@example.com'}),
        isTrue);
    expect(
        isSameOrderSubmission(
            {'email': 'customer@example.com', 'submissionId': 'new-order'},
            {'email': 'customer@example.com'}),
        isFalse);
  });
}

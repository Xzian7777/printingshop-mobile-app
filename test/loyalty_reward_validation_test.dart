import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/services/loyalty_api.dart';

void main() {
  const reward = {'active': true, 'pointsCost': 5};
  test('insufficient points display a customer message without exception text',
      () {
    expect(
        loyaltyErrorMessage(
            const FormatException('Insufficient available points.')),
        'You do not have enough available points for this reward.');
    expect(loyaltyErrorMessage(StateError('Connection unavailable.')),
        'Connection unavailable.');
    expect(loyaltyErrorMessage(const FormatException('Reward changed.')),
        'Reward changed.');
  });
  test('redemption is unavailable until a sufficient balance is loaded', () {
    for (final account in [
      {},
      {'available': 0},
      {'available': 4},
      {'available': double.nan}
    ]) {
      expect(
          canRedeemReward(reward, Map<String, dynamic>.from(account)), false);
    }
    expect(canRedeemReward(reward, {'available': 5}), true);
    expect(canRedeemReward(reward, {'available': 10}), true);
  });
  test('disabled or invalid rewards cannot be claimed', () {
    expect(canRedeemReward({...reward, 'active': false}, {'available': 10}),
        false);
    for (final cost in [0, -1, 1.5, double.infinity, 'invalid']) {
      expect(
          canRedeemReward({...reward, 'pointsCost': cost}, {'available': 10}),
          false);
    }
  });
}

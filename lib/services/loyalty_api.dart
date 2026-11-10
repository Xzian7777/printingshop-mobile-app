import 'dart:convert';
import 'local_db_service.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

String loyaltyErrorMessage(Object issue) {
  final message = issue is FormatException
      ? issue.message
      : issue is StateError
          ? issue.message.toString()
          : 'Unable to complete the request. Please try again.';
  if (message.toLowerCase().contains('insufficient') &&
      message.toLowerCase().contains('points')) {
    return 'You do not have enough available points for this reward.';
  }
  return message;
}

bool canRedeemReward(
    Map<String, dynamic> reward, Map<String, dynamic> account) {
  final cost = num.tryParse('${reward['pointsCost']}');
  final available = num.tryParse('${account['available']}');
  return reward['active'] == true &&
      cost != null &&
      cost.isFinite &&
      cost > 0 &&
      cost == cost.truncateToDouble() &&
      available != null &&
      available.isFinite &&
      available >= cost;
}

class LoyaltyApi {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static String submissionId() => List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();

  static Future<Map<String, dynamic>> submitOrder(
      Map<String, dynamic> payload) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final local = LocalDbService.instance;
    final pending = await local.getLoyaltyPending(uid);
    if (pending != null && pending['submissionId'] != payload['submissionId']) {
      throw StateError(
          'A previous checkout needs confirmation. Open Rewards to retry it first.');
    }
    await local.saveLoyaltyPending(uid, payload);
    try {
      final result = await call('/api/loyalty/orders',
          method: 'POST', data: pending ?? payload);
      await local.clearLoyaltyPending(uid);
      return result;
    } on FormatException {
      await local.clearLoyaltyPending(uid);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> call(String path,
      {String method = 'GET', Map<String, dynamic>? data}) async {
    if (baseUrl.isEmpty) {
      throw StateError(
          'Rewards require the shop server. Set API_BASE_URL when building the app.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final token = await user.getIdToken();
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      });
    if (data != null) request.body = jsonEncode(data);
    final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 25)));
    Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw StateError(
          'The shop server returned an invalid response. Retry the same submission.');
    }
    if (response.statusCode >= 400 || result['success'] != true) {
      final message =
          '${result['message'] ?? result['error'] ?? 'Server request failed.'}';
      if ([400, 409].contains(response.statusCode))
        throw FormatException(message);
      throw StateError(message);
    }
    return result;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'loyalty_api.dart';

String? validateResetPassword(String? value, String email) {
  if (value == null || value.isEmpty) return 'Enter a new password.';
  if (value.length < 8 || value.length > 32) return 'Use 8 to 32 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(value) || !RegExp(r'[a-z]').hasMatch(value)) {
    return 'Include uppercase and lowercase letters.';
  }
  if (!RegExp(r'[0-9!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(value)) {
    return 'Include at least one number or symbol.';
  }
  if (RegExp(r'\s').hasMatch(value)) return 'Password must not contain spaces.';
  final prefix = email.split('@').first.toLowerCase();
  if (prefix.length >= 2 && value.toLowerCase().contains(prefix)) {
    return 'Password must not contain your email username.';
  }
  return null;
}

class PasswordResetService {
  PasswordResetService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? LoyaltyApi.baseUrl;
  final http.Client _client;
  final String _baseUrl;
  void close() => _client.close();

  Future<void> requestSignupCode(String email) =>
      _post('/api/request-signup-otp', {'email': email});
  Future<void> register(Map<String, dynamic> data) =>
      _post('/api/signup', data);

  Future<void> requestCode(String email) =>
      _post('/api/forgot-password', {'email': email});
  Future<void> verifyCode(String email, String code) =>
      _post('/api/verify-reset-otp', {'email': email, 'otp': code});
  Future<void> resetPassword(String email, String code, String password) =>
      _post('/api/reset-password', {
        'email': email,
        'otp': code,
        'newPassword': password,
      });

  Future<void> _post(String path, Map<String, dynamic> data) async {
    if (_baseUrl.isEmpty) {
      throw StateError(
          'The shop server URL is missing. Contact the shop administrator.');
    }
    http.Response response;
    try {
      response = await _client
          .post(Uri.parse('${_baseUrl.replaceFirst(RegExp(r"/$"), "")}$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data))
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw StateError(
          'The shop server took too long to respond. Check your connection and try again.');
    } on http.ClientException {
      throw StateError(
          'Unable to reach the shop server. Check your connection and try again.');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw StateError(
          'The shop server returned an invalid response. Please try again later.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
          'The shop server returned an invalid response. Please try again later.');
    }
    if (response.statusCode != 200 || decoded['success'] != true) {
      throw StateError(decoded['message'] is String
          ? decoded['message'] as String
          : 'Unable to complete password recovery. Please try again.');
    }
  }
}

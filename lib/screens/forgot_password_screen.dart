import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_reset_service.dart';
import '../theme/dashboard_theme.dart';
import '../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.service});
  final String initialEmail;
  final PasswordResetService? service;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _service = widget.service ?? PasswordResetService();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  Timer? _timer;
  int _step = 1, _remaining = 0;
  bool _busy = false, _obscure = true;
  String? _error;
  String _verifiedCode = '';
  String get _address => _email.text.trim().toLowerCase();

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [_email, _code, _password, _confirm]) {
      controller.dispose();
    }
    if (widget.service == null) _service.close();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _remaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Unable to complete password recovery. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode() async {
    if (_step == 1 && !_form.currentState!.validate()) return;
    await _run(() async {
      await _service.requestCode(_address);
      if (!mounted) return;
      _code.clear();
      _verifiedCode = '';
      setState(() {
        _step = 2;
        _startCooldown();
      });
    });
  }

  Future<void> _verify() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final code = _code.text.trim();
      await _service.verifyCode(_address, code);
      if (mounted) {
        setState(() {
          _verifiedCode = code;
          _step = 3;
        });
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await _service.resetPassword(_address, _verifiedCode, _password.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  void _back() {
    if (_busy) return;
    if (_step > 1) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: DashboardTheme.light,
        child: PopScope(
            canPop: !_busy,
            child: Scaffold(
              appBar: AppBar(
                  title: const Text('Password recovery'),
                  leading: IconButton(
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded))),
              body: SafeArea(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_busy) const LinearProgressIndicator(),
                          Text(
                              _step == 1
                                  ? 'Forgot password'
                                  : _step == 2
                                      ? 'Verify your email'
                                      : 'Set your app password',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(_step == 1
                              ? 'Enter your registered email to receive a verification code.'
                              : _step == 2
                                  ? 'Enter the six-digit code sent to $_address. The code is valid for five minutes.'
                                  : 'Use this password to sign in with your email. Your Google sign-in uses the same account.'),
                          const SizedBox(height: 20),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Color(0xFFBE123C)))),
                          if (_step == 1)
                            TextFormField(
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                    labelText: 'Registered email',
                                    prefixIcon: Icon(Icons.email_outlined)),
                                validator: AppValidators.validateEmail),
                          if (_step == 2) ...[
                            TextFormField(
                                controller: _code,
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6)
                                ],
                                decoration: const InputDecoration(
                                    labelText: 'Verification code',
                                    prefixIcon: Icon(Icons.security)),
                                validator: (value) => value == null ||
                                        !RegExp(r'^\d{6}$').hasMatch(value)
                                    ? 'Enter the six-digit verification code.'
                                    : null),
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                    onPressed: _busy || _remaining > 0
                                        ? null
                                        : _requestCode,
                                    child: Text(_remaining > 0
                                        ? 'Resend in ${_remaining}s'
                                        : 'Resend code'))),
                          ],
                          if (_step == 3) ...[
                            TextFormField(
                                controller: _password,
                                enabled: !_busy,
                                obscureText: _obscure,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                decoration: InputDecoration(
                                    labelText: 'New password',
                                    suffixIcon: IconButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () => _obscure = !_obscure),
                                        icon: Icon(_obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined))),
                                validator: (value) =>
                                    validateResetPassword(value, _address)),
                            const SizedBox(height: 8),
                            const Text(
                                '8–32 characters, uppercase and lowercase letters, and a number or symbol.',
                                style: TextStyle(
                                    fontSize: 12, color: DashboardTheme.muted)),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _confirm,
                                enabled: !_busy,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Confirm new password'),
                                validator: (value) => value != _password.text
                                    ? 'Passwords do not match.'
                                    : null),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                              height: 48,
                              child: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : _step == 1
                                          ? _requestCode
                                          : _step == 2
                                              ? _verify
                                              : _save,
                                  child: Text(_busy
                                      ? 'Please wait…'
                                      : _step == 1
                                          ? 'Send verification code'
                                          : _step == 2
                                              ? 'Verify code'
                                              : 'Save new password'))),
                        ])),
              )),
            )),
      );
}

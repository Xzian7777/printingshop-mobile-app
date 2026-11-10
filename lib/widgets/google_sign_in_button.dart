import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../services/auth_service.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton(
      {super.key,
      required this.busy,
      required this.termsAccepted,
      required this.onBusyChanged});
  final bool busy;
  final bool termsAccepted;
  final ValueChanged<bool> onBusyChanged;

  Future<void> _signIn(BuildContext context) async {
    if (busy || AuthService.signingIn) return;
    if (!termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please accept the Terms & Conditions to continue with Google.')));
      return;
    }
    onBusyChanged(true);
    try {
      final profile = await AuthService.signInWithGoogle(
        confirmExistingPassword: (email) =>
            confirmGoogleAccountLink(context, email),
      );
      if (!context.mounted || profile == null) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => DashboardScreen(
                  userEmail: profile['email'] as String,
                  isAdmin: profile['role'] == 'admin')),
          (_) => false);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(googleSignInError(error))));
    } finally {
      if (context.mounted) onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(child: Divider(color: Color(0xFFBBF7D0))),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child:
                      Text('or', style: TextStyle(color: Color(0xFF4B7A5E)))),
              Expanded(child: Divider(color: Color(0xFFBBF7D0))),
            ])),
        SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _signIn(context),
              icon: Image.asset('assets/images/google_g.png',
                  width: 20, height: 20),
              label: const Text('Continue with Google',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(color: Color(0xFF747775)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
      ]);
}

/// Password verification occurs before any Google credential is linked.
Future<String?> confirmGoogleAccountLink(BuildContext context, String email) {
  if (!context.mounted) return Future.value(null);
  return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GoogleAccountLinkDialog(email: email));
}

class _GoogleAccountLinkDialog extends StatefulWidget {
  const _GoogleAccountLinkDialog({required this.email});
  final String email;
  @override
  State<_GoogleAccountLinkDialog> createState() =>
      _GoogleAccountLinkDialogState();
}

class _GoogleAccountLinkDialogState extends State<_GoogleAccountLinkDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Link your existing account',
            style: TextStyle(color: Color(0xFF14532D))),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'An account already uses this email. Enter its existing password to link Google and keep your orders and points.',
                        style: TextStyle(color: Color(0xFF374151))),
                    const SizedBox(height: 12),
                    Text(widget.email,
                        style: const TextStyle(color: Color(0xFF14532D))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofocus: true,
                        style: const TextStyle(color: Color(0xFF1F2937)),
                        decoration: const InputDecoration(
                            labelText: 'Existing password',
                            labelStyle: TextStyle(color: Color(0xFF4B7A5E))),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your existing password.'
                            : null),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF15803D)),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _password.text);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white),
              child: const Text('Verify and link Google')),
        ],
      );
}

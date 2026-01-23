import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final VoidCallback onDone;
  const ResetPasswordPage({super.key, required this.onDone});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;

  // Eye toggles
  bool _hideNew = true;

  String? _error;
  String? _msg;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    final newPass = _password.text.trim();
    final confirm = _confirm.text.trim();

    if (newPass.isEmpty) return 'New password cannot be empty.';
    if (newPass.length < 6) return 'Password must be at least 6 characters.';
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (newPass != confirm) return 'Passwords do not match.';
    return null;
  }

  String _friendlySupabaseError(Object e) {
    // Supabase Flutter throws AuthException with a message you can show or map. [web:1199]
    if (e is AuthException) {
      final msg = e.message.trim();

      // Optional mappings (adjust based on what you see in your logs)
      final lower = msg.toLowerCase();
      if (lower.contains('same') && lower.contains('password')) {
        return 'New password must be different from the old password.';
      }
      if (lower.contains('not logged in')) {
        return 'Session expired. Please open the reset link again.';
      }

      // Fallback: show Supabase's message directly (more specific than your generic text). [web:1204]
      return msg.isEmpty ? 'Failed to update password.' : msg;
    }

    return 'Failed to update password. Please try again.';
  }

  Future<void> _update() async {
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _msg = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _msg = null;
    });

    try {
      final res = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text.trim()),
      ); // updateUser(password) is the correct API. [web:1199]

      if (res.user == null) {
        setState(() => _error = 'Failed to update password.');
        return;
      }

      setState(() => _msg = 'Password updated. You can use it to log in.');
      widget.onDone();
    } catch (e) {
      setState(() => _error = _friendlySupabaseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _password,
              obscureText: _hideNew,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hideNew = !_hideNew),
                  icon: Icon(
                    _hideNew ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _update,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_msg != null) ...[const SizedBox(height: 8), Text(_msg!)],
          ],
        ),
      ),
    );
  }
}

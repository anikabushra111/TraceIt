import 'package:flutter/material.dart';
import 'package:trace_it/auth/auth_service.dart';
import 'login_page.dart';

import '../widgets/bd_phone_field.dart';

class SignUpPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onLoginTap;

  const SignUpPage({super.key, this.onBack, this.onLoginTap});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _department = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(); // local part only: 1XXXXXXXXX
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;
  String? _error;
  bool _showPassword = false;

  final _departments = const [
    'CSE',
    'BBA',
    'EEE',
    'CE',
    'THM',
    'Bangla',
    'Islamic Studies',
    'Architecture',
    'Law',
    'Public Health',
  ];
  String? _selectedDepartment;

  @override
  void dispose() {
    _name.dispose();
    _department.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final name = _name.text.trim();
    final dept = _department.text.trim();
    final email = _email.text.trim();
    final pwd = _password.text.trim();

    final local = _onlyDigits(_phone.text).trim();
    if (!BdPhoneField.isValidBdMobileLocalPart(local)) {
      setState(() => _error = 'Invalid BD phone. Use 1XXXXXXXXX (after +880).');
      return;
    }
    final phoneE164 = BdPhoneField.toE164(local);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.signUp(
        email,
        pwd,
        phone: phoneE164,
        name: name,
        department: dept,
      );

      if (!mounted) return;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. Please verify your email, then log in.',
          ),
        ),
      );

      _openLogin();
    } catch (e) {
      print('SIGNUP ERROR: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLogin() {
    if (widget.onLoginTap != null) {
      widget.onLoginTap!();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Sign Up',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Let's help you find your things",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),

                // Name
                Text(
                  'Name',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return 'Please enter your name.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Department
                Text(
                  'Department',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  items: _departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return 'Please select your department.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: const Text('Select your department'),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value;
                      _department.text = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Email
                Text(
                  'Email',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return 'Please enter your email.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Phone number (label outside, no internal label)
                Text(
                  'Phone number',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                BdPhoneField(controller: _phone, enabled: !_loading),
                const SizedBox(height: 6),
                Text(
                  'Enter only the part after +880 (example: 1XXXXXXXXX).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                Text(
                  'Password',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  validator: (v) {
                    final p = (v ?? '').trim();
                    if (p.isEmpty) return 'Please enter your password.';
                    if (p.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm password
                Text(
                  'Confirm Password',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  validator: (v) {
                    final conf = (v ?? '').trim();
                    if (conf.isEmpty) return 'Please confirm your password.';
                    if (conf != _password.text.trim()) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign Up'),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Have an account? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Color(0xFF1F3A93),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

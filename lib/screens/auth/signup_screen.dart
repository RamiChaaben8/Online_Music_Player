// ============================================================
// screens/auth/signup_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  /// Called when the user taps "Already have an account? Sign in"
  /// — switches back in-place without a Navigator push.
  final VoidCallback? onBackToLogin;

  const SignupScreen({super.key, this.onBackToLogin});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  static const _kAccent = Color(0xFF1DB954);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(
            _emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    // AuthGate will automatically show the app shell on success.
    if (!ok && mounted) {
      _showError(
          ref.read(authNotifierProvider).error ?? 'Sign up failed.');
    }
  }

  Future<void> _googleSignIn() async {
    final ok =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!ok && mounted) {
      final err = ref.read(authNotifierProvider).error;
      if (err != null) _showError(err);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.headphones,
                        color: _kAccent, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start listening across all your devices',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFFB3B3B3), fontSize: 14),
                    ),
                    const SizedBox(height: 36),

                    _label('Display Name'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Your name',
                          icon: Icons.person_outline),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('you@example.com',
                          icon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _label('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Min. 6 characters',
                          icon: Icons.lock_outline,
                          suffix: _eyeBtn(_obscurePass, () => setState(
                              () => _obscurePass = !_obscurePass))),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a password';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _label('Confirm Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Repeat password',
                          icon: Icons.lock_outline,
                          suffix: _eyeBtn(_obscureConfirm, () => setState(
                              () => _obscureConfirm = !_obscureConfirm))),
                      validator: (v) => v != _passCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                          textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black))
                            : const Text('Create Account'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(children: const [
                      Expanded(
                          child: Divider(color: Color(0xFF282828))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 13)),
                      ),
                      Expanded(
                          child: Divider(color: Color(0xFF282828))),
                    ]),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                              color: Color(0xFF282828)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                        icon: const Text('G',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4285F4))),
                        label: const Text('Continue with Google',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?',
                            style: TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 14)),
                        TextButton(
                          // Switch back in-place — no Navigator push
                          onPressed: widget.onBackToLogin,
                          child: const Text('Sign in',
                              style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500));

  InputDecoration _deco(String hint,
      {required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon:
          Icon(icon, color: const Color(0xFFB3B3B3), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      hintStyle: const TextStyle(color: Color(0xFF666666)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF282828))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF282828))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  Widget _eyeBtn(bool obscure, VoidCallback onTap) => IconButton(
        icon: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: const Color(0xFFB3B3B3),
          size: 20,
        ),
        onPressed: onTap,
      );
}

// ============================================================
// screens/auth/login_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _showSignup = false;

  static const _kAccent = Color(0xFF1DB954);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(_emailCtrl.text, _passCtrl.text);
    // AuthGate rebuilds automatically on success — no navigation needed.
    if (!ok && mounted) {
      _showError(ref.read(authNotifierProvider).error ?? 'Sign in failed.');
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
    // Switch between login and signup without pushing a new route.
    // This keeps AuthGate as the topmost widget so it can swap in the
    // app shell the moment Firebase fires authStateChanges.
    if (_showSignup) {
      return SignupScreen(onBackToLogin: () => setState(() => _showSignup = false));
    }

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
                      'Tuneify',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFFB3B3B3), fontSize: 15),
                    ),
                    const SizedBox(height: 40),

                    _label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('you@example.com',
                          icon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco('••••••••',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFFB3B3B3),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePass = !_obscurePass),
                          )),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your password'
                          : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ForgotPasswordScreen()),
                        ),
                        child: const Text('Forgot password?',
                            style: TextStyle(
                                color: _kAccent, fontSize: 13)),
                      ),
                    ),

                    const SizedBox(height: 8),

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
                            : const Text('Sign In'),
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
                        const Text("Don't have an account?",
                            style: TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 14)),
                        TextButton(
                          // Switch in-place — no Navigator push
                          onPressed: () =>
                              setState(() => _showSignup = true),
                          child: const Text('Sign up',
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

  InputDecoration _inputDeco(String hint,
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
          borderSide:
              const BorderSide(color: Color(0xFF282828))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF282828))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _kAccent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}

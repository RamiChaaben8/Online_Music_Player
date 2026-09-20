// ============================================================
// screens/auth/delete_account_screen.dart
//
// Allows the user to permanently delete their account.
// Flow:
//   1. Show confirmation warning.
//   2. User types "DELETE" to confirm.
//   3. Delete all Firestore data (users/{uid}/**).
//   4. Delete the Firebase Auth account.
//   5. authStateChanges fires null → AuthGate shows LoginScreen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/auth_service.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmCtrl = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  static const _kConfirmWord = 'DELETE';

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_confirmCtrl.text.trim() != _kConfirmWord) {
      setState(() => _error = 'Please type DELETE to confirm.');
      return;
    }

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw const AuthException('No user signed in.');

      // 1. Stop playback
      await ref.read(playerProvider.notifier).pause().catchError((_) {});

      // 2. Delete all Firestore data first
      await ref.read(firestoreServiceProvider).deleteUserData(user.uid);

      // 3. Delete the Auth account
      await ref.read(authServiceProvider).deleteAccount();

      // AuthGate will respond to the auth state change and show LoginScreen.
      // No explicit navigation needed.
    } on AuthException catch (e) {
      setState(() {
        _isDeleting = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isDeleting = false;
        _error = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        title: const Text('Delete Account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Warning icon ──────────────────────────────────────
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 64),
                  const SizedBox(height: 24),

                  const Text(
                    'Delete Your Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This action is permanent and cannot be undone:',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        SizedBox(height: 10),
                        _BulletPoint('All your playlists will be deleted'),
                        _BulletPoint('All your liked songs will be deleted'),
                        _BulletPoint(
                            'Your playback history will be deleted'),
                        _BulletPoint(
                            'Your account cannot be recovered'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Confirmation input ────────────────────────────────
                  const Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: const TextStyle(
                          color: Color(0xFF666666), letterSpacing: 2),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF282828)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF282828)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ],

                  const SizedBox(height: 24),

                  // ── Delete button ─────────────────────────────────────
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isDeleting ? null : _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                        textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white))
                          : const Text(
                              'Permanently Delete Account'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Cancel ────────────────────────────────────────────
                  TextButton(
                    onPressed:
                        _isDeleting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFFB3B3B3), fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style:
                  TextStyle(color: Colors.redAccent, fontSize: 14)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFB3B3B3), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

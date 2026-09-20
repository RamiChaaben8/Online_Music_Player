// ============================================================
// providers/auth_provider.dart
//
// Exposes:
//   • authServiceProvider   — singleton AuthService
//   • authStateProvider     — StreamProvider<User?> (Firebase stream)
//   • authNotifierProvider  — StateNotifier with isLoading + error
//     for login / signup / google actions driven by the UI.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

// ── Singleton service ─────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ── Raw Firebase auth-state stream ───────────────────────────────────────────
// Use this in AuthGate to decide which tree to show.

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── UI-facing notifier ────────────────────────────────────────────────────────

class AuthNotifierState {
  final bool isLoading;
  final String? error;

  const AuthNotifierState({this.isLoading = false, this.error});

  AuthNotifierState copyWith({bool? isLoading, String? error, bool clearError = false}) {
    return AuthNotifierState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthNotifierState> {
  final AuthService _auth;

  AuthNotifier(this._auth) : super(const AuthNotifierState());

  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.signInWithEmail(email, password);
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.signUpWithEmail(email, password, displayName);
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cred = await _auth.signInWithGoogle();
      state = state.copyWith(isLoading: false);
      return cred != null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _auth.sendPasswordResetEmail(email);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthNotifierState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

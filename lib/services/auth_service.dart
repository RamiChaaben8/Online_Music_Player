// ============================================================
// services/auth_service.dart
//
// Wraps Firebase Auth for Tuneify.
//
// Google Sign-In strategy
// ─────────────────────────────────────────────────────────────
// • Android / iOS  → native GoogleSignIn flow (google_sign_in package).
// • Windows / Linux / Web → google_sign_in also works on Windows via
//   the google_sign_in_web / desktop shims, but the most reliable path
//   on Windows is signInWithPopup via firebase_auth's web support
//   (firebase_auth calls the Google OAuth endpoint in a real browser
//   window via the google_sign_in package's desktop implementation).
//   We use the same GoogleSignIn() call on all platforms; the package
//   selects the correct underlying flow automatically.
//
// Persistent sessions
// ─────────────────────────────────────────────────────────────
// Firebase Auth persists the token in platform-native secure storage by
// default (SharedPreferences on Android, Keychain on iOS, localStorage
// on Web, a local file on Windows/Linux). No extra work is needed.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Current user ───────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email / Password ───────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(displayName.trim());
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  //
  // On Android/iOS the GoogleSignIn package shows the native account picker.
  // On Windows/Linux it opens the system browser to complete OAuth, then
  // passes the idToken back to Firebase. The google_sign_in package handles
  // all of this automatically — we just call signIn().

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use Firebase's built-in popup flow
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      }

      // Mobile / Desktop: google_sign_in package
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    } catch (e) {
      throw AuthException('Google sign-in failed. Please try again.');
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      // Also disconnect Google so the account picker shows next time
      try { await GoogleSignIn().signOut(); } catch (_) {}
      await _auth.signOut();
    } catch (_) {}
  }

  // ── Delete account ─────────────────────────────────────────────────────────
  //
  // Deletes the Firebase Auth account. Firestore data cleanup is done by
  // FirestoreService.deleteUserData() before calling this.

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is signed in.');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
          'For security, please sign out and sign back in before deleting your account.',
        );
      }
      throw AuthException(_friendlyMessage(e));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

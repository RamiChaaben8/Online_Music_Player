// ============================================================
// services/auth_service.dart
//
// Wraps Firebase Auth for Utify.
//
// Persistent sessions
// ─────────────────────────────────────────────────────────────
// Firebase Auth persists the token in platform-native secure storage by
// default (SharedPreferences on Android, Keychain on iOS, localStorage
// on Web, a local file on Windows/Linux). No extra work is needed.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firestore_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _profiles = FirestoreService();

  // ── Current user ───────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userChanges => _auth.userChanges();

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
    String serialCode,
    String username,
  ) async {
    final normalizedCode = serialCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9_-]{8,80}$').hasMatch(normalizedCode)) {
      throw const AuthException('Enter a valid serial code.');
    }

    final codeRef = _firestore.collection('signupCodes').doc(normalizedCode);
    DocumentSnapshot<Map<String, dynamic>> codeSnapshot;
    try {
      codeSnapshot = await codeRef.get();
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Could not validate the serial code.');
    } catch (_) {
      throw const AuthException('Could not validate the serial code. Check your connection and try again.');
    }
    if (!codeSnapshot.exists || codeSnapshot.data()?['enabled'] != true) {
      throw const AuthException(
          'This serial code is invalid or has already been used.');
    }

    UserCredential? credential;
    var profileCreated = false;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      final user = credential.user;
      if (user == null) throw const AuthException('Could not create your account.');
      await _profiles.createPublicProfile(
        user: user,
        username: username,
        displayName: displayName,
      );
      profileCreated = true;
      // A document delete is a single atomic Firestore write. Rules only allow
      // deleting an enabled code, so only one racing signup can consume it.
      await codeRef.delete();
      return credential;
    } catch (e) {
      if (profileCreated && credential?.user != null) {
        try {
          await _profiles.deletePublicProfile(
            uid: credential!.user!.uid,
            username: username,
          );
        } catch (_) {}
      }
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          await _auth.signOut();
        }
      }
      if (e is AuthException) rethrow;
      if (e is FirebaseAuthException) {
        throw AuthException(_friendlyMessage(e));
      }
      if (e is FirebaseException) {
        throw AuthException(e.message ?? 'Could not validate the serial code.');
      }
      throw const AuthException('Could not complete signup. Please try again.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
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

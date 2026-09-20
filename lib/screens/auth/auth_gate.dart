// ============================================================
// screens/auth/auth_gate.dart
//
// Routing guard. Uses a top-level Navigator so the auth screens
// and the app shell are siblings in the same Navigator stack.
// When Firebase fires authStateChanges:
//   • null  → LoginScreen (stack cleared)
//   • User  → app shell   (stack cleared)
// No manual Navigator.push/pop needed anywhere.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/migration_dialog.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const _SplashScreen(),

      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Firebase error:\n$e',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),

      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(libraryProvider.notifier).resetForLogout();
            ref.read(syncProvider.notifier).reset();
          });
          // Return LoginScreen directly — AuthGate IS the navigator decision.
          // No Navigator.push needed; when auth state changes Flutter rebuilds
          // this widget and switches between LoginScreen and child.
          return const LoginScreen();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Prevent re-initialising on every rebuild (e.g. keyboard popups, resizes)
          final syncState = ref.read(syncProvider);
          if (syncState.initialised && syncState.uid == user.uid) return;

          ref.read(libraryProvider.notifier).initForUser(user.uid);
          await ref.read(syncProvider.notifier).init(user.uid);

          // If no device is currently active, this device auto-claims.
          // If another device is already active, this device stays passive.
          final syncService = ref.read(syncProvider.notifier).service;
          if (!syncService.isActive) {
            final active = await ref.read(firestoreServiceProvider).getActiveDevice(user.uid);
            if (active == null) {
              // No active device — claim this one.
              await syncService.claimAsActiveDevice();
            }
            // else: another device is active, stay passive.
          }

          // Restore last playback session — only runs on the active device.
          if (context.mounted) {
            await ref.read(playerProvider.notifier).restoreLastSession();
          }
          if (context.mounted) {
            await MigrationDialog.showIfNeeded(context, ref, user.uid);
          }
        });

        return child;
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones, color: Color(0xFF1DB954), size: 64),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF1DB954)),
          ],
        ),
      ),
    );
  }
}

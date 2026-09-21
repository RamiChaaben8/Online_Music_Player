import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../screens/auth/delete_account_screen.dart';
import '../screens/privacy_settings_screen.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    return GestureDetector(
      onTap: () => showAccountMenu(context, ref),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF535353),
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? const Icon(Icons.person_outline, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

void showAccountMenu(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF282828),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF555555),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title:
                const Text('Sign Out', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(playerProvider.notifier)
                  .pause()
                  .catchError((_) {});
              await ref.read(authServiceProvider).signOut();
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.white70),
            title: const Text('Privacy', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivacySettingsScreen(user: user),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

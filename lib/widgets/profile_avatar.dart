import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../screens/auth/delete_account_screen.dart';
import '../screens/privacy_settings_screen.dart';
import '../services/firestore_service.dart';
import 'update_dialog.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value ??
        ref.read(authServiceProvider).currentUser;
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
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ListTile(
              leading: const Icon(Icons.system_update_alt, color: Colors.white70),
              title: const Text('Check for Updates', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showUpdateDialog(context, ref);
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white70),
            title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final user = ref.read(authServiceProvider).currentUser;
              if (user == null) return;
              final nameController = TextEditingController(text: user.displayName ?? '');
              final photoController = TextEditingController(text: user.photoURL ?? '');
              final saved = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Edit Profile'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: nameController, maxLength: 50, decoration: const InputDecoration(labelText: 'Display name')),
                    TextField(controller: photoController, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Profile image URL')),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () async {
                      try {
                        await FirestoreService().updateOwnProfile(user: user, displayName: nameController.text, photoURL: photoController.text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    }, child: const Text('Save')),
                  ],
                ),
              );
              nameController.dispose();
              photoController.dispose();
              if (saved == true && context.mounted) ref.invalidate(authStateProvider);
            },
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../providers/guest_session_provider.dart';
import '../screens/privacy_settings_screen.dart';
import '../services/firestore_service.dart';
import '../desktop/theme/desktop_theme.dart';
import 'update_dialog.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value ??
        ref.read(authServiceProvider).currentUser;
    final theme = context.appTheme;
    return GestureDetector(
      onTap: () => showAccountMenu(context, ref),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: theme.highlightElevated,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Icon(Icons.person_outline, color: theme.iconDefault, size: 22)
            : null,
      ),
    );
  }
}

void showAccountMenu(BuildContext context, WidgetRef ref) {
  if (ref.read(guestSessionProvider)) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guest mode'),
        content: const Text(
            'Would you like to leave guest mode and go to the sign-in page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stay as guest'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(guestSessionProvider.notifier).leaveGuest();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Go to sign in'),
          ),
        ],
      ),
    );
    return;
  }

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close account menu',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final user = ref.read(authServiceProvider).currentUser;
      final screenWidth = MediaQuery.sizeOf(dialogContext).width;
      final panelWidth = (screenWidth * 0.84).clamp(0.0, 360.0).toDouble();
      final theme = dialogContext.appTheme;
      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: dialogContext.appTheme.card,
          elevation: 20,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: user?.photoURL?.isNotEmpty == true
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL?.isNotEmpty == true
                            ? null
                            : Icon(Icons.person_outline, color: theme.iconDefault),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.displayName?.isNotEmpty == true
                                ? user!.displayName!
                                : 'Utify account',
                                style: TextStyle(color: theme.text, fontSize: 16, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (user?.email != null)
                              Text(user!.email!, style: TextStyle(color: theme.subtext, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close, color: theme.iconDefault),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ListTile(
              leading: Icon(Icons.system_update_alt, color: theme.iconDefault),
              title: Text('Check for Updates', style: TextStyle(color: theme.text)),
              onTap: () {
                Navigator.pop(dialogContext);
                showUpdateDialog(context, ref);
              },
            ),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: theme.iconDefault),
            title: Text('Edit Profile', style: TextStyle(color: theme.text)),
            onTap: () async {
              Navigator.pop(dialogContext);
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
            leading: Icon(Icons.lock_outline, color: theme.iconDefault),
            title: Text('Privacy', style: TextStyle(color: theme.text)),
            onTap: () {
              Navigator.pop(dialogContext);
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
                  ])),
                  Divider(height: 1, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(Icons.logout, color: theme.notificationError),
                    title: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: theme.notificationError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await ref
                          .read(playerProvider.notifier)
                          .pause()
                          .catchError((_) {});
                      await ref.read(authServiceProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
      position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

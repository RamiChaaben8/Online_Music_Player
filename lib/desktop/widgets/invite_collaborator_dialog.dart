import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../theme/desktop_theme.dart';

Future<String?> showCollaboratorInviteDialog(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  if (playlist.sharedId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Make this playlist collaborative before inviting.'),
      ),
    );
    return null;
  }

  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in before inviting friends.')),
    );
    return null;
  }

  final friendsNotifier = ref.read(friendsProvider.notifier);
  friendsNotifier.initForUser(uid);
  await friendsNotifier.refresh();
  final friends = ref.read(friendsProvider).accepted;

  if (!context.mounted) return null;
  if (friends.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('You do not have any accepted friends yet.')),
    );
    return null;
  }

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.appTheme.card,
      title: Text(
        'Invite to playlist',
        style: TextStyle(color: context.appTheme.text),
      ),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: friends.length,
          separatorBuilder: (_, __) =>
              Divider(color: context.appTheme.shadow, height: 1),
          itemBuilder: (_, index) {
            final friend = friends[index];
            final profile = friend.profile;
            final displayName = profile?.displayName.trim();
            final name = displayName?.isNotEmpty == true
                ? displayName!
                : 'Friend ${index + 1}';
            final subtitle = profile?.username.trim();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundImage: profile?.photoURL.isNotEmpty == true
                    ? NetworkImage(profile!.photoURL)
                    : null,
                child: profile?.photoURL.isNotEmpty == true
                    ? null
                    : const Icon(Icons.person),
              ),
              title: Text(name, style: TextStyle(color: context.appTheme.text)),
              subtitle: subtitle?.isNotEmpty == true
                  ? Text('@$subtitle',
                      style: TextStyle(color: context.appTheme.subtext))
                  : null,
              trailing:
                  Icon(Icons.person_add_alt_1, color: context.appTheme.button),
              onTap: () => Navigator.pop(dialogContext, friend.otherUid),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child:
              Text('Cancel', style: TextStyle(color: context.appTheme.button)),
        ),
      ],
    ),
  );
}

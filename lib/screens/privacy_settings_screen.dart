import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import '../providers/presence_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  final User user;

  const PrivacySettingsScreen({super.key, required this.user});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  final _service = FirestoreService();
  Map<String, bool> _privacy = const {
    'showOnlineStatus': true,
    'showActivity': true,
    'allowFriendRequests': true,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.getPublicProfile(widget.user.uid);
    if (!mounted) return;
    setState(() {
      if (profile != null) _privacy = profile.privacy;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final old = _privacy;
    final next = {...old, key: value};
    setState(() => _privacy = next);
    try {
      await _service.updatePrivacy(widget.user.uid, next);
      await ref.read(presenceProvider.notifier).updatePrivacy(next);
    } catch (_) {
      if (mounted) {
        setState(() => _privacy = old);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update privacy settings.')),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    try {
      await _service.updatePrivacy(widget.user.uid, _privacy);
      await ref.read(presenceProvider.notifier).updatePrivacy(_privacy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save privacy settings: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: FilledButton.icon(
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save privacy settings'),
                  ),
                ),
                _toggle(
                  'Show my online status',
                  'Friends can see when you are online.',
                  'showOnlineStatus',
                ),
                _toggle(
                  'Show what I am listening to',
                  'Friends can see your current track.',
                  'showActivity',
                ),
                _toggle(
                  'Allow friend requests',
                  'Let other users send you friend requests.',
                  'allowFriendRequests',
                ),
              ],
            ),
    );
  }

  Widget _toggle(String title, String subtitle, String key) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: _privacy[key] ?? true,
      onChanged: (value) => _set(key, value),
    );
  }
}

// ============================================================
// widgets/migration_dialog.dart
//
// Shown once on first login when the user has existing local
// playlists or liked songs. Offers to upload them to Firestore.
//
// Usage
// ─────────────────────────────────────────────────────────────
// Call MigrationDialog.showIfNeeded(context, ref) from auth_gate
// (post-frame callback) after the user signs in.
//
// The "already migrated" flag is stored in SharedPreferences so
// the dialog never shows again for this install.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/library_provider.dart';
import '../providers/sync_provider.dart';

class MigrationDialog extends ConsumerStatefulWidget {
  final String uid;

  const MigrationDialog({super.key, required this.uid});

  // ── Entry point ────────────────────────────────────────────────────────────

  static Future<void> showIfNeeded(
      BuildContext context, WidgetRef ref, String uid) async {
    // Only run once per install
    final prefs = await SharedPreferences.getInstance();
    final key = 'migration_done_$uid';
    if (prefs.getBool(key) == true) return;

    // Only show if there is local data worth migrating
    final library = ref.read(libraryProvider);
    final hasData =
        library.likedSongs.isNotEmpty || library.playlists.isNotEmpty;
    if (!hasData) {
      await prefs.setBool(key, true);
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: MigrationDialog(uid: uid),
      ),
    );
    await prefs.setBool(key, true);
  }

  @override
  ConsumerState<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends ConsumerState<MigrationDialog> {
  bool _isUploading = false;
  String? _error;
  bool _done = false;

  static const _kAccent = Color(0xFF1DB954);

  Future<void> _upload() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final library = ref.read(libraryProvider);
      final fs = ref.read(firestoreServiceProvider);

      // Upload liked songs
      if (library.likedSongs.isNotEmpty) {
        await fs.migrateLikedSongs(widget.uid, library.likedSongs);
      }

      // Upload each playlist
      for (final playlist in library.playlists) {
        await fs.migratePlaylist(widget.uid, playlist);
      }

      setState(() => _done = true);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed. You can try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final likedCount = library.likedSongs.length;
    final playlistCount = library.playlists.length;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Import Local Library',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: _done
          ? _buildSuccess()
          : _buildBody(likedCount, playlistCount),
      actions: _done
          ? [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.black),
                child: const Text('Done'),
              ),
            ]
          : [
              TextButton(
                onPressed: _isUploading
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Skip',
                    style: TextStyle(color: Color(0xFFB3B3B3))),
              ),
              ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.black),
                child: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Upload'),
              ),
            ],
    );
  }

  Widget _buildBody(int likedCount, int playlistCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You have local data that can be uploaded to your account so it syncs across devices:',
          style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (likedCount > 0)
          _Row(Icons.favorite, '$likedCount liked song${likedCount == 1 ? '' : 's'}'),
        if (playlistCount > 0)
          _Row(Icons.queue_music,
              '$playlistCount playlist${playlistCount == 1 ? '' : 's'}'),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildSuccess() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF1DB954), size: 48),
        SizedBox(height: 12),
        Text(
          'Your library has been uploaded successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Row(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1DB954), size: 18),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

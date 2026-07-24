// ============================================================
// screens/library_screen.dart
//
// Library tab: Liked Songs, Recently Played, custom playlists.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../models/playlist.dart';
import '../screens/playlist_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create playlist',
            onPressed: () => _showCreatePlaylistDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Liked Songs ────────────────────────────────────────────────
          _LibraryItemTile(
            icon: Icons.favorite,
            iconColor: const Color(0xFF1DB954),
            title: 'Liked Songs',
            subtitle: '${library.likedSongs.length} songs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(
                  title: 'Liked Songs',
                  songs: library.likedSongs,
                  icon: Icons.favorite,
                ),
              ),
            ),
          ),

          // ── Recently Played ────────────────────────────────────────────
          _LibraryItemTile(
            icon: Icons.history,
            iconColor: const Color(0xFF3D79F3),
            title: 'Recently Played',
            subtitle: '${library.recentlyPlayed.length} songs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(
                  title: 'Recently Played',
                  songs: library.recentlyPlayed,
                  icon: Icons.history,
                ),
              ),
            ),
          ),

          if (library.playlists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'MY PLAYLISTS',
                style: TextStyle(
                  color: Color(0xFFB3B3B3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ...library.playlists.map((pl) => _PlaylistTile(playlist: pl)),
          ],

          if (library.playlists.isEmpty && library.likedSongs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.library_music, size: 64, color: Color(0xFF3A3A3A)),
                  const SizedBox(height: 16),
                  Text(
                    'Build your library',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Like songs or create playlists to see them here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(libraryProvider.notifier).createPlaylist(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}

// ─── Generic library row ───────────────────────────────────────────────────

class _LibraryItemTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LibraryItemTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
      onTap: onTap,
    );
  }
}

// ─── Playlist tile with rename/delete actions ──────────────────────────────

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: playlist.coverThumbnail != null
            ? Image.network(
                playlist.coverThumbnail!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${playlist.songs.length} songs',
        style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            title: playlist.name,
            songs: playlist.songs,
            playlistKey: playlist.key as int?,
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFFB3B3B3)),
        color: const Color(0xFF282828),
        onSelected: (action) {
          if (action == 'rename') {
            _showRenameDialog(context, ref, playlist);
          } else if (action == 'delete') {
            _showDeleteDialog(context, ref, playlist);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'rename',
            child: Text('Rename', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF282828),
      child: const Icon(Icons.queue_music, color: Color(0xFF3A3A3A)),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(libraryProvider.notifier).renamePlaylist(
                      playlist.key as int,
                      controller.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Playlist?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: const TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).deletePlaylist(playlist.key as int);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

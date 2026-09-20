// ============================================================
// screens/library_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../providers/local_music_provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../screens/playlist_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import 'auth/delete_account_screen.dart';

/// Which songs to show in playlist/library screens.
enum SongFilter { all, local, online }

// Shared filter state so PlaylistScreen can read it too.
final songFilterProvider = StateProvider<SongFilter>((_) => SongFilter.all);

/// Applies [filter] to [songs], returning the matching subset.
List<Song> applyFilter(List<Song> songs, SongFilter filter) {
  switch (filter) {
    case SongFilter.all:
      return songs;
    case SongFilter.local:
      return songs.where((s) => s.isLocal).toList();
    case SongFilter.online:
      return songs.where((s) => !s.isLocal).toList();
  }
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final localState = ref.watch(localMusicProvider);
    final filter = ref.watch(songFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create playlist',
            onPressed: () => _showCreatePlaylistDialog(context, ref),
          ),
          // Account menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            onSelected: (v) async {
              if (v == 'signout') {
                await ref.read(playerProvider.notifier).pause().catchError((_) {});
                await ref.read(authServiceProvider).signOut();
              } else if (v == 'delete') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DeleteAccountScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.white70),
                    SizedBox(width: 10),
                    Text('Sign Out'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Delete Account',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Firestore loading bar ───────────────────────────────────────
          if (library.isLoading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF1A1A1A),
              color: Color(0xFF1DB954),
              minHeight: 2,
            ),
          // ── Filter chips ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter == SongFilter.all,
                  onTap: () =>
                      ref.read(songFilterProvider.notifier).state = SongFilter.all,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Local',
                  icon: Icons.folder_outlined,
                  iconColor: const Color(0xFF1DB954),
                  selected: filter == SongFilter.local,
                  onTap: () =>
                      ref.read(songFilterProvider.notifier).state = SongFilter.local,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Online',
                  icon: Icons.cloud_outlined,
                  iconColor: const Color(0xFF3D79F3),
                  selected: filter == SongFilter.online,
                  onTap: () =>
                      ref.read(songFilterProvider.notifier).state = SongFilter.online,
                ),
                if (localState.isScanning) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ],
                const Spacer(),
                if (!localState.isScanning)
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        size: 20, color: Color(0xFFB3B3B3)),
                    tooltip: 'Rescan local music',
                    onPressed: () =>
                        ref.read(localMusicProvider.notifier).scan(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF282828)),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Local Music — only show when filter is All or Local
                if (filter != SongFilter.online) ...[
                  _LibraryItemTile(
                    icon: Icons.folder_open,
                    iconColor: const Color(0xFF1DB954),
                    title: 'Local Music',
                    subtitle: localState.isScanning
                        ? 'Scanning…'
                        : '${localState.songs.length} downloaded songs',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistScreen(
                          title: 'Local Music',
                          songs: localState.songs,
                          icon: Icons.folder_open,
                          forcedFilter: SongFilter.local,
                        ),
                      ),
                    ),
                  ),
                ],

                // Liked Songs — only show when filter is All or Online
                if (filter != SongFilter.local) ...[
                  _LibraryItemTile(
                    icon: Icons.favorite,
                    iconColor: const Color(0xFF1DB954),
                    title: 'Liked Songs',
                    subtitle:
                        '${applyFilter(library.likedSongs, filter).length} songs',
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

                  // Recently Played
                  _LibraryItemTile(
                    icon: Icons.history,
                    iconColor: const Color(0xFF3D79F3),
                    title: 'Recently Played',
                    subtitle:
                        '${applyFilter(library.recentlyPlayed, filter).length} songs',
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
                ],

                // Custom playlists
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

                if (library.playlists.isEmpty &&
                    library.likedSongs.isEmpty &&
                    localState.songs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.library_music,
                            size: 64, color: Color(0xFF3A3A3A)),
                        const SizedBox(height: 16),
                        Text(
                          'Build your library',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Like songs, download them, or create playlists.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
        title:
            const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(libraryProvider.notifier)
                    .createPlaylist(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ───────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1DB954).withOpacity(0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1DB954)
                : const Color(0xFF3A3A3A),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? const Color(0xFF1DB954)
                      : iconColor ?? const Color(0xFFB3B3B3)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1DB954) : const Color(0xFFB3B3B3),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic library row ──────────────────────────────────────────────────

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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
      onTap: onTap,
    );
  }
}

// ─── Playlist tile with rename/delete ─────────────────────────────────────

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      title: Text(playlist.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('${playlist.songs.length} songs',
          style:
              const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            title: playlist.name,
            songs: playlist.songs,
            playlist: playlist,
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
              child: Text('Rename',
                  style: TextStyle(color: Colors.white))),
          const PopupMenuItem(
              value: 'delete',
              child:
                  Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFF282828),
        child: const Icon(Icons.queue_music, color: Color(0xFF3A3A3A)),
      );

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Rename Playlist',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFB3B3B3)))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(libraryProvider.notifier).renamePlaylistObj(
                    playlist, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Playlist playlist) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Playlist?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: const TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFB3B3B3)))),
          TextButton(
            onPressed: () {
              ref
                  .read(libraryProvider.notifier)
                  .deletePlaylistObj(playlist);
              Navigator.pop(context);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

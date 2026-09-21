// ============================================================
// screens/library_screen.dart  — Spotify-style mobile library
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/library_provider.dart';
import '../providers/local_music_provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../screens/playlist_screen.dart';
import '../widgets/import_playlist_dialog.dart';
import '../widgets/profile_avatar.dart';

/// Which songs to show in playlist/library screens.
enum SongFilter { all, local, online }

const _playlistVisibilityValues = ['private', 'friends', 'public'];

String _playlistVisibilityLabel(String value) {
  switch (value) {
    case 'friends':
      return 'Friends';
    case 'public':
      return 'Public';
    default:
      return 'Private';
  }
}

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

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _gridView = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final localState = ref.watch(localMusicProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Spotify-style header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Profile avatar — tap to open account menu
                  const ProfileAvatar(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Import playlist
                  IconButton(
                    icon: const Icon(Icons.playlist_add,
                        color: Colors.white, size: 26),
                    onPressed: () => showImportPlaylistDialog(context, ref),
                    tooltip: 'Import playlist',
                  ),
                  // Create (+)
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () => _showCreatePlaylistDialog(context, ref),
                    tooltip: 'Create playlist',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Filter chips ──────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SpotifyChip(
                      label: 'Playlists', selected: true, onTap: () {}),
                  const SizedBox(width: 8),
                  _SpotifyChip(
                    label: 'Local',
                    selected: false,
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
              ),
            ),

            const SizedBox(height: 16),

            // ── Recents bar + grid toggle ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.swap_vert,
                      color: Color(0xFFB3B3B3), size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    'Recents',
                    style: TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _gridView = !_gridView),
                    child: Icon(
                      _gridView ? Icons.list : Icons.grid_view,
                      color: const Color(0xFFB3B3B3),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Loading bar ───────────────────────────────────────────────
            if (library.isLoading)
              const LinearProgressIndicator(
                backgroundColor: Color(0xFF1A1A1A),
                color: Color(0xFF1DB954),
                minHeight: 2,
              ),

            // ── Playlist list ─────────────────────────────────────────────
            Expanded(
              child: _gridView
                  ? _buildGridView(context, library, localState)
                  : _buildListView(context, library, localState),
            ),
          ],
        ),
      ),
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────

  Widget _buildListView(
      BuildContext context, LibraryState library, LocalMusicState localState) {
    final items = _buildItems(library, localState);
    if (items.isEmpty) {
      return _emptyState(context);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }

  // ── Grid view ──────────────────────────────────────────────────────────────

  Widget _buildGridView(
      BuildContext context, LibraryState library, LocalMusicState localState) {
    final playlists = library.playlists;
    if (playlists.isEmpty) return _emptyState(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: playlists.length,
      itemBuilder: (_, i) => _PlaylistGridCard(playlist: playlists[i]),
    );
  }

  List<Widget> _buildItems(LibraryState library, LocalMusicState localState) {
    final items = <Widget>[];

    // Liked Songs
    items.add(_SpotifyPlaylistTile(
      thumbnail: null,
      isFavourite: true,
      title: 'Liked Songs',
      subtitle: 'Playlist • ${library.likedSongs.length} songs',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          title: 'Liked Songs',
          songs: library.likedSongs,
          icon: Icons.favorite,
        ),
      )),
    ));

    // Recently Played
    if (library.recentlyPlayed.isNotEmpty) {
      items.add(_SpotifyPlaylistTile(
        thumbnail: library.recentlyPlayed.first.thumbnailUrl,
        title: 'Recently Played',
        subtitle: 'Playlist • ${library.recentlyPlayed.length} songs',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            title: 'Recently Played',
            songs: library.recentlyPlayed,
            icon: Icons.history,
          ),
        )),
      ));
    }

    // Local Music
    if (localState.songs.isNotEmpty) {
      items.add(_SpotifyPlaylistTile(
        thumbnail: null,
        title: 'Local Music',
        subtitle: 'Playlist • ${localState.songs.length} songs',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            title: 'Local Music',
            songs: localState.songs,
            icon: Icons.folder_open,
            forcedFilter: SongFilter.local,
          ),
        )),
      ));
    }

    // Custom playlists
    for (final pl in library.playlists) {
      items.add(_SpotifyPlaylistTile(
        playlist: pl,
        thumbnail: pl.coverThumbnail,
        title: pl.name,
        subtitle: 'Playlist • ${pl.songs.length} songs',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            title: pl.name,
            songs: pl.songs,
            playlist: pl,
          ),
        )),
        onMoreTap: () => _showPlaylistOptions(context, pl),
      ));
    }

    return items;
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music, size: 64, color: Color(0xFF3A3A3A)),
            const SizedBox(height: 16),
            const Text(
              'Build your library',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Like songs, download them, or create playlists.',
              style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    var visibility = 'private';
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title:
              const Text('New Playlist', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Playlist name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(labelText: 'Privacy'),
                dropdownColor: const Color(0xFF282828),
                style: const TextStyle(color: Colors.white),
                items: _playlistVisibilityValues
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(_playlistVisibilityLabel(v)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => visibility = v ?? 'private'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFB3B3B3))),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(libraryProvider.notifier).createPlaylist(
                        controller.text.trim(),
                        visibility: visibility,
                      );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Create',
                  style: TextStyle(color: Color(0xFF1DB954))),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, Playlist pl) {
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
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title:
                  const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, pl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined, color: Colors.white70),
              title: Text(
                  'Visibility: ${_playlistVisibilityLabel(pl.visibility)}',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showVisibilityMenu(context, pl);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, pl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
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
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFB3B3B3)))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(libraryProvider.notifier)
                    .renamePlaylistObj(playlist, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Playlist?',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${playlist.name}"?',
            style: const TextStyle(color: Color(0xFFB3B3B3))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFB3B3B3)))),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).deletePlaylistObj(playlist);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showVisibilityMenu(BuildContext context, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in ['private', 'friends', 'public'])
              RadioListTile<String>(
                value: v,
                groupValue: playlist.visibility,
                title: Text(_playlistVisibilityLabel(v),
                    style: const TextStyle(color: Colors.white)),
                onChanged: (next) {
                  if (next != null) {
                    ref
                        .read(libraryProvider.notifier)
                        .setPlaylistVisibility(playlist, next);
                    Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Spotify playlist tile ─────────────────────────────────────────────────────

class _SpotifyPlaylistTile extends StatelessWidget {
  final String? thumbnail;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final Playlist? playlist;
  final bool isFavourite;

  const _SpotifyPlaylistTile({
    required this.thumbnail,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onMoreTap,
    this.playlist,
    this.isFavourite = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: _buildThumbnail(),
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onMoreTap != null
          ? IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFFB3B3B3)),
              onPressed: onMoreTap,
            )
          : null,
    );
  }

  Widget _buildThumbnail() {
    if (isFavourite) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A90D9), Color(0xFF9B59B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 28),
      );
    }

    if (thumbnail != null && thumbnail!.isNotEmpty) {
      // Multi-thumbnail mosaic for playlists with songs
      if (playlist != null && playlist!.songs.length >= 4) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 56,
            height: 56,
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              children: playlist!.songs.take(4).map((s) {
                return CachedNetworkImage(
                  imageUrl: s.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF282828)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF282828)),
                );
              }).toList(),
            ),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: thumbnail!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 26),
      );
}

// ─── Grid card ─────────────────────────────────────────────────────────────────

class _PlaylistGridCard extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistGridCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaylistScreen(
          title: playlist.name,
          songs: playlist.songs,
          playlist: playlist,
        ),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildCover(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            '${playlist.songs.length} songs',
            maxLines: 1,
            style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCover() {
    if (playlist.songs.length >= 4) {
      return GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: playlist.songs.take(4).map((s) {
          return CachedNetworkImage(
            imageUrl: s.thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF282828)),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF282828)),
          );
        }).toList(),
      );
    }
    if (playlist.coverThumbnail != null) {
      return CachedNetworkImage(
        imageUrl: playlist.coverThumbnail!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFF282828)),
        errorWidget: (_, __, ___) => Container(color: const Color(0xFF282828)),
      );
    }
    return Container(
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 40),
    );
  }
}

// ─── Spotify pill chip ─────────────────────────────────────────────────────────

class _SpotifyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpotifyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

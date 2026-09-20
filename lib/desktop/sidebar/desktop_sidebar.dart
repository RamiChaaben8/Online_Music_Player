// ============================================================
// desktop/sidebar/desktop_sidebar.dart
// Left panel — 300px, playlists + library navigation.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../providers/library_provider.dart';
import '../theme/desktop_theme.dart';

class DesktopSidebar extends ConsumerWidget {
  final Playlist? selectedPlaylist;
  final void Function(Playlist?) onPlaylistSelected;

  const DesktopSidebar({
    super.key,
    required this.selectedPlaylist,
    required this.onPlaylistSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);

    return Container(
      width: kSidebarWidth,
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.library_music, color: kTextSecondary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Your Library',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showCreatePlaylistDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16, color: kAccent),
                  label: const Text(
                    'Create',
                    style: TextStyle(color: kAccent, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_full,
                      color: kTextSecondary, size: 16),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // ── Filter chip ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3321),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Playlists',
                style: TextStyle(
                  color: kAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Search row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.search, color: kTextSecondary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Recents',
                    style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.list, color: kTextSecondary, size: 18),
              ],
            ),
          ),

          const Divider(color: kBorderColor, height: 16, thickness: 0.5),

          // ── Playlists list ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                // Playlists
                if (library.playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No playlists yet.\nTap + Create to add one.',
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...library.playlists.map((playlist) {
                    final isActive = selectedPlaylist?.name == playlist.name;
                    return _PlaylistTile(
                      playlist: playlist,
                      isActive: isActive,
                      onTap: () => onPlaylistSelected(
                          isActive ? null : playlist),
                    );
                  }),

                const Divider(
                    color: kBorderColor, height: 24, thickness: 0.5),

                // Liked Songs row
                if (library.likedSongs.isNotEmpty) ...[
                  _LibraryItemTile(
                    icon: Icons.favorite,
                    iconColor: const Color(0xFF7B4FE9),
                    bgColor: const Color(0xFF2A1A4A),
                    title: 'Liked Songs',
                    subtitle: '${library.likedSongs.length} songs',
                    onTap: () {},
                  ),
                ],

                // Recently played
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Recently Played',
                    style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8),
                  ),
                ),
                ...library.recentlyPlayed.take(10).map((song) {
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _thumb(song.thumbnailUrl, 36),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      song.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 11),
                    ),
                    onTap: () {},
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(String url, double size) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFF4A2C7A),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 16),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
          width: size, height: size, color: const Color(0xFF4A2C7A)),
      errorWidget: (_, __, ___) => Container(
        width: size,
        height: size,
        color: const Color(0xFF4A2C7A),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 14),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelLight,
        title: const Text('New Playlist',
            style: TextStyle(color: kTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: kTextSecondary),
            filled: true,
            fillColor: kCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(libraryProvider.notifier).createPlaylist(name);
    }
  }
}

// ─── Playlist tile ────────────────────────────────────────────────────────────

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.playlist,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl = playlist.songs.isNotEmpty
        ? playlist.songs.first.thumbnailUrl
        : '';

    return Material(
      color: isActive
          ? const Color(0xFF1A2A1A)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbUrl.isEmpty
                    ? Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF4A2C7A),
                        child: const Icon(Icons.queue_music,
                            color: Colors.white54, size: 22),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumbUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF4A2C7A)),
                        errorWidget: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF4A2C7A),
                          child: const Icon(Icons.queue_music,
                              color: Colors.white54, size: 22),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive ? kAccent : kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Playlist • ${playlist.songs.length} songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Library item tile (liked songs etc.) ────────────────────────────────────

class _LibraryItemTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LibraryItemTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: kTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kTextSecondary, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

// ============================================================
// screens/playlist_screen.dart
//
// Shows songs in a playlist (or Liked Songs / Recently Played).
// Supports removing songs from editable playlists.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/song_tile.dart';

class PlaylistScreen extends ConsumerWidget {
  final String title;
  final List<Song> songs;
  final int? playlistKey; // null for built-in lists (liked, recent)
  final IconData? icon;

  const PlaylistScreen({
    super.key,
    required this.title,
    required this.songs,
    this.playlistKey,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _PlaylistHeader(title: title, songs: songs, icon: icon),
            ),
          ),

          // ── Play all button ────────────────────────────────────────────
          if (songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: () => ref
                      .read(playerProvider.notifier)
                      .playSong(songs.first, queue: songs),
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: const Text('Play all', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),

          // ── Song list ──────────────────────────────────────────────────
          if (songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No songs yet', style: TextStyle(color: Color(0xFFB3B3B3))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final song = songs[i];
                  final isCurrent = playerState.currentSong?.id == song.id;
                  return SongTile(
                    song: song,
                    isPlaying: isCurrent && playerState.isPlaying,
                    isSelected: isCurrent,
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .playSong(song, queue: songs),
                    trailing: playlistKey != null
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Color(0xFFB3B3B3)),
                            onPressed: () => ref
                                .read(libraryProvider.notifier)
                                .removeSongFromPlaylist(playlistKey!, song.id),
                          )
                        : null,
                  );
                },
                childCount: songs.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Playlist header with mosaic art ─────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final IconData? icon;

  const _PlaylistHeader({required this.title, required this.songs, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Album art mosaic / icon
            if (songs.isNotEmpty && songs.first.thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  songs.first.thumbnailUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _iconBox(),
                ),
              )
            else
              _iconBox(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            Text(
              '${songs.length} songs',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon ?? Icons.queue_music, color: const Color(0xFF3A3A3A), size: 56),
    );
  }
}

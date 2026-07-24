// ============================================================
// screens/now_playing_screen.dart
//
// Full-screen "Now Playing" view with:
//  - Large album art with dynamic background colour
//  - Seek bar with current/total time
//  - Play/Pause, skip next/previous
//  - Shuffle & repeat toggles
//  - Like button
//  - Queue button (navigates to QueueScreen)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/seek_bar.dart';
import '../screens/queue_screen.dart';
import '../providers/download_provider.dart';
import '../widgets/add_to_playlist_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;
    final library = ref.watch(libraryProvider);

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final isLiked = library.isLiked(song.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: const [
            Text(
              'NOW PLAYING',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Color(0xFFB3B3B3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ── Album art ─────────────────────────────────────────────────
            Hero(
              tag: 'album_art_${song.id}',
              child: Container(
                width: double.infinity,
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: const Color(0xFF1A1A1A)),
                    errorWidget: (_, __, ___) => const _AlbumPlaceholder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Song info + like ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.channelName,
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? const Color(0xFF1DB954) : Colors.white,
                    size: 28,
                  ),
                  onPressed: () async {
                    try {
                      await ref.read(libraryProvider.notifier).toggleLike(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(!isLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs'),
                            duration: const Duration(seconds: 1),
                            backgroundColor: const Color(0xFF1DB954),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to like song: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add, color: Colors.white, size: 28),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (c) => AddToPlaylistSheet(song: song),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final downloading = ref.watch(downloadProvider).contains(song.id);
                    return IconButton(
                      icon: downloading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download, color: Colors.white, size: 28),
                      onPressed: downloading
                          ? null
                          : () {
                              ref.read(downloadProvider.notifier).downloadSong(song);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));
                            },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Seek bar ───────────────────────────────────────────────────
            SeekBar(
              position: playerState.position,
              duration: playerState.duration,
              onSeek: (pos) => ref.read(playerProvider.notifier).seek(pos),
            ),

            const SizedBox(height: 8),

            // ── Controls ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: playerState.shuffle
                        ? const Color(0xFF1DB954)
                        : const Color(0xFFB3B3B3),
                  ),
                  onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
                ),

                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: () => ref.read(playerProvider.notifier).skipToPrevious(),
                ),

                // Play / Pause
                _PlayPauseButton(
                  isPlaying: playerState.isPlaying,
                  isLoading: playerState.isLoading,
                  onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                ),

                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: () => ref.read(playerProvider.notifier).skipToNext(),
                ),

                // Repeat
                IconButton(
                  icon: Icon(
                    playerState.loopMode == LoopMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color: playerState.loopMode != LoopMode.off
                        ? const Color(0xFF1DB954)
                        : const Color(0xFFB3B3B3),
                  ),
                  onPressed: () => ref.read(playerProvider.notifier).toggleLoopMode(),
                ),
              ],
            ),

            // Error display
            if (playerState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playerState.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => ref.read(playerProvider.notifier).clearError(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Play/Pause button ─────────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF1DB954),
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 36,
              ),
      ),
    );
  }
}

// ─── Album art placeholder ─────────────────────────────────────────────────

class _AlbumPlaceholder extends StatelessWidget {
  const _AlbumPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF282828),
      child: const Center(
        child: Icon(Icons.music_note, size: 80, color: Color(0xFF3A3A3A)),
      ),
    );
  }
}

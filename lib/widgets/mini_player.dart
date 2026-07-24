// ============================================================
// widgets/mini_player.dart
//
// Persistent mini-player bar shown above the bottom nav bar.
// Tapping it opens the full NowPlayingScreen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NowPlayingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      ),
      child: Container(
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Hero(
              tag: 'album_art_${song.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF282828), width: 68, height: 68),
                  errorWidget: (_, __, ___) => Container(
                    width: 68,
                    height: 68,
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A)),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Title & artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Loading / Play-Pause / Skip
            if (playerState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
                ),
              )
            else ...[
              IconButton(
                icon: Icon(
                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: () => ref.read(playerProvider.notifier).skipToNext(),
              ),
            ],

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

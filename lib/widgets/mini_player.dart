// ============================================================
// widgets/mini_player.dart
//
// Spotify-style mini-player bar shown above the bottom nav bar.
//
// Layout:
//   ┌──────────────────────────────────────────────────────────┐
//   │  ▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  (thin green progress bar)  │
//   │  [thumb]  Title • Artist        |◀  ▶  ▶|  cast         │
//   │           Next: Song name                                │
//   └──────────────────────────────────────────────────────────┘
//
// Tapping the body opens NowPlayingScreen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'device_picker.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    final queue = playerState.queue;
    final idx = playerState.currentIndex;
    final nextSong =
        queue.length > 1 ? queue[(idx + 1) % queue.length] : null;

    // Progress fraction (0.0 – 1.0); clamp to avoid NaN when duration is zero
    final progress = playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context),
      child: Container(
        // No extra margin — sits flush above the nav bar like Spotify
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(
            top: BorderSide(color: Color(0xFF282828), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Thin green progress bar ──────────────────────────────
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF333333),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1DB954)),
              ),
            ),

            // ── Content row ──────────────────────────────────────────
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  // ── Thumbnail ──────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF282828),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFF282828),
                        child: const Icon(Icons.music_note,
                            color: Color(0xFF3A3A3A), size: 22),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Title, artist & next ───────────────────────────
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title • Channel
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: ' • ${song.channelName}',
                                style: const TextStyle(
                                  color: Color(0xFFB3B3B3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (nextSong != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                'Next: ',
                                style: TextStyle(
                                  color: Color(0xFF1DB954),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  nextSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFB3B3B3),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Controls ───────────────────────────────────────
                  if (playerState.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                    )
                  else ...[
                    // Skip previous
                    _MiniButton(
                      icon: Icons.skip_previous,
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .skipToPrevious(),
                    ),
                    // Play / Pause
                    _MiniButton(
                      icon: playerState.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 28,
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .togglePlayPause(),
                    ),
                    // Skip next
                    _MiniButton(
                      icon: Icons.skip_next,
                      onTap: () =>
                          ref.read(playerProvider.notifier).skipToNext(),
                    ),
                    // Cast / device picker
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: DevicePickerButton(size: 18),
                    ),
                  ],

                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ─── Compact icon button ────────────────────────────────────────────────────

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36,
        height: 48,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

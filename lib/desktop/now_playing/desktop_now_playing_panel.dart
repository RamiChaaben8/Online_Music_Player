// ============================================================
// desktop/now_playing/desktop_now_playing_panel.dart
//
// Right panel showing a video preview of the currently playing
// YouTube track. Uses VideoPreviewWidget (video_player + fvp)
// instead of a WebView embed, so embed restrictions (Error 153)
// are irrelevant — we stream the raw muxed MP4 directly.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_provider.dart';
import '../../widgets/video_preview_widget.dart';
import '../theme/desktop_theme.dart';

class DesktopNowPlayingPanel extends ConsumerWidget {
  const DesktopNowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    return Container(
      width: kNowPlayingWidth,
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        child: song == null || song.isLocal
            ? const _Placeholder()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // ── Video preview ──────────────────────────────────────
                  Positioned.fill(
                    child: _FullscreenVideo(videoId: song.id),
                  ),

                  // ── Bottom gradient ────────────────────────────────────
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 180,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xF0000000)],
                        ),
                      ),
                    ),
                  ),

                  // ── Song info overlay ──────────────────────────────────
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 10, color: Colors.black)
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(blurRadius: 8, color: Colors.black)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.check_circle,
                            color: kAccent, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Full-screen video that covers the panel ──────────────────────────────────
// Wraps VideoPreviewWidget and stretches it to fill available space using
// a FittedBox so the video aspect ratio is maintained (cover behaviour).

class _FullscreenVideo extends StatelessWidget {
  final String videoId;
  const _FullscreenVideo({required this.videoId});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: VideoPreviewWidget(
        videoId: videoId,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ── Placeholder when nothing is playing ──────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kCardColor,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_video, color: Colors.white12, size: 72),
          SizedBox(height: 16),
          Text(
            'Play a song to\nsee the video',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

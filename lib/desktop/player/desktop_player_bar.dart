// ============================================================
// desktop/player/desktop_player_bar.dart
// Bottom 80px player bar with progress, controls, and volume.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/player_provider.dart';
import '../theme/desktop_theme.dart';

class DesktopPlayerBar extends ConsumerStatefulWidget {
  const DesktopPlayerBar({super.key});

  @override
  ConsumerState<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends ConsumerState<DesktopPlayerBar> {
  double _volume = 0.8;
  bool _draggingProgress = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Apply initial volume to the underlying player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyVolume(_volume);
    });
  }

  void _applyVolume(double v) {
    try {
      ref.read(audioHandlerProvider).service.player.setVolume(v);
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final song = ps.currentSong;

    final position = ps.position;
    final duration = ps.duration;
    final progressFraction = (duration.inMilliseconds > 0 && !_draggingProgress)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : (_draggingProgress ? _dragProgress : 0.0);

    return Container(
      color: kBgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Progress bar ──────────────────────────────────────────────
          _ProgressBar(
            fraction: progressFraction,
            position: position,
            duration: duration,
            onSeek: (fraction) {
              final target = Duration(
                  milliseconds:
                      (fraction * duration.inMilliseconds).toInt());
              ref.read(playerProvider.notifier).seek(target);
            },
            onDragStart: (f) => setState(() {
              _draggingProgress = true;
              _dragProgress = f;
            }),
            onDragUpdate: (f) => setState(() => _dragProgress = f),
            onDragEnd: (f) {
              setState(() => _draggingProgress = false);
              final target = Duration(
                  milliseconds:
                      (f * duration.inMilliseconds).toInt());
              ref.read(playerProvider.notifier).seek(target);
            },
          ),

          // ── Controls row ──────────────────────────────────────────────
          SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left: song info
                  Expanded(child: _SongInfo(song: song)),

                  // Center: transport controls
                  Expanded(
                    child: _TransportControls(
                      isPlaying: ps.isPlaying,
                      isLoading: ps.isLoading,
                      shuffle: ps.shuffle,
                      loopMode: ps.loopMode,
                      onPlayPause: () =>
                          ref.read(playerProvider.notifier).togglePlayPause(),
                      onPrev: () =>
                          ref.read(playerProvider.notifier).skipToPrevious(),
                      onNext: () =>
                          ref.read(playerProvider.notifier).skipToNext(),
                      onShuffle: () =>
                          ref.read(playerProvider.notifier).toggleShuffle(),
                      onRepeat: () =>
                          ref.read(playerProvider.notifier).toggleLoopMode(),
                    ),
                  ),

                  // Right: volume + extra controls
                  Expanded(
                    child: _VolumeControls(
                      volume: _volume,
                      onVolumeChanged: (v) {
                        setState(() => _volume = v);
                        _applyVolume(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double fraction;
  final Duration position;
  final Duration duration;
  final void Function(double) onSeek;
  final void Function(double) onDragStart;
  final void Function(double) onDragUpdate;
  final void Function(double) onDragEnd;

  const _ProgressBar({
    required this.fraction,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _fmt(position),
            style:
                const TextStyle(color: kTextSecondary, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    onSeek(f);
                  },
                  onHorizontalDragStart: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    onDragStart(f);
                  },
                  onHorizontalDragUpdate: (d) {
                    final f = (d.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    onDragUpdate(f);
                  },
                  onHorizontalDragEnd: (_) => onDragEnd(fraction),
                  child: SizedBox(
                    height: 16,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Track background
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Progress fill
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: kAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Thumb
                          Positioned(
                            left: (fraction * constraints.maxWidth - 5)
                                .clamp(0.0, constraints.maxWidth - 10),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(duration),
            style:
                const TextStyle(color: kTextSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Song info (left 1/3) ─────────────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  final dynamic song;
  const _SongInfo({required this.song});

  @override
  Widget build(BuildContext context) {
    if (song == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: (song.thumbnailUrl as String).isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: song.thumbnailUrl as String,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 48, height: 48, color: kCardColor),
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: kCardColor,
                    child: const Icon(Icons.music_note,
                        color: Colors.white54, size: 20),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  color: kCardColor,
                  child: const Icon(Icons.music_note,
                      color: Colors.white54, size: 20),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                song.channelName as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle_outline, color: kAccent, size: 16),
      ],
    );
  }
}

// ─── Transport controls (center 1/3) ─────────────────────────────────────────

class _TransportControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool shuffle;
  final LoopMode loopMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const _TransportControls({
    required this.isPlaying,
    required this.isLoading,
    required this.shuffle,
    required this.loopMode,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final repeatIcon = loopMode == LoopMode.one
        ? Icons.repeat_one
        : Icons.repeat;
    final repeatColor = loopMode != LoopMode.off ? kAccent : kTextSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          onPressed: onShuffle,
          icon: Icon(
            Icons.shuffle,
            color: shuffle ? kAccent : kTextSecondary,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),

        // Previous
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.skip_previous, color: kTextPrimary, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),

        const SizedBox(width: 4),

        // Play / Pause
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: kAccent,
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 28,
                  ),
          ),
        ),

        const SizedBox(width: 4),

        // Next
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.skip_next, color: kTextPrimary, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),

        // Repeat
        IconButton(
          onPressed: onRepeat,
          icon: Icon(repeatIcon, color: repeatColor, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

// ─── Volume controls (right 1/3) ─────────────────────────────────────────────

class _VolumeControls extends StatelessWidget {
  final double volume;
  final void Function(double) onVolumeChanged;

  const _VolumeControls({
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _grayIcon(Icons.mic_none_outlined),
        _grayIcon(Icons.queue_music_outlined),
        _grayIcon(volume < 0.01 ? Icons.volume_off : Icons.volume_up_outlined),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kAccent,
              inactiveTrackColor: const Color(0xFF3A3A3A),
              thumbColor: Colors.white,
              overlayColor: kAccent.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: onVolumeChanged,
            ),
          ),
        ),
        _grayIcon(Icons.fullscreen_outlined),
      ],
    );
  }

  Widget _grayIcon(IconData icon) {
    return IconButton(
      icon: Icon(icon, color: kTextSecondary, size: 20),
      onPressed: () {},
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

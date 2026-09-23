// ============================================================
// desktop/player/desktop_player_bar.dart
// Bottom 80px player bar with progress, controls, and volume.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/song.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_context_menu.dart';
import '../../widgets/device_picker.dart';
import '../theme/desktop_theme.dart';
import '../../widgets/listen_party_controls.dart';

class DesktopPlayerBar extends ConsumerStatefulWidget {
  const DesktopPlayerBar({super.key});

  @override
  ConsumerState<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends ConsumerState<DesktopPlayerBar> {
  double _volume = 0.8;
  double _volumeBeforeMute = 0.8;
  bool _muted = false;
  bool _draggingProgress = false;
  double _dragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(audioHandlerProvider).service;
      setState(() => _volume = service.volume);
      _applyVolume(_volume);
    });
  }

  void _applyVolume(double v) {
    try {
      ref.read(audioHandlerProvider).service.setVolume(v);
    } catch (_) {}
  }

  void _toggleMute() {
    setState(() {
      if (_muted) {
        _muted = false;
        _volume = _volumeBeforeMute;
        _applyVolume(_volume);
      } else {
        _volumeBeforeMute = _volume;
        _muted = true;
        _applyVolume(0.0);
      }
    });
  }

  void _togglePanel(PanelMode mode) {
    final current = ref.read(panelModeProvider);
    final next = current == mode ? PanelMode.none : mode;
    ref.read(panelModeProvider.notifier).state = next;

    // Pre-fetch lyrics when panel is opened
    if (next == PanelMode.lyrics) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        ref.read(lyricsProvider.notifier).fetchFor(song.id, song: song);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final panelMode = ref.watch(panelModeProvider);
    final song = ps.currentSong;

    final position = ps.position;
    final duration = ps.duration;
    final progressFraction = (duration.inMilliseconds > 0 && !_draggingProgress)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : (_draggingProgress ? _dragProgress : 0.0);

    return Container(
      color: context.appTheme.player,
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
                  milliseconds: (fraction * duration.inMilliseconds).toInt());
              ref.read(playerProvider.notifier).seek(target);
            },
            onDragStart: (f) => setState(() {
              _draggingProgress = true;
              _dragProgress = f;
            }),
            onDragUpdate: (f) => setState(() => _dragProgress = f),
            onDragEnd: (f) {
              setState(() => _draggingProgress = false);
              final target =
                  Duration(milliseconds: (f * duration.inMilliseconds).toInt());
              ref.read(playerProvider.notifier).seek(target);
            },
          ),

          // ── Controls row ──────────────────────────────────────────────
          SizedBox(
            height: 76,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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

                  // Right: volume + panel controls
                  Expanded(
                    child: _VolumeControls(
                      volume: _muted ? 0.0 : _volume,
                      muted: _muted,
                      panelMode: panelMode,
                      onVolumeChanged: (v) {
                        setState(() {
                          _volume = v;
                          _muted = v < 0.01;
                          if (!_muted) _volumeBeforeMute = v;
                        });
                        _applyVolume(v);
                      },
                      onMuteToggle: _toggleMute,
                      onLyricsToggle: () => _togglePanel(PanelMode.lyrics),
                      onQueueToggle: () => _togglePanel(PanelMode.queue),
                    ),
                  ),
                  const ListenPartyControls(),
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
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _fmt(position),
            style: TextStyle(color: context.appTheme.subtext, fontSize: 11),
          ),
          SizedBox(width: 8),
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
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.appTheme.shadow,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: context.appTheme.button,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (fraction * constraints.maxWidth - 5)
                                .clamp(0.0, constraints.maxWidth - 10),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: context.appTheme.text,
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
          SizedBox(width: 8),
          Text(
            _fmt(duration),
            style: TextStyle(color: context.appTheme.subtext, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Song info (left 1/3) ─────────────────────────────────────────────────────

class _SongInfo extends ConsumerWidget {
  final Song? song;
  const _SongInfo({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (song == null) return SizedBox.shrink();

    final s = song!;
    final ps = ref.watch(playerProvider);
    final queue = ps.queue;
    final idx = ps.currentIndex;
    final next =
        (queue.length > 1 && idx >= 0) ? queue[(idx + 1) % queue.length] : null;

    return SongContextMenu(
      song: s,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: s.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: s.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 48, height: 48, color: context.appTheme.card),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: context.appTheme.card,
                      child: Icon(Icons.music_note,
                          color:
                              context.appTheme.subtext.withValues(alpha: 0.54),
                          size: 20),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: context.appTheme.card,
                    child: Icon(Icons.music_note,
                        color: context.appTheme.subtext.withValues(alpha: 0.54),
                        size: 20),
                  ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  s.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: context.appTheme.subtext, fontSize: 11),
                ),
              ],
            ),
          ),
          SongMenuButton(song: s, size: 16),
          if (next != null) ...[
            SizedBox(width: 8),
            Container(width: 1, height: 36, color: context.appTheme.shadow),
            SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: next.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: next.thumbnailUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          width: 30, height: 30, color: context.appTheme.card),
                      errorWidget: (_, __, ___) => Container(
                        width: 30,
                        height: 30,
                        color: context.appTheme.card,
                        child: Icon(Icons.music_note,
                            color: context.appTheme.subtext
                                .withValues(alpha: 0.54),
                            size: 12),
                      ),
                    )
                  : Container(
                      width: 30,
                      height: 30,
                      color: context.appTheme.card,
                      child: Icon(Icons.music_note,
                          color:
                              context.appTheme.subtext.withValues(alpha: 0.54),
                          size: 12),
                    ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: context.appTheme.button,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    next.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTheme.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    next.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.appTheme.subtext, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
    final repeatIcon =
        loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat;
    final repeatColor = loopMode != LoopMode.off
        ? context.appTheme.button
        : context.appTheme.subtext;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onShuffle,
          icon: Icon(Icons.shuffle,
              color:
                  shuffle ? context.appTheme.button : context.appTheme.subtext,
              size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          onPressed: onPrev,
          icon:
              Icon(Icons.skip_previous, color: context.appTheme.text, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        SizedBox(width: 4),
        Material(
          color: context.appTheme.button,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPlayPause,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: isLoading
                    ? Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            color: context.appTheme.text, strokeWidth: 2.5),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: context.appTheme.text,
                        size: 28,
                      ),
              ),
            ),
          ),
        ),
        SizedBox(width: 4),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.skip_next, color: context.appTheme.text, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
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
  final bool muted;
  final PanelMode panelMode;
  final void Function(double) onVolumeChanged;
  final VoidCallback onMuteToggle;
  final VoidCallback onLyricsToggle;
  final VoidCallback onQueueToggle;

  const _VolumeControls({
    required this.volume,
    required this.muted,
    required this.panelMode,
    required this.onVolumeChanged,
    required this.onMuteToggle,
    required this.onLyricsToggle,
    required this.onQueueToggle,
  });

  @override
  Widget build(BuildContext context) {
    final IconData volIcon = muted || volume < 0.01
        ? Icons.volume_off
        : volume < 0.5
            ? Icons.volume_down_outlined
            : Icons.volume_up_outlined;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const DevicePickerButton(size: 20),

        // Lyrics button — opens fullscreen lyrics overlay
        Tooltip(
          message: panelMode == PanelMode.lyrics
              ? 'Close Fullscreen Lyrics'
              : 'Fullscreen Lyrics',
          child: IconButton(
            icon: Icon(
              panelMode == PanelMode.lyrics
                  ? Icons.lyrics // filled when active
                  : Icons.lyrics_outlined,
              color: panelMode == PanelMode.lyrics
                  ? context.appTheme.button
                  : context.appTheme.subtext,
              size: 20,
            ),
            onPressed: onLyricsToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),

        // Queue button
        Tooltip(
          message: panelMode == PanelMode.queue ? 'Close Queue' : 'Queue',
          child: IconButton(
            icon: Icon(
              Icons.queue_music_outlined,
              color: panelMode == PanelMode.queue
                  ? context.appTheme.button
                  : context.appTheme.subtext,
              size: 20,
            ),
            onPressed: onQueueToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),

        // Mute button
        Tooltip(
          message: muted ? 'Unmute' : 'Mute',
          child: IconButton(
            icon: Icon(volIcon, color: context.appTheme.subtext, size: 20),
            onPressed: onMuteToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ),

        // Volume slider
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.appTheme.button,
              inactiveTrackColor: context.appTheme.shadow,
              thumbColor: context.appTheme.text,
              overlayColor: context.appTheme.button.withValues(alpha: 0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: onVolumeChanged,
            ),
          ),
        ),

        // Fullscreen placeholder
        IconButton(
          icon: Icon(Icons.fullscreen_outlined,
              color: context.appTheme.subtext, size: 20),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ============================================================
// desktop/now_playing/desktop_now_playing_panel.dart
//
// Right panel — fixed layout:
//   1. Video card  (fixed height, never scrolls)
//   2. Lyrics card (takes ALL remaining height, scrolls internally)
//
// Lyrics card features:
//   • Rounded card (12 px), background #2a2a2a on #121212 panel
//   • Small green bold "Lyrics" label top-left
//   • 22 px bold white lyrics lines, generous spacing
//   • Only the lyrics card scrolls
//   • Thin subtle custom scrollbar
//   • Active line = full white; others = 60 % opacity
//   • Auto-scroll keeps active line visible; manual scroll
//     pauses auto-scroll for 3 s then resumes
//   • Noto Sans font covers Korean + English (and most scripts)
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_service.dart';
import '../../widgets/video_preview_widget.dart';
import '../theme/desktop_theme.dart';

// ─── Height constants ─────────────────────────────────────────────────────────

/// Height reserved for the video card (16:9 ratio of panel width + info bar).
const double _kVideoCardHeight = 230.0;

/// Gap between video card and lyrics card.
const double _kGap = 10.0;

/// How long (ms) after a manual scroll before auto-scroll resumes.
const int _kAutoScrollPauseMs = 3000;

// ─── Panel ───────────────────────────────────────────────────────────────────

class DesktopNowPlayingPanel extends ConsumerStatefulWidget {
  const DesktopNowPlayingPanel({super.key});

  @override
  ConsumerState<DesktopNowPlayingPanel> createState() =>
      _DesktopNowPlayingPanelState();
}

class _DesktopNowPlayingPanelState
    extends ConsumerState<DesktopNowPlayingPanel> {
  // Lyrics scroll controller (internal to the lyrics card only)
  final ScrollController _lyricsScroll = ScrollController();

  // Active line tracking
  String? _lastVideoId;
  int _activeIndex = -1;
  final List<GlobalKey> _lineKeys = [];

  // Manual-scroll pause
  bool _autoScrollPaused = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _lyricsScroll.addListener(_onManualScroll);
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _lyricsScroll.removeListener(_onManualScroll);
    _lyricsScroll.dispose();
    super.dispose();
  }

  // ── Manual scroll detection ──────────────────────────────────────────────
  void _onManualScroll() {
    // Only treat as manual if auto-scroll didn't trigger it
    if (_isAutoScrolling) return;
    _autoScrollPaused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(
      const Duration(milliseconds: _kAutoScrollPauseMs),
      () => _autoScrollPaused = false,
    );
  }

  bool _isAutoScrolling = false;

  // ── Active line sync ─────────────────────────────────────────────────────
  void _syncActive(List<LyricLine> lines, Duration pos) {
    // Rebuild key list if line count changed
    if (_lineKeys.length != lines.length) {
      _lineKeys.clear();
      for (int i = 0; i < lines.length; i++) {
        _lineKeys.add(GlobalKey());
      }
    }

    int active = -1;
    for (int i = 0; i < lines.length; i++) {
      if (pos >= lines[i].start) active = i;
    }

    if (active != _activeIndex) {
      _activeIndex = active;
      _autoScrollToLine(active);
    }
  }

  void _autoScrollToLine(int index) {
    if (_autoScrollPaused) return;
    if (index < 0 || index >= _lineKeys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[index].currentContext;
      if (ctx == null || !_lyricsScroll.hasClients) return;

      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        alignment: 0.35, // keep line ~35 % from top of visible area
      ).then((_) => _isAutoScrolling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final panelMode = ref.watch(panelModeProvider);
    final ps        = ref.watch(playerProvider);
    final lyrics    = ref.watch(lyricsProvider);
    final song      = ps.currentSong;

    // When lyrics button pressed → fetch for current song
    if (panelMode == PanelMode.lyrics && song != null) {
      if (song.id != _lastVideoId ||
          (song.id == _lastVideoId && lyrics.videoId != song.id)) {
        _lastVideoId = song.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(lyricsProvider.notifier).fetchFor(song.id);
        });
      }
    }

    // Continuously sync active line
    if (lyrics.hasLyrics) {
      _syncActive(lyrics.lines, ps.position);
    }

    return Container(
      width: kNowPlayingWidth,
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: song == null || song.isLocal
          ? const _Placeholder()
          : _buildLayout(song, lyrics, ps.position),
    );
  }

  Widget _buildLayout(dynamic song, LyricsState lyrics, Duration pos) {
    return Column(
      children: [
        // ── 1. Video card (fixed) ───────────────────────────────────
        _VideoCard(song: song, height: _kVideoCardHeight),

        const SizedBox(height: _kGap),

        // ── 2. Lyrics card (fills remaining height) ─────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _LyricsCard(
              lyrics: lyrics,
              activeIndex: _activeIndex,
              lineKeys: _lineKeys,
              scrollController: _lyricsScroll,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Video card ───────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final dynamic song;
  final double height;

  const _VideoCard({required this.song, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player (muted)
          ColoredBox(
            color: Colors.black,
            child: VideoPreviewWidget(videoId: song.id, fit: BoxFit.cover),
          ),

          // Bottom gradient
          const Positioned(
            left: 0, right: 0, bottom: 0, height: 110,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF2000000)],
                ),
              ),
            ),
          ),

          // Song info overlay
          Positioned(
            left: 16, right: 16, bottom: 16,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.check_circle, color: kAccent, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lyrics card ─────────────────────────────────────────────────────────────

class _LyricsCard extends StatelessWidget {
  final LyricsState lyrics;
  final int activeIndex;
  final List<GlobalKey> lineKeys;
  final ScrollController scrollController;

  const _LyricsCard({
    required this.lyrics,
    required this.activeIndex,
    required this.lineKeys,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Slightly lighter than the #121212 panel background
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "Lyrics" label ──────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined, color: kAccent, size: 13),
                SizedBox(width: 5),
                Text(
                  'Lyrics',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(color: Color(0xFF3d3d3d), height: 1, thickness: 1),
          ),

          const SizedBox(height: 4),

          // ── Scrollable lyrics body ──────────────────────────────
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (lyrics.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kAccent, strokeWidth: 2),
            SizedBox(height: 10),
            Text(
              'Loading lyrics…',
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // No lyrics / error state
    if (!lyrics.hasLyrics) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off, color: kTextSecondary, size: 36),
              const SizedBox(height: 10),
              Text(
                lyrics.error ?? 'No lyrics available for this song.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Lyrics list with thin custom scrollbar
    return Scrollbar(
      controller: scrollController,
      thickness: 3,
      radius: const Radius.circular(2),
      thumbVisibility: true,
      child: ListView.builder(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 20, 24),
        itemCount: lyrics.lines.length + 1, // +1 for footer
        itemBuilder: (context, i) {
          // Footer
          if (i == lyrics.lines.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Lyrics provided by YouTube',
                style: TextStyle(color: Color(0xFF666666), fontSize: 11),
              ),
            );
          }

          final isActive = i == activeIndex;
          final key = i < lineKeys.length ? lineKeys[i] : GlobalKey();

          return _LyricLine(
            key: key,
            text: lyrics.lines[i].text,
            isActive: isActive,
          );
        },
      ),
    );
  }
}

// ─── Single lyric line ────────────────────────────────────────────────────────

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isActive;

  const _LyricLine({
    super.key,
    required this.text,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    // fontFamilyFallback provides broad multi-script support:
    //   • Android ships Noto Sans CJK / Noto Sans KR (covers Korean, JP, CN)
    //   • Windows ships Malgun Gothic (Korean) and Microsoft YaHei (Chinese)
    //   • No font assets need to be bundled in pubspec.yaml
    const fallbackFonts = [
      'Malgun Gothic',   // Windows Korean
      'Noto Sans KR',    // Android Korean
      'Noto Sans CJK',   // Android CJK fallback
      'Microsoft YaHei', // Windows Chinese
      'Segoe UI',        // Windows Latin
    ];

    return Padding(
      // Generous vertical spacing between lines
      padding: const EdgeInsets.only(bottom: 18),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        style: TextStyle(
          fontFamilyFallback: fallbackFonts,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: isActive
              ? Colors.white                        // active: full white
              : Colors.white.withValues(alpha: 0.38), // dimmed: ~38 % opacity
        ),
        child: Text(
          text,
          softWrap: true, // wrap long lines gracefully
        ),
      ),
    );
  }
}

// ─── Placeholder (no song playing) ────────────────────────────────────────────

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

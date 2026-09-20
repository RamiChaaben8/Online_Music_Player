// ============================================================
// desktop/player/lyrics_panel.dart
//
// Full-screen lyrics view (opens when lyrics button is pressed).
//
// • CustomScrollView with a SliverAppBar:
//   - Video/thumbnail fills the top at expandedHeight
//   - StretchMode.zoomBackground → video STRETCHES when you
//     pull/scroll up (parallax zoom effect)
//   - Collapses away as you scroll down into the lyrics
// • Lyrics below: active line white+bold, past dimmed, upcoming muted
// • Auto-scrolls to keep active line in view
// • Player bar stays visible at bottom (audio never stops)
// • × close button pinned top-right at all times
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_service.dart';
import '../../widgets/video_preview_widget.dart';
import '../theme/desktop_theme.dart';

class LyricsPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const LyricsPanel({super.key, required this.onClose});

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  final ScrollController _scroll = ScrollController();
  String? _lastVideoId;
  int _activeIndex = -1;
  final List<GlobalKey> _lineKeys = [];

  static const double _expandedHeight = 340.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncActive(List<LyricLine> lines, Duration pos) {
    if (_lineKeys.length != lines.length) {
      _lineKeys.clear();
      for (int i = 0; i < lines.length; i++) _lineKeys.add(GlobalKey());
    }
    int active = -1;
    for (int i = 0; i < lines.length; i++) {
      if (pos >= lines[i].start) active = i;
    }
    if (active != _activeIndex) {
      _activeIndex = active;
      _scrollToActive(active);
    }
  }

  void _scrollToActive(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[index].currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        alignment: 0.38,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ps       = ref.watch(playerProvider);
    final lyrics   = ref.watch(lyricsProvider);
    final song     = ps.currentSong;

    // Trigger fetch on song change
    if (song != null && song.id != _lastVideoId) {
      _lastVideoId = song.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        ref.read(lyricsProvider.notifier).fetchFor(song.id);
      });
    }

    // Sync active lyric line
    if (lyrics.hasLyrics) _syncActive(lyrics.lines, ps.position);

    return Material(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          // ── Main scrollable content ───────────────────────────────
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Stretchy video header ──────────────────────────────
              SliverAppBar(
                expandedHeight: _expandedHeight,
                collapsedHeight: 0,
                toolbarHeight: 0,
                pinned: false,
                stretch: true,           // enables stretch-on-overscroll
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground, // video zooms on pull-down
                    StretchMode.fadeTitle,
                  ],
                  background: _VideoHeader(song: song),
                ),
              ),

              // ── Song info ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (song != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF9A9A9A),
                                      fontSize: 14,
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
                        const SizedBox(height: 20),
                      ],

                      // "Lyrics" chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF2E2E50), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lyrics_outlined,
                                color: kAccent, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Lyrics',
                              style: TextStyle(
                                color: kAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // ── Lyric lines ────────────────────────────────────────
              _buildLyricsSliver(lyrics),

              // ── Footer padding ─────────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),

          // ── Close button (always on top) ──────────────────────────
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsSliver(LyricsState lyrics) {
    if (lyrics.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: kAccent, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading lyrics…',
                  style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (!lyrics.hasLyrics) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lyrics_outlined,
                    color: Color(0xFF444466), size: 48),
                const SizedBox(height: 14),
                Text(
                  lyrics.error ?? 'No lyrics available for this song.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF9A9A9A), fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            // Footer item
            if (i == lyrics.lines.length) {
              return const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Text(
                  'Lyrics provided by YouTube',
                  style: TextStyle(color: Color(0xFF555577), fontSize: 12),
                ),
              );
            }

            final isActive = i == _activeIndex;
            final isPast   = i < _activeIndex;
            final key      = i < _lineKeys.length
                ? _lineKeys[i]
                : GlobalKey();

            return _LyricLine(
              key: key,
              text: lyrics.lines[i].text,
              isActive: isActive,
              isPast: isPast,
            );
          },
          childCount: lyrics.lines.length + 1,
        ),
      ),
    );
  }
}

// ─── Video / thumbnail header ─────────────────────────────────────────────────

class _VideoHeader extends StatelessWidget {
  final dynamic song; // Song?
  const _VideoHeader({required this.song});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video (muted — just_audio owns the audio)
        if (song != null && !song.isLocal)
          ColoredBox(
            color: Colors.black,
            child: VideoPreviewWidget(videoId: song.id, fit: BoxFit.cover),
          )
        else if (song != null && song.thumbnailUrl.isNotEmpty)
          Image.network(song.thumbnailUrl, fit: BoxFit.cover)
        else
          const ColoredBox(
            color: Color(0xFF1A1A2A),
            child: Center(
              child: Icon(Icons.music_note, color: Colors.white12, size: 72),
            ),
          ),

        // Bottom gradient so the song info below blends in
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
                colors: [Colors.transparent, Color(0xFF0A0A0A)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Single lyric line ────────────────────────────────────────────────────────

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isActive;
  final bool isPast;

  const _LyricLine({
    super.key,
    required this.text,
    required this.isActive,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        style: TextStyle(
          color: isActive
              ? Colors.white
              : isPast
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFF888888),
          fontSize: isActive ? 22 : 18,
          fontWeight:
              isActive ? FontWeight.w800 : FontWeight.w500,
          height: 1.3,
        ),
        child: Text(text),
      ),
    );
  }
}

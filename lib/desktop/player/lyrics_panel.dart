// ============================================================
// desktop/player/lyrics_panel.dart
//
// Full-screen lyrics overlay — side-by-side layout:
//
//   ┌─────────────────────┬─────────────────────────────────┐
//   │                     │  Song title                     │
//   │   Thumbnail /       │  Artist                         │
//   │   album art         ├─────────────────────────────────┤
//   │   (fills left       │  Lyrics  ▲                      │
//   │    column,          │  …       │  scrollable           │
//   │    always           │  …       ▼                      │
//   │    visible)         │                                 │
//   └─────────────────────┴─────────────────────────────────┘
//
// • Left column width is resizable by dragging the divider.
// • Lyrics scroll independently — image never moves.
// • × close button pinned top-right.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_service.dart';
import '../theme/desktop_theme.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const double _kLeftMin = 220.0;
const double _kLeftMax = 600.0;
const double _kLeftDefault = 340.0;
const double _kDividerW = 8.0;

// ─────────────────────────────────────────────────────────────────────────────

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

  double _leftWidth = _kLeftDefault;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Lyric sync ────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final lyrics = ref.watch(lyricsProvider);
    final song = ps.currentSong;

    // Trigger fetch on song change
    if (song != null && song.id != _lastVideoId) {
      _lastVideoId = song.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        ref.read(lyricsProvider.notifier).fetchFor(song.id);
      });
    }

    if (lyrics.hasLyrics) _syncActive(lyrics.lines, ps.position);

    return Material(
      color: context.appTheme.main,
      child: Stack(
        children: [
          // ── Side-by-side layout ───────────────────────────────────
          Row(
            children: [
              // ── LEFT: thumbnail (always fully visible) ───────────
              SizedBox(
                width: _leftWidth,
                child: _VideoHeader(song: song),
              ),

              // ── Draggable divider ─────────────────────────────────
              _Divider(
                onDelta: (dx) => setState(() {
                  _leftWidth = (_leftWidth + dx).clamp(_kLeftMin, _kLeftMax);
                }),
              ),

              // ── RIGHT: song info + scrollable lyrics ─────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Song info header
                    if (song != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 56, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTheme.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              song.channelName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTheme.subtext,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 14),
                            // "Lyrics" chip
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.appTheme.card,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: context.appTheme.shadow, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lyrics_outlined,
                                      color: context.appTheme.button, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Lyrics',
                                    style: TextStyle(
                                      color: context.appTheme.button,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),

                    // Thin separator
                    Divider(
                        height: 1, thickness: 1, color: context.appTheme.main),

                    // Scrollable lyrics box
                    Expanded(
                      child: Directionality(
                        textDirection: lyrics.isArabic
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: CustomScrollView(
                          controller: _scroll,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            _buildLyricsSliver(lyrics, ps.position),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 60)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Close button (always on top-right) ────────────────────
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.appTheme.shadow.withValues(alpha: 0.54),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.close, color: context.appTheme.text, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lyrics sliver ─────────────────────────────────────────────────────────

  Widget _buildLyricsSliver(LyricsState lyrics, Duration position) {
    if (lyrics.isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: context.appTheme.button, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading lyrics…',
                  style:
                      TextStyle(color: context.appTheme.subtext, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (!lyrics.hasLyrics) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lyrics_outlined,
                    color: context.appTheme.misc, size: 48),
                SizedBox(height: 14),
                Text(
                  lyrics.error ?? 'No lyrics available for this song.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: context.appTheme.subtext, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == lyrics.lines.length) {
              return Padding(
                padding: EdgeInsets.only(top: 28),
                child: Text(
                  'Lyrics provided by YouTube',
                  style:
                      TextStyle(color: context.appTheme.shadow, fontSize: 12),
                ),
              );
            }

            final isActive = i == _activeIndex;
            final isPast = i < _activeIndex;
            final key = i < _lineKeys.length ? _lineKeys[i] : GlobalKey();

            return _LyricLine(
              key: key,
              line: lyrics.lines[i],
              isActive: isActive,
              isPast: isPast,
              position: position,
            );
          },
          childCount: lyrics.lines.length + 1,
        ),
      ),
    );
  }
}

// ─── Draggable vertical divider ───────────────────────────────────────────────

class _Divider extends StatefulWidget {
  final void Function(double dx) onDelta;
  const _Divider({required this.onDelta});

  @override
  State<_Divider> createState() => _DividerState();
}

class _DividerState extends State<_Divider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        child: SizedBox(
          width: _kDividerW,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 2,
              height: double.infinity,
              color: _hovered
                  ? context.appTheme.button.withValues(alpha: 0.6)
                  : context.appTheme.text.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thumbnail / album art left panel ────────────────────────────────────────

class _VideoHeader extends StatelessWidget {
  final dynamic song;
  const _VideoHeader({required this.song});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (song != null && song.thumbnailUrl.isNotEmpty)
          Image.network(
            song.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _Placeholder(),
          )
        else
          const _Placeholder(),

        // Right-edge fade to blend into the divider/dark bg
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.75, 1.0],
                colors: [
                  context.appTheme.main.withValues(alpha: 0),
                  context.appTheme.shadow.withValues(alpha: 0.8)
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appTheme.card,
      child: Center(
        child: Icon(Icons.music_note,
            color: context.appTheme.subtext.withValues(alpha: 0.12), size: 80),
      ),
    );
  }
}

// ─── Single lyric line ────────────────────────────────────────────────────────

class _LyricLine extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final Duration position;

  const _LyricLine({
    super.key,
    required this.line,
    required this.isActive,
    required this.isPast,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // ── Karaoke word-by-word when active and timing available ───────
    if (isActive && line.hasWordTiming) {
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: Wrap(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            spacing: 0,
            runSpacing: 2,
            children: line.words.map((word) {
              final lit = position >= word.start;
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: lit
                      ? context.appTheme.button
                      : context.appTheme.text.withValues(alpha: 0.45),
                ),
                child: Text('${word.text} '),
              );
            }).toList(),
          ),
        ),
      );
    }

    // ── Plain line ──────────────────────────────────────────────────
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        style: TextStyle(
          color: isActive
              ? context.appTheme.text
              : isPast
                  ? context.appTheme.shadow
                  : context.appTheme.subtext,
          fontSize: isActive ? 22 : 18,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          height: 1.3,
        ),
        child: Align(
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            line.text,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
        ),
      ),
    );
  }
}

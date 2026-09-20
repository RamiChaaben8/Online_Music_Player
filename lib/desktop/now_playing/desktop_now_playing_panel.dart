// ============================================================
// desktop/now_playing/desktop_now_playing_panel.dart
//
// Right panel — ONE scrollable column for everything:
//   • Video card at top (fixed height, cover-cropped, resizable)
//   • Lyrics card below (same scroll — no nested scroller)
//   • Single thin green-thumb scrollbar on the right edge
//   • Resize bar on the far-right edge (video height only)
// ============================================================

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_service.dart';
import '../../widgets/video_preview_widget.dart';
import '../theme/desktop_theme.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const double _kVideoMin  = 230.0;
const double _kBarWidth  =   7.0;
const double _kSnapFrac  =   0.10;
const int    _kAnimMs    =  150;
const int    _kPauseMs   = 3000;
const String _kPrefKey   = 'now_playing_video_height';

// ─── Panel ───────────────────────────────────────────────────────────────────

class DesktopNowPlayingPanel extends ConsumerStatefulWidget {
  const DesktopNowPlayingPanel({super.key});

  @override
  ConsumerState<DesktopNowPlayingPanel> createState() =>
      _DesktopNowPlayingPanelState();
}

class _DesktopNowPlayingPanelState
    extends ConsumerState<DesktopNowPlayingPanel> {

  // One scroll controller for the whole panel
  final ScrollController _scroll = ScrollController();

  // Video resize
  double _videoHeight          = _kVideoMin;
  double _videoMax             = _kVideoMin;
  bool   _isDragging           = false;
  double _dragStartThumbOffset = 0;

  // Lyrics
  String? _lastVideoId;
  int     _activeIndex     = -1;
  final List<GlobalKey> _lineKeys = [];
  bool    _autoScrollPaused = false;
  Timer?  _resumeTimer;
  bool    _isAutoScrolling  = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadHeight();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _loadHeight() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getDouble(_kPrefKey);
    if (saved != null && saved >= _kVideoMin) {
      setState(() => _videoHeight = saved);
    }
  }

  Future<void> _saveHeight(double h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefKey, h);
  }

  // ── Height helpers ────────────────────────────────────────────────────────

  double _clamp(double h) => h.clamp(_kVideoMin, _videoMax);

  double _snapIfClose(double h) {
    final range = _videoMax - _kVideoMin;
    if (range <= 0) return h;
    if ((h - _kVideoMin) / range < _kSnapFrac) return _kVideoMin;
    if ((_videoMax - h)  / range < _kSnapFrac) return _videoMax;
    return h;
  }

  void _setHeight(double h, {bool snap = false}) {
    double next = _clamp(h);
    if (snap) next = _snapIfClose(next);
    if (next == _videoHeight) return;
    setState(() => _videoHeight = next);
    _saveHeight(next);
  }

  double _thumbOffsetToHeight(double offset, double trackH) {
    if (trackH <= 0) return _kVideoMin;
    return _kVideoMin +
        (offset / trackH).clamp(0.0, 1.0) * (_videoMax - _kVideoMin);
  }

  // ── Scroll / lyrics auto-scroll ───────────────────────────────────────────

  void _onScroll() {
    if (_isAutoScrolling) return;
    _autoScrollPaused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(
      const Duration(milliseconds: _kPauseMs),
      () => _autoScrollPaused = false,
    );
  }

  void _syncActive(List<LyricLine> lines, Duration pos) {
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
      if (ctx == null || !_scroll.hasClients) return;
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        alignment: 0.35,
      ).then((_) => _isAutoScrolling = false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final panelMode = ref.watch(panelModeProvider);
    final ps        = ref.watch(playerProvider);
    final lyrics    = ref.watch(lyricsProvider);
    final song      = ps.currentSong;

    if (panelMode == PanelMode.lyrics && song != null) {
      if (song.id != _lastVideoId ||
          (song.id == _lastVideoId && lyrics.videoId != song.id)) {
        _lastVideoId = song.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(lyricsProvider.notifier).fetchFor(song.id);
        });
      }
    }

    if (lyrics.hasLyrics) _syncActive(lyrics.lines, ps.position);

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
          : _buildPanel(song, lyrics),
    );
  }

  Widget _buildPanel(dynamic song, LyricsState lyrics) {
    return LayoutBuilder(builder: (context, constraints) {
      final panelH = constraints.maxHeight;
      _videoMax = (panelH - 16).clamp(_kVideoMin, double.infinity);
      if (_videoHeight > _videoMax) _videoHeight = _videoMax;

      final dur = _isDragging
          ? Duration.zero
          : const Duration(milliseconds: _kAnimMs);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Scrollable area (no scrollbar) ───────────────────────
          Expanded(
            child: Listener(
                // Intercept wheel events so we can resize the video
                // before (or instead of) scrolling the list.
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  final dy = event.scrollDelta.dy;

                  if (dy < 0) {
                    // ── Scroll UP ──────────────────────────────────
                    // If video is below MAX, grow it and consume the
                    // event (don't scroll the list).
                    if (_videoHeight < _videoMax) {
                      _setHeight(_videoHeight - dy); // dy<0 → adds
                      return; // consumed — list does not scroll
                    }
                    // Already at MAX → fall through to normal list scroll
                  } else if (dy > 0) {
                    // ── Scroll DOWN ────────────────────────────────
                    // If list is at the very top AND video is above MIN,
                    // shrink video first.
                    final atTop = !_scroll.hasClients ||
                        _scroll.offset <= 0;
                    if (atTop && _videoHeight > _kVideoMin) {
                      _setHeight(_videoHeight - dy); // dy>0 → subtracts
                      return; // consumed — list does not scroll yet
                    }
                    // List already scrolled or video at MIN → normal scroll
                  }

                  // Let the ListView handle the event normally
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(
                      (_scroll.offset + dy)
                          .clamp(0.0, _scroll.position.maxScrollExtent),
                    );
                  }
                },
                child: ListView(
                  controller: _scroll,
                  // NeverScrollableScrollPhysics because we drive the
                  // scroll manually from the Listener above, which gives
                  // us the control needed for the video-resize intercept.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // 1. Video card (animated height)
                    AnimatedContainer(
                      duration: dur,
                      curve: Curves.easeOut,
                      height: _videoHeight,
                      child: _VideoCard(song: song),
                    ),

                    const SizedBox(height: 10),

                    // 2. Lyrics section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildLyricsContent(lyrics),
                      ),
                    ),
                ],
              ),     // ListView
            ),       // Listener
          ),         // Expanded

          // ── Resize bar ────────────────────────────────────────────
          _DragBar(
            panelHeight: panelH,
            videoHeight: _videoHeight,
            videoMin: _kVideoMin,
            videoMax: _videoMax,
            isDragging: _isDragging,
            onDragStart: (_, thumbOffset) => setState(() {
              _isDragging           = true;
              _dragStartThumbOffset = thumbOffset;
            }),
            onDragUpdate: (dy, trackH) {
              final newOffset =
                  (_dragStartThumbOffset + dy).clamp(0.0, trackH);
              _setHeight(_thumbOffsetToHeight(newOffset, trackH));
            },
            onDragEnd: () {
              setState(() => _isDragging = false);
              _setHeight(_videoHeight, snap: true);
            },
            onTrackTap: (frac) => _setHeight(
              _kVideoMin + frac * (_videoMax - _kVideoMin),
              snap: true,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildLyricsContent(LyricsState lyrics) {
    if (lyrics.isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LyricsHeader(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
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
            ),
          ),
        ],
      );
    }

    if (!lyrics.hasLyrics) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LyricsHeader(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_off, color: kTextSecondary, size: 36),
                const SizedBox(height: 10),
                Text(
                  lyrics.error ?? 'No lyrics available for this song.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // All lyric lines rendered in a plain Column — no nested scroll,
    // the outer ListView handles all scrolling.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LyricsHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < lyrics.lines.length; i++)
                _LyricLine(
                  key: i < _lineKeys.length ? _lineKeys[i] : GlobalKey(),
                  text: lyrics.lines[i].text,
                  isActive: i == _activeIndex,
                ),
              const SizedBox(height: 8),
              const Text(
                'Lyrics provided by YouTube',
                style: TextStyle(color: Color(0xFF666666), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Lyrics header (const widget so it can live in const trees) ──────────────

class _LyricsHeader extends StatelessWidget {
  const _LyricsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child:
              Divider(color: Color(0xFF3d3d3d), height: 1, thickness: 1),
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

// ─── Thin custom scrollbar ────────────────────────────────────────────────────

class _ThinScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController controller;

  const _ThinScrollbar({required this.child, required this.controller});

  @override
  State<_ThinScrollbar> createState() => _ThinScrollbarState();
}

class _ThinScrollbarState extends State<_ThinScrollbar> {
  static const double _kBarW      =  6.0;
  static const double _kThumbW    =  4.0;
  static const double _kThumbMinH = 32.0;
  static const double _kPadV      =  8.0;

  bool   _hovering        = false;
  bool   _dragging        = false;
  double _dragStartLocalY = 0;
  double _dragStartScroll = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => setState(() {});

  double _thumbH(double trackH) {
    final sc = widget.controller;
    if (!sc.hasClients || sc.position.maxScrollExtent <= 0) return trackH;
    final visible = sc.position.viewportDimension;
    final total   = visible + sc.position.maxScrollExtent;
    return (trackH * visible / total).clamp(_kThumbMinH, trackH);
  }

  double _thumbTop(double trackH) {
    final sc = widget.controller;
    if (!sc.hasClients || sc.position.maxScrollExtent <= 0) return 0;
    return (sc.offset / sc.position.maxScrollExtent) *
        (trackH - _thumbH(trackH));
  }

  void _dragStart(double localY) {
    setState(() {
      _dragging        = true;
      _dragStartLocalY = localY;
      _dragStartScroll = widget.controller.hasClients
          ? widget.controller.offset
          : 0;
    });
  }

  void _dragUpdate(double localY, double trackH) {
    if (!_dragging || !widget.controller.hasClients) return;
    final dy          = localY - _dragStartLocalY;
    final tH          = _thumbH(trackH);
    final scrollRange = widget.controller.position.maxScrollExtent;
    final scrollable  = trackH - tH;
    if (scrollable <= 0) return;
    widget.controller.jumpTo(
      (_dragStartScroll + dy / scrollable * scrollRange)
          .clamp(0.0, scrollRange),
    );
  }

  void _dragEnd() => setState(() => _dragging = false);

  void _trackTap(double localY, double trackH) {
    if (!widget.controller.hasClients) return;
    final tH   = _thumbH(trackH);
    final frac = ((localY - tH / 2) / (trackH - tH)).clamp(0.0, 1.0);
    widget.controller.animateTo(
      frac * widget.controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: widget.child),
        MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          onEnter: (_) => setState(() => _hovering = true),
          onExit:  (_) => setState(() => _hovering = false),
          child: LayoutBuilder(builder: (context, constraints) {
            final totalH = constraints.maxHeight;
            final trackH = totalH - 2 * _kPadV;
            return GestureDetector(
              onTapDown: (d) =>
                  _trackTap(d.localPosition.dy - _kPadV, trackH),
              onVerticalDragStart:  (d) =>
                  _dragStart(d.localPosition.dy - _kPadV),
              onVerticalDragUpdate: (d) =>
                  _dragUpdate(d.localPosition.dy - _kPadV, trackH),
              onVerticalDragEnd:    (_) => _dragEnd(),
              onVerticalDragCancel: ()  => _dragEnd(),
              child: SizedBox(
                width: _kBarW,
                height: totalH,
                child: CustomPaint(
                  painter: _BarPainter(
                    trackH:     trackH,
                    padV:       _kPadV,
                    thumbTop:   _thumbTop(trackH),
                    thumbH:     _thumbH(trackH),
                    thumbW:     _kThumbW,
                    barW:       _kBarW,
                    thumbColor: (_hovering || _dragging)
                        ? const Color(0xFF82b832)
                        : const Color(0xFF5f7a2f),
                    trackColor: const Color(0xFF1e1e1e),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  final double trackH, padV, thumbTop, thumbH, thumbW, barW;
  final Color  thumbColor, trackColor;

  const _BarPainter({
    required this.trackH,
    required this.padV,
    required this.thumbTop,
    required this.thumbH,
    required this.thumbW,
    required this.barW,
    required this.thumbColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = barW / 2;
    canvas.drawLine(
      Offset(cx, padV),
      Offset(cx, padV + trackH),
      Paint()
        ..color = trackColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        cx - thumbW / 2, padV + thumbTop,
        cx + thumbW / 2, padV + thumbTop + thumbH,
        Radius.circular(thumbW / 2),
      ),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.thumbTop   != thumbTop   ||
      old.thumbH     != thumbH     ||
      old.thumbColor != thumbColor;
}

// ─── Resize drag bar (video height only) ─────────────────────────────────────

class _DragBar extends StatefulWidget {
  final double panelHeight, videoHeight, videoMin, videoMax;
  final bool   isDragging;
  final void Function(double pointerY, double thumbOffset) onDragStart;
  final void Function(double dy, double trackH) onDragUpdate;
  final void Function() onDragEnd;
  final void Function(double frac) onTrackTap;

  const _DragBar({
    required this.panelHeight,
    required this.videoHeight,
    required this.videoMin,
    required this.videoMax,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTrackTap,
  });

  @override
  State<_DragBar> createState() => _DragBarState();
}

class _DragBarState extends State<_DragBar> {
  bool _hovering = false;

  static const double _kThumbH    = 40.0;
  static const double _kThumbW    =  4.0;
  static const double _kTrackPadV = 12.0;

  double get _trackH =>
      widget.panelHeight - 2 * _kTrackPadV - _kThumbH;

  double get _thumbOffset {
    final range = widget.videoMax - widget.videoMin;
    if (range <= 0) return 0;
    return ((widget.videoHeight - widget.videoMin) / range)
            .clamp(0.0, 1.0) *
        _trackH;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (d) {
          final localY = d.localPosition.dy - _kTrackPadV;
          widget.onTrackTap(
              (localY / (_trackH + _kThumbH)).clamp(0.0, 1.0));
        },
        onVerticalDragStart:  (d) =>
            widget.onDragStart(d.globalPosition.dy, _thumbOffset),
        onVerticalDragUpdate: (d) =>
            widget.onDragUpdate(d.delta.dy, _trackH),
        onVerticalDragEnd:    (_) => widget.onDragEnd(),
        onVerticalDragCancel: ()  => widget.onDragEnd(),
        child: SizedBox(
          width: _kBarWidth,
          height: widget.panelHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 2,
                margin: const EdgeInsets.symmetric(
                  vertical: _kTrackPadV,
                  horizontal: (_kBarWidth - 2) / 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              AnimatedPositioned(
                duration: widget.isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: _kAnimMs),
                curve: Curves.easeOut,
                top: _kTrackPadV + _thumbOffset,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _kThumbW,
                  height: _kThumbH,
                  decoration: BoxDecoration(
                    color: _hovering || widget.isDragging
                        ? const Color(0xFF82b832)
                        : const Color(0xFF5f7a2f),
                    borderRadius: BorderRadius.circular(_kThumbW / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Video card ───────────────────────────────────────────────────────────────

class _VideoCard extends StatelessWidget {
  final dynamic song;
  const _VideoCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: VideoPreviewWidget(videoId: song.id, fit: BoxFit.cover),
        ),
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
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black)
                        ],
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
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black)
                        ],
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
    );
  }
}

// ─── Single lyric line ────────────────────────────────────────────────────────

class _LyricLine extends StatelessWidget {
  final String text;
  final bool   isActive;

  const _LyricLine({
    super.key,
    required this.text,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    const fallbackFonts = [
      'Malgun Gothic',
      'Noto Sans KR',
      'Noto Sans CJK',
      'Microsoft YaHei',
      'Segoe UI',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 220),
        style: TextStyle(
          fontFamilyFallback: fallbackFonts,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: isActive
              ? Colors.white
              : Colors.white.withValues(alpha: 0.38),
        ),
        child: Text(text, softWrap: true),
      ),
    );
  }
}

// ─── Placeholder ──────────────────────────────────────────────────────────────

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

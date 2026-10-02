// ============================================================
// desktop/shell/panel_widths.dart
//
// Spotify-style draggable widths for the two side panels:
//   • the library sidebar (playlists, folders, liked songs)
//   • the now-playing / queue panel (video card + lyrics card)
//
// A divider sits in the gap next to each panel; drag it to resize and
// double-click it to snap back to the theme's default width. Widths are
// remembered per theme, matching how the video card height is stored.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/desktop_theme.dart';

// ─── Drag range ────────────────────────────────────────────────────────────────
// The range is a UX constant rather than a theme token: resizing should feel
// identical in every theme, so only the starting width comes from the theme.

const double kSidebarResizeMin = 200;
const double kSidebarResizeMax = 460;
const double kNowPlayingResizeMin = 300;
const double kNowPlayingResizeMax = 520;

/// Width of the library sidebar's collapsed icon rail. This is the state the
/// sidebar snaps to when the divider is dragged below [kSidebarResizeMin].
const double kSidebarCollapsedWidth = 64;

/// Stored width that means "collapsed". Kept as a distinct sentinel rather than
/// a real pixel value so the rail can never be mistaken for a sized panel.
const double kSidebarCollapsed = 0;

/// The centre view (home / search / playlist / friends) must stay usable, so
/// neither panel is allowed to squeeze it out of existence.
const double kCenterMinWidth = 320;

double clampSidebarWidth(double w) => w.clamp(kSidebarResizeMin, kSidebarResizeMax);

double clampNowPlayingWidth(double w) =>
    w.clamp(kNowPlayingResizeMin, kNowPlayingResizeMax);

// ─── Store ─────────────────────────────────────────────────────────────────────

/// Holds the user's panel width overrides. A null override means "use the
/// theme's default width for the current window size".
class PanelWidthStore extends ChangeNotifier {
  static const String _prefKey = 'desktop_panel_width';

  String? _themeName;
  double? _sidebar;
  double? _nowPlaying;
  bool _ready = false;

  double? get sidebar => _ready ? _sidebar : null;
  double? get nowPlaying => _ready ? _nowPlaying : null;

  /// Drops the current overrides and loads the newly active theme's widths.
  void bindTheme(String themeName) {
    if (_themeName == themeName) return;
    _themeName = themeName;
    _sidebar = null;
    _nowPlaying = null;
    _ready = false;
    unawaited(_load(themeName));
  }

  Future<void> _load(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    final sidebar = prefs.getDouble(_key(themeName, 'sidebar'));
    final nowPlaying = prefs.getDouble(_key(themeName, 'now_playing'));
    if (_themeName != themeName) return;
    _sidebar = sidebar;
    _nowPlaying = nowPlaying;
    _ready = true;
    notifyListeners();
  }

  Future<void> setSidebar(double? width) async {
    _sidebar = width;
    notifyListeners();
    await _write('sidebar', width);
  }

  Future<void> setNowPlaying(double? width) async {
    _nowPlaying = width;
    notifyListeners();
    await _write('now_playing', width);
  }

  Future<void> _write(String slot, double? width) async {
    final themeName = _themeName;
    if (themeName == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _key(themeName, slot);
    // A null width means "follow the theme default", so clear the override
    // instead of writing a stale pixel value.
    if (width == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, width);
    }
  }

  static String _key(String themeName, String slot) {
    final slug = themeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${_prefKey}_${slug}_$slot';
  }
}

/// Resolves the width a panel should actually render at, preferring the user's
/// stored override and falling back to the theme default for this window.
///
/// An override of [kSidebarCollapsed] (or anything at or below it) renders the
/// library sidebar as its collapsed icon rail instead of a sized panel.
double resolvePanelWidth({
  required AppLayoutTokens layout,
  required double screenWidth,
  required double? override,
  required bool isNowPlaying,
}) {
  if (!isNowPlaying && override != null && override <= kSidebarCollapsed) {
    return kSidebarCollapsedWidth;
  }
  final themeDefault = isNowPlaying
      ? layout.nowPlayingWidthFor(screenWidth)
      : layout.sidebarWidthFor(screenWidth);
  final clampedDefault = isNowPlaying
      ? clampNowPlayingWidth(themeDefault)
      : clampSidebarWidth(themeDefault);
  if (override == null) return clampedDefault;
  return isNowPlaying ? clampNowPlayingWidth(override) : clampSidebarWidth(override);
}

/// Maps a raw drag result to a stored width, collapsing the library sidebar
/// when it is dragged narrower than the minimum expanded width.
///
/// The same rule works in both directions: dragging the rail's divider right
/// produces a width of at least [kSidebarCollapsedWidth], so it only expands
/// once the pointer travels far enough to clear [kSidebarResizeMin].
double storedSidebarWidth(double raw) =>
    raw < kSidebarResizeMin ? kSidebarCollapsed : raw;

// ─── Divider ───────────────────────────────────────────────────────────────────

/// Thin draggable divider that occupies the gap between two panels.
/// Drag to resize, double-click to reset to the theme default.
class PanelResizeHandle extends StatefulWidget {
  /// True when the handle sits on the *left* edge of its panel (now playing),
  /// so dragging right makes the panel narrower.
  final bool onLeftEdge;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  const PanelResizeHandle({
    super.key,
    required this.onLeftEdge,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;
  double _dragStartWidth = 0;

  /// Total horizontal travel since the drag began.
  ///
  /// Drag updates arrive as a stream of small per-event deltas, so they have to
  /// be accumulated. Using a single event's delta against the start width would
  /// make the panel jump by only a few pixels no matter how far the pointer
  /// travels.
  double _dragTravel = 0;

  static const double _barW = 3;
  static const double _barH = 44;

  void _onPanStart() {
    setState(() {
      _dragging = true;
      _dragStartWidth = widget.value;
      _dragTravel = 0;
    });
  }

  void _onPanEnd() {
    if (_dragging) setState(() => _dragging = false);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Dragging the left-edge handle rightwards shrinks the panel on its right.
    _dragTravel += widget.onLeftEdge ? -details.delta.dx : details.delta.dx;
    widget.onChanged((_dragStartWidth + _dragTravel).clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final active = _hovered || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _dragging = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onPanStart: (_) => _onPanStart(),
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _barW,
            height: _barH,
            decoration: BoxDecoration(
              color: active ? theme.nowPlayingAccent : theme.dividerColor,
              borderRadius: BorderRadius.circular(_barW / 2),
            ),
          ),
        ),
      ),
    );
  }
}

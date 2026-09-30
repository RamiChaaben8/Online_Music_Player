// ============================================================
// desktop/theme/ui_sizes.dart
//
// Tunable type and metric sizes for widgets that don't map cleanly onto the
// per-theme layout tokens.
//
// Everything here is a plain constant or a value derived from a single scale
// knob, so the whole group can be nudged from one place.
// ============================================================

/// Sizes for playlist titles.
///
/// The library rows and the opened-playlist header used to be hard-coded at
/// different sizes in two different files; both read from here now.
class PlaylistSizes {
  const PlaylistSizes._();

  /// Playlist name in the "Your Library" sidebar list ("c418", "Jap", ...).
  ///
  /// Was 14.
  static const double libraryTitle = 16;

  /// "Playlist • 73 songs" under the library row name. Was 12.
  static const double librarySubtitle = 13;

  /// Playlist name in the opened-playview header. Was 56.
  ///
  /// This one scales with the viewport, so it gets a small relative bump
  /// rather than a flat +2 that would be invisible at this size.
  static const double headerTitle = 62;

  /// Creator / "• 73 songs • 41 min" meta row under the header title. Was 13.
  static const double headerSubtitle = 14;
}

/// Sizes for the queue side panel.
///
/// [QueueSizes.of] is the instance widgets should read. Call
/// `QueueSizes(1.1)` to grow the entire panel by 10% without touching widget
/// code — the sliders below are all derived from [base].
class QueueSizes {
  const QueueSizes([this.base = 1.0]);

  /// Single knob for the whole panel. 1.0 is the current tuning.
  final double base;

  /// Shared instance used by the widgets.
  static const QueueSizes of = QueueSizes();

  double _s(double v) => v * base;

  // ── Type ──────────────────────────────────────────────────────────────────

  /// Song title in the Now Playing and Next Up rows. Was 12.
  double get songTitle => _s(14);

  /// Artist / channel line under the song title. Was 10.
  double get songSubtitle => _s(11.5);

  /// "NOW PLAYING" / "NEXT UP • n songs" section labels. Was 10.
  double get sectionLabel => _s(11.5);

  // ── Metrics ───────────────────────────────────────────────────────────────

  /// Album art edge length. Was 40 (now playing) / 38 (next up).
  double get thumb => _s(52);

  /// Fixed height of a pinned section header. Was 34.
  double get sectionHeight => _s(40);

  /// Horizontal ListTile inset. Was 10.
  double get rowPadH => _s(12);

  /// Vertical ListTile inset. dense: true already contributes 4px per side, so
  /// this stays small to avoid inflating row height.
  double get rowPadV => _s(4);

  /// Row action buttons (remove / more) icon size. Was 15.
  double get rowActionIcon => _s(18);

  /// Row action buttons tap target. Was 24.
  double get rowActionTap => _s(28);

  /// Reorder drag handle. Was 16.
  double get dragHandle => _s(20);

  /// Animated equalizer glyph (both the trailing one and the one overlaid on
  /// the now-playing thumbnail). Was 18.
  double get equalizer => _s(22);

  /// Header vertical inset. Was 10.
  double get headerPadV => _s(12);
}

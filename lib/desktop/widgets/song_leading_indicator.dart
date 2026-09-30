// ============================================================
// desktop/widgets/song_leading_indicator.dart
//
// Shared "what is playing" indicator for song rows.
//
//   idle, not current   -> track number
//   hovered, not current-> play triangle
//   hovered, current    -> pause bars
//   current             -> animated equalizer (freezes when playback pauses)
//
// Every colour is pulled from the active theme so it follows accent changes.
// ============================================================

import 'package:flutter/material.dart';

/// Animated equalizer bars for the row that is currently playing.
///
/// Four bars ride the same 0..1 cycle but each starts at a different offset, so
/// they never move in sync. When [animating] is false the controller stops and
/// the bars rest low and static.
class EqualizerBars extends StatefulWidget {
  final Color color;

  /// Edge length of the (square) drawing box.
  final double size;

  /// False freezes the bars instead of stopping mid-bounce.
  final bool animating;

  const EqualizerBars({
    super.key,
    required this.color,
    this.size = 16,
    this.animating = true,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.animating == old.animating) return;
    if (widget.animating) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _EqualizerPainter(color: widget.color, t: _controller.value),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  const _EqualizerPainter({required this.color, required this.t});

  final Color color;
  final double t;

  /// Per-bar offsets into the cycle. Unequal values are what keeps the bars out
  /// of phase with each other.
  static const List<double> _phases = [0.0, 0.37, 0.68, 1.06];

  static const double _barWidth = 2.4;
  static const double _barGap = 1.6;
  static const double _minHeightFraction = 0.26;

  @override
  void paint(Canvas canvas, Size size) {
    final count = _phases.length;
    final totalWidth = count * _barWidth + (count - 1) * _barGap;
    var x = (size.width - totalWidth) / 2;
    final paint = Paint()..color = color;
    final maxHeight = size.height;
    final minHeight = maxHeight * _minHeightFraction;
    final radius = const Radius.circular(_barWidth / 2);

    for (final phase in _phases) {
      final local = (t + phase) % 1.0;
      // Triangle wave: rises over the first half of the cycle, falls over the
      // second, so the motion reads as a bounce rather than a saw-tooth jump.
      final wave = local < 0.5 ? local * 2 : (1 - local) * 2;
      final height = minHeight + (maxHeight - minHeight) * wave;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - height) / 2, _barWidth, height),
          radius,
        ),
        paint,
      );
      x += _barWidth + _barGap;
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => old.t != t || old.color != color;
}

/// Fixed-size leading slot for a song row.
///
/// The box is a constant [size] × [size] regardless of which of the four states
/// is showing, so swapping the number for an icon never nudges the row layout.
class SongLeadingIndicator extends StatelessWidget {
  /// 1-based track number. Null renders an empty slot.
  final int? number;

  /// This row is the one loaded in the player.
  final bool isCurrent;

  /// The player is actually running (as opposed to paused).
  final bool isPlaying;

  /// The pointer is over this row.
  final bool hovered;

  /// Theme accent, used for the play icon, pause icon and equalizer bars.
  final Color accent;

  final double size;
  final double iconSize;
  final double fontSize;

  /// Theme colour for the track number.
  final Color numberColor;

  /// Tapping the indicator. Typically play/pause for this row.
  final VoidCallback? onTap;

  const SongLeadingIndicator({
    super.key,
    this.number,
    required this.isCurrent,
    required this.isPlaying,
    required this.hovered,
    required this.accent,
    required this.numberColor,
    this.size = 24,
    this.iconSize = 18,
    this.fontSize = 13,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (hovered) {
      // Hover wins over the equalizer so you can always reach pause directly.
      content = Icon(
        isCurrent && isPlaying ? Icons.pause : Icons.play_arrow,
        color: accent,
        size: iconSize,
      );
    } else if (isCurrent) {
      content = EqualizerBars(
        color: accent,
        size: iconSize,
        animating: isPlaying,
      );
    } else if (number != null) {
      content = Text(
        '$number',
        style: TextStyle(color: numberColor, fontSize: fontSize),
        textAlign: TextAlign.right,
      );
    } else {
      content = const SizedBox.shrink();
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: onTap == null
            ? content
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }
}

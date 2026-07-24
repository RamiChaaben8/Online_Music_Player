// ============================================================
// widgets/seek_bar.dart
//
// Seek bar widget with current/total time labels.
// Allows dragging to seek.
// ============================================================

import 'package:flutter/material.dart';

class SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  // While dragging, show the dragged value instead of the stream position.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final current = _dragValue ?? widget.position.inMilliseconds.toDouble();
    final clampedCurrent = current.clamp(0, total > 0 ? total : 1).toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: const RoundedRectSliderTrackShape(),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: clampedCurrent,
            min: 0,
            max: total > 0 ? total : 1,
            onChanged: total > 0
                ? (val) => setState(() => _dragValue = val)
                : null,
            onChangeEnd: total > 0
                ? (val) {
                    setState(() => _dragValue = null);
                    widget.onSeek(Duration(milliseconds: val.round()));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: clampedCurrent.round())),
                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
              ),
              Text(
                _formatDuration(widget.duration),
                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

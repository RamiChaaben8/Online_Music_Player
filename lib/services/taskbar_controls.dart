// ============================================================
// services/taskbar_controls.dart
//
// Windows taskbar thumbnail toolbar — Prev / Play-Pause / Next.
//
// Usage:
//   // After the first frame (window must exist):
//   TaskbarControls.instance.init(
//     onPrev:      () => ref.read(playerProvider.notifier).skipToPrevious(),
//     onPlayPause: () => ref.read(playerProvider.notifier).togglePlayPause(),
//     onNext:      () => ref.read(playerProvider.notifier).skipToNext(),
//   );
//
//   // Whenever play-state changes:
//   TaskbarControls.instance.updatePlayState(isPlaying);
//
// The class is fully no-op on non-Windows platforms — every method
// is guarded with Platform.isWindows so you can call them freely from
// shared code.
// ============================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class TaskbarControls {
  TaskbarControls._();
  static final TaskbarControls instance = TaskbarControls._();

  VoidCallback? _onPrev;
  VoidCallback? _onPlayPause;
  VoidCallback? _onNext;

  bool _initialised = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once after the first frame so the native window handle exists.
  void init({
    required VoidCallback onPrev,
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
  }) {
    if (!Platform.isWindows) return;

    _onPrev = onPrev;
    _onPlayPause = onPlayPause;
    _onNext = onNext;
    _initialised = true;

    // Start paused state (app hasn't played anything yet).
    _setButtons(isPlaying: false);
  }

  /// Swap the Play / Pause icon and update the tooltip.
  /// Safe to call before [init] — it becomes a no-op.
  void updatePlayState(bool isPlaying) {
    if (!Platform.isWindows || !_initialised) return;
    _setButtons(isPlaying: isPlaying);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setButtons({required bool isPlaying}) {
    WindowsTaskbar.setThumbnailToolbar([
      ThumbnailToolbarButton(
        ThumbnailToolbarAssetIcon('assets/icons/prev.ico'),
        'Previous',
        () => _onPrev?.call(),
      ),
      ThumbnailToolbarButton(
        ThumbnailToolbarAssetIcon(
          isPlaying ? 'assets/icons/pause.ico' : 'assets/icons/play.ico',
        ),
        isPlaying ? 'Pause' : 'Play',
        () => _onPlayPause?.call(),
      ),
      ThumbnailToolbarButton(
        ThumbnailToolbarAssetIcon('assets/icons/next.ico'),
        'Next',
        () => _onNext?.call(),
      ),
    ]);
  }
}

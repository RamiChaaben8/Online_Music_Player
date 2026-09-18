// ============================================================
// providers/download_provider.dart
//
// Tracks:
//   • Which songs are in-progress (downloading set)
//   • Per-song download progress  (progress map, 0.0 – 1.0)
//   • Which songs are fully done  (downloaded set, persisted in Hive)
//   • Last error string
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../services/download_service.dart';
import 'youtube_provider.dart';
import 'local_music_provider.dart';
import '../models/song.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(youtubeServiceProvider));
});

// ── State ──────────────────────────────────────────────────────────────────

class DownloadState {
  /// IDs of songs currently downloading.
  final Set<String> downloading;

  /// Per-song download progress (0.0 = just started, 1.0 = complete).
  /// Only present while the download is in progress.
  final Map<String, double> progress;

  /// IDs of songs that have been fully downloaded (persisted to Hive).
  final Set<String> downloaded;

  final String? error;

  const DownloadState({
    this.downloading = const {},
    this.progress = const {},
    this.downloaded = const {},
    this.error,
  });

  DownloadState copyWith({
    Set<String>? downloading,
    Map<String, double>? progress,
    Set<String>? downloaded,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      downloading: downloading ?? this.downloading,
      progress: progress ?? this.progress,
      downloaded: downloaded ?? this.downloaded,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool isDownloading(String id) => downloading.contains(id);
  bool isDownloaded(String id) => downloaded.contains(id);

  /// Returns 0.0 if not started yet, 1.0 if finished.
  double progressFor(String id) => progress[id] ?? 0.0;
}

// ── Notifier ───────────────────────────────────────────────────────────────

const _kDownloadedBox = 'downloaded_songs';

class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadService _service;
  final Ref _ref;

  DownloadNotifier(this._service, this._ref) : super(const DownloadState()) {
    _loadDownloaded();
  }

  Future<void> _loadDownloaded() async {
    try {
      final box = await Hive.openBox(_kDownloadedBox);
      final ids = Set<String>.from(box.keys.cast<String>());
      state = state.copyWith(downloaded: ids);
    } catch (_) {}
  }

  Future<void> _persistDownloaded(String id) async {
    try {
      final box = await Hive.openBox(_kDownloadedBox);
      await box.put(id, true);
    } catch (_) {}
  }

  // ── Public API ───────────────────────────────────────────────────────

  Future<void> downloadSong(Song song) async {
    if (state.isDownloaded(song.id) || state.isDownloading(song.id)) return;

    // Mark as in-progress at 0 %
    state = state.copyWith(
      downloading: {...state.downloading, song.id},
      progress: {...state.progress, song.id: 0.0},
      clearError: true,
    );

    try {
      await _service.downloadSong(
        song,
        onProgress: (p) {
          // Guard: notifier may have been disposed if the app restarted
          if (!mounted) return;
          state = state.copyWith(
            progress: {...state.progress, song.id: p},
          );
        },
      );

      // Success — mark downloaded, remove from progress map
      final newDownloaded = {...state.downloaded, song.id};
      final newProgress = Map<String, double>.from(state.progress)
        ..remove(song.id);
      state = state.copyWith(
        downloaded: newDownloaded,
        progress: newProgress,
      );
      await _persistDownloaded(song.id);

      _ref.read(localMusicProvider.notifier).scan();
    } catch (e) {
      final newProgress = Map<String, double>.from(state.progress)
        ..remove(song.id);
      state = state.copyWith(
        progress: newProgress,
        error: 'Download failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        state = state.copyWith(
          downloading: state.downloading.difference({song.id}),
        );
      }
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ───────────────────────────────────────────────────────────────

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref.watch(downloadServiceProvider), ref);
});

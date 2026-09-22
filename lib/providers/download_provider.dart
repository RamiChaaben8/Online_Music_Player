// ============================================================
// providers/download_provider.dart
//
// Tracks download state locally on this device only (no cloud sync).
//
// Hive box 'downloaded_songs' stores:
//   key   = song ID (String)
//   value = absolute file path (String)
//
// On startup every persisted entry is verified against the filesystem.
// Entries whose file no longer exists are purged automatically — so
// deleting the file from the file manager clears the downloaded badge.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../services/download_service.dart';
import 'youtube_provider.dart';
import 'local_music_provider.dart';
import '../models/song.dart';

import 'dart:io';

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

  /// song ID → absolute local file path, for songs confirmed on disk.
  final Map<String, String> downloadedPaths;

  final String? error;

  const DownloadState({
    this.downloading = const {},
    this.progress = const {},
    this.downloadedPaths = const {},
    this.error,
  });

  DownloadState copyWith({
    Set<String>? downloading,
    Map<String, double>? progress,
    Map<String, String>? downloadedPaths,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      downloading: downloading ?? this.downloading,
      progress: progress ?? this.progress,
      downloadedPaths: downloadedPaths ?? this.downloadedPaths,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool isDownloading(String id) => downloading.contains(id);

  /// True only when the file is confirmed to exist on disk.
  bool isDownloaded(String id) => downloadedPaths.containsKey(id);

  /// Returns 0.0 if not started yet, 1.0 if finished.
  double progressFor(String id) => progress[id] ?? 0.0;

  /// Local file path for a downloaded song, or null.
  String? localPath(String id) => downloadedPaths[id];
}

// ── Notifier ───────────────────────────────────────────────────────────────

const _kDownloadedBox = 'downloaded_songs';

class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadService _service;
  final Ref _ref;

  DownloadNotifier(this._service, this._ref) : super(const DownloadState()) {
    _loadAndVerify();
  }

  // ── Startup: load Hive then verify every file exists on disk ──────────

  Future<void> _loadAndVerify() async {
    try {
      final box = await Hive.openBox<String>(_kDownloadedBox);
      final verified = <String, String>{};
      final toDelete = <String>[];

      for (final key in box.keys.cast<String>()) {
        final path = box.get(key);
        if (path == null) {
          toDelete.add(key);
          continue;
        }
        if (await File(path).exists()) {
          verified[key] = path;
        } else {
          // File was deleted externally — purge from Hive.
          toDelete.add(key);
        }
      }

      if (toDelete.isNotEmpty) {
        await box.deleteAll(toDelete);
      }

      if (mounted) {
        state = state.copyWith(downloadedPaths: verified);
      }
    } catch (_) {}
  }

  // ── Persist a confirmed download ──────────────────────────────────────

  Future<void> _persist(String id, String path) async {
    try {
      final box = await Hive.openBox<String>(_kDownloadedBox);
      await box.put(id, path);
    } catch (_) {}
  }

  // ── Remove a single entry from Hive (file deleted externally) ─────────

  Future<void> _purge(String id) async {
    try {
      final box = await Hive.openBox<String>(_kDownloadedBox);
      await box.delete(id);
    } catch (_) {}
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Re-scan Hive against disk. Call this after the user might have
  /// deleted files externally (e.g. from the file manager).
  Future<void> refresh() => _loadAndVerify();

  final Set<String> _cancelled = {};

  Future<void> cancelDownload(String id) async {
    _cancelled.add(id);
    if (mounted) {
      final newProgress = Map<String, double>.from(state.progress)..remove(id);
      state = state.copyWith(
        downloading: state.downloading.difference({id}),
        progress: newProgress,
      );
    }
  }

  Future<void> downloadSong(Song song) async {
    if (state.isDownloading(song.id)) return;
    _cancelled.remove(song.id);

    // If marked as downloaded, verify the file actually still exists on disk.
    // It might have been deleted externally without the app being notified.
    if (state.isDownloaded(song.id)) {
      final existingPath = state.downloadedPaths[song.id];
      final fileExists =
          existingPath != null && await File(existingPath).exists();
      if (fileExists) return; // File is confirmed on disk — nothing to do.
      // File is missing — purge stale Hive entry and continue to re-download.
      final cleanedPaths = Map<String, String>.from(state.downloadedPaths)
        ..remove(song.id);
      if (mounted) state = state.copyWith(downloadedPaths: cleanedPaths);
      await _purge(song.id);
    }

    // Mark as in-progress at 0 %
    state = state.copyWith(
      downloading: {...state.downloading, song.id},
      progress: {...state.progress, song.id: 0.0},
      clearError: true,
    );

    try {
      final filePath = await _service.downloadSong(
        song,
        onProgress: (p) {
          if (!mounted || _cancelled.contains(song.id)) return;
          // Progress callbacks can arrive out of order when the underlying
          // HTTP stream is cancelled at the end of a range.
          final previous = state.progress[song.id] ?? 0.0;
          final next = p < previous ? previous : p;
          state = state.copyWith(
            progress: {...state.progress, song.id: next},
          );
        },
        isCancelled: () => _cancelled.contains(song.id),
      );

      if (_cancelled.contains(song.id)) {
        // Just in case it sneaked through
        throw Exception('Cancelled');
      }

      // Verify the file actually landed on disk before marking done.
      final exists = await File(filePath).exists();
      if (!exists) throw Exception('File not found after download: $filePath');

      final newPaths = Map<String, String>.from(state.downloadedPaths)
        ..[song.id] = filePath;
      final newProgress = Map<String, double>.from(state.progress)
        ..remove(song.id);

      if (mounted) {
        state = state.copyWith(
          downloadedPaths: newPaths,
          progress: newProgress,
        );
      }
      await _persist(song.id, filePath);
      _ref.read(localMusicProvider.notifier).scan();
    } catch (e) {
      if (_cancelled.contains(song.id)) {
        // It was cancelled, don't show an error.
        _cancelled.remove(song.id);
        return; // Early return, state already cleaned in cancelDownload
      }
      final newProgress = Map<String, double>.from(state.progress)
        ..remove(song.id);
      // If partial file exists for this song, purge the Hive entry too.
      final paths = Map<String, String>.from(state.downloadedPaths)
        ..remove(song.id);
      if (mounted) {
        state = state.copyWith(
          downloadedPaths: paths,
          progress: newProgress,
          error:
              'Download failed: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
      await _purge(song.id);
    } finally {
      _cancelled.remove(song.id);
      if (mounted) {
        state = state.copyWith(
          downloading: state.downloading.difference({song.id}),
        );
      }
    }
  }

  Future<void> deleteSong(Song song) async {
    final path = state.downloadedPaths[song.id];
    if (path == null) {
      await _purge(song.id);
      // Still remove from in-memory state in case of stale entry.
      if (mounted) {
        final paths = Map<String, String>.from(state.downloadedPaths)
          ..remove(song.id);
        state = state.copyWith(downloadedPaths: paths, clearError: true);
      }
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      final paths = Map<String, String>.from(state.downloadedPaths)
        ..remove(song.id);
      if (mounted) {
        state = state.copyWith(downloadedPaths: paths, clearError: true);
      }
      await _purge(song.id);
      // Full re-scan to keep in-memory state consistent with disk.
      await _loadAndVerify();
      _ref.read(localMusicProvider.notifier).scan();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          error: 'Delete failed: ${e.toString().replaceAll('Exception: ', '')}',
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

// ============================================================
// providers/download_provider.dart
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/download_service.dart';
import 'youtube_provider.dart';
import 'local_music_provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(youtubeServiceProvider));
});

class DownloadState {
  final Set<String> downloading;
  final String? error;

  const DownloadState({this.downloading = const {}, this.error});

  DownloadState copyWith({
    Set<String>? downloading,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      downloading: downloading ?? this.downloading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool isDownloading(String songId) => downloading.contains(songId);
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadService _service;
  final Ref _ref;

  DownloadNotifier(this._service, this._ref) : super(const DownloadState());

  Future<void> downloadSong(Song song) async {
    state = state.copyWith(
      downloading: {...state.downloading, song.id},
      clearError: true,
    );

    try {
      await _service.downloadSong(song);
      // Re-scan local music so the new file appears immediately
      _ref.read(localMusicProvider.notifier).scan();
    } catch (e) {
      state = state.copyWith(
        error: 'Download failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      state = state.copyWith(
        downloading: state.downloading.difference({song.id}),
      );
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      await downloadSong(song);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref.watch(downloadServiceProvider), ref);
});

// ============================================================
// providers/download_provider.dart
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/download_service.dart';
import 'youtube_provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final ytService = ref.watch(youtubeServiceProvider);
  return DownloadService(ytService);
});

class DownloadNotifier extends StateNotifier<Set<String>> {
  final DownloadService _service;
  
  DownloadNotifier(this._service) : super({});

  Future<void> downloadSong(Song song) async {
    state = {...state, song.id};
    try {
      await _service.downloadSong(song);
    } finally {
      state = state.difference({song.id});
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      await downloadSong(song);
    }
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, Set<String>>((ref) {
  return DownloadNotifier(ref.watch(downloadServiceProvider));
});

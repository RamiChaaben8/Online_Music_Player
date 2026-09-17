// ============================================================
// providers/local_music_provider.dart
//
// Exposes the list of locally downloaded songs.
// Call scan() after a download completes or on app resume.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/local_music_service.dart';

class LocalMusicState {
  final List<Song> songs;
  final bool isScanning;

  const LocalMusicState({this.songs = const [], this.isScanning = false});

  LocalMusicState copyWith({List<Song>? songs, bool? isScanning}) {
    return LocalMusicState(
      songs: songs ?? this.songs,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class LocalMusicNotifier extends StateNotifier<LocalMusicState> {
  final LocalMusicService _service;

  LocalMusicNotifier(this._service) : super(const LocalMusicState()) {
    scan(); // auto-scan on init
  }

  Future<void> scan() async {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true);
    final songs = await _service.scanLocalSongs();
    state = state.copyWith(songs: songs, isScanning: false);
  }
}

final localMusicServiceProvider = Provider<LocalMusicService>((_) => LocalMusicService());

final localMusicProvider =
    StateNotifierProvider<LocalMusicNotifier, LocalMusicState>((ref) {
  return LocalMusicNotifier(ref.watch(localMusicServiceProvider));
});

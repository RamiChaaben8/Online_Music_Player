// ============================================================
// providers/library_provider.dart
//
// Riverpod state for liked songs, recently played, and playlists.
// Backed by LibraryService (Hive).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../services/library_service.dart';

// ─── Library state ────────────────────────────────────────────────────────────

class LibraryState {
  final List<Song> likedSongs;
  final List<Song> recentlyPlayed;
  final List<Playlist> playlists;

  const LibraryState({
    this.likedSongs = const [],
    this.recentlyPlayed = const [],
    this.playlists = const [],
  });

  LibraryState copyWith({
    List<Song>? likedSongs,
    List<Song>? recentlyPlayed,
    List<Playlist>? playlists,
  }) {
    return LibraryState(
      likedSongs: likedSongs ?? this.likedSongs,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      playlists: playlists ?? this.playlists,
    );
  }

  bool isLiked(String songId) => likedSongs.any((s) => s.id == songId);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryService _service;

  LibraryNotifier(this._service) : super(const LibraryState()) {
    _load();
  }

  void _load() {
    state = LibraryState(
      likedSongs: _service.getLikedSongs(),
      recentlyPlayed: _service.getRecentlyPlayed(),
      playlists: _service.getPlaylists(),
    );
  }

  Future<void> toggleLike(Song song) async {
    await _service.toggleLike(song);
    state = state.copyWith(likedSongs: _service.getLikedSongs());
  }

  Future<void> addToRecentlyPlayed(Song song) async {
    await _service.addToRecentlyPlayed(song);
    state = state.copyWith(recentlyPlayed: _service.getRecentlyPlayed());
  }

  Future<void> createPlaylist(String name, {String? description}) async {
    await _service.createPlaylist(name, description: description);
    state = state.copyWith(playlists: _service.getPlaylists());
  }

  Future<void> renamePlaylist(int key, String name) async {
    await _service.renamePlaylist(key, name);
    state = state.copyWith(playlists: _service.getPlaylists());
  }

  Future<void> deletePlaylist(int key) async {
    await _service.deletePlaylist(key);
    state = state.copyWith(playlists: _service.getPlaylists());
  }

  Future<void> addSongToPlaylist(int playlistKey, Song song) async {
    await _service.addSongToPlaylist(playlistKey, song);
    state = state.copyWith(playlists: _service.getPlaylists());
  }

  Future<void> removeSongFromPlaylist(int playlistKey, String songId) async {
    await _service.removeSongFromPlaylist(playlistKey, songId);
    state = state.copyWith(playlists: _service.getPlaylists());
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final libraryServiceProvider = Provider<LibraryService>((ref) => LibraryService());

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref.watch(libraryServiceProvider));
});

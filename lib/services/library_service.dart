// ============================================================
// services/library_service.dart
//
// Manages local persistence with Hive:
//  - Liked songs
//  - Recently played history (capped at 50)
//  - Custom playlists (CRUD)
// ============================================================

import 'package:hive/hive.dart';

import '../models/song.dart';
import '../models/playlist.dart';

class LibraryService {
  // Hive boxes (opened in main.dart)
  Box<Song> get _likedBox => Hive.box<Song>('liked_songs');
  Box<Song> get _recentBox => Hive.box<Song>('recently_played');
  Box<Playlist> get _playlistsBox => Hive.box<Playlist>('playlists');

  /// Exposed for FirestoreService sync (mirrors server-side likes to local cache).
  Box<Song> get likedBox => _likedBox;

  static const int _maxRecent = 50;

  // ── Liked songs ───────────────────────────────────────────────────────────

  List<Song> getLikedSongs() => _likedBox.values.toList().reversed.toList();

  bool isLiked(String songId) => _likedBox.containsKey(songId);

  Future<void> likeSong(Song song) => _likedBox.put(song.id, _clone(song));

  Future<void> unlikeSong(String songId) => _likedBox.delete(songId);

  Future<void> toggleLike(Song song) async {
    if (isLiked(song.id)) {
      await unlikeSong(song.id);
    } else {
      await likeSong(song);
    }
  }

  // ── Recently played ───────────────────────────────────────────────────────

  List<Song> getRecentlyPlayed() => _recentBox.values.toList().reversed.toList();

  Future<void> addToRecentlyPlayed(Song song) async {
    // Remove if already present (to move it to front)
    await _recentBox.delete(song.id);

    // Cap at max
    if (_recentBox.length >= _maxRecent) {
      final oldest = _recentBox.keys.first;
      await _recentBox.delete(oldest);
    }

    await _recentBox.put(song.id, _clone(song));
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  List<Playlist> getPlaylists() => _playlistsBox.values.toList();

  Future<void> createPlaylist(String name, {String? description}) async {
    final playlist = Playlist(name: name, description: description);
    await _playlistsBox.add(playlist);
  }

  Future<void> renamePlaylist(int boxKey, String newName) async {
    final playlist = _playlistsBox.get(boxKey);
    if (playlist != null) {
      playlist.name = newName;
      await playlist.save();
    }
  }

  Future<void> deletePlaylist(int boxKey) => _playlistsBox.delete(boxKey);

  Future<void> addSongToPlaylist(int playlistKey, Song song) async {
    final playlist = _playlistsBox.get(playlistKey);
    if (playlist != null && !playlist.songs.any((s) => s.id == song.id)) {
      playlist.songs.add(_clone(song));
      await playlist.save();
    }
  }

  Future<void> removeSongFromPlaylist(int playlistKey, String songId) async {
    final playlist = _playlistsBox.get(playlistKey);
    if (playlist != null) {
      playlist.songs.removeWhere((s) => s.id == songId);
      await playlist.save();
    }
  }

  // Clone to avoid Hive "Object already in another box" exception
  Song _clone(Song s) => Song(
        id: s.id,
        title: s.title,
        channelName: s.channelName,
        thumbnailUrl: s.thumbnailUrl,
        duration: s.duration,
        streamUrl: s.streamUrl,
        streamUrlFetchedAt: s.streamUrlFetchedAt,
      );
}

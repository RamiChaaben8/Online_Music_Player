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
  static bool _guestMode = false;

  static void setGuestMode(bool enabled) => _guestMode = enabled;

  Box<Song> get _likedBox =>
      Hive.box<Song>(_guestMode ? 'guest_liked_songs' : 'liked_songs');
  Box<Song> get _recentBox =>
      Hive.box<Song>(_guestMode ? 'guest_recently_played' : 'recently_played');
  Box<Playlist> get _playlistsBox =>
      Hive.box<Playlist>(_guestMode ? 'guest_playlists' : 'playlists');
  Box<dynamic> get _settingsBox => Hive.box<dynamic>('settings');

  String get _foldersKey => _guestMode ? 'guest_folders' : 'local_folders';

  List<String> getFolders() =>
      (_settingsBox.get(_foldersKey) as List?)?.cast<String>().toList() ??
      <String>[];

  Future<void> addFolder(String name) async {
    final folders = getFolders().toSet()..add(name);
    await _settingsBox.put(_foldersKey, folders.toList());
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final folders =
        getFolders().map((name) => name == oldName ? newName : name).toSet();
    await _settingsBox.put(_foldersKey, folders.toList());
  }

  Future<void> deleteFolder(String name) async {
    final folders = getFolders()..remove(name);
    await _settingsBox.put(_foldersKey, folders);
  }

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

  List<Song> getRecentlyPlayed() =>
      _recentBox.values.toList().reversed.toList();

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

  Future<void> createPlaylist(String name,
      {String? description, String visibility = 'private'}) async {
    final playlist =
        Playlist(name: name, description: description, visibility: visibility);
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

  /// Persist a new song order for a playlist (drag-to-reorder).
  Future<void> updatePlaylistSongs(int playlistKey, List<Song> songs) async {
    final playlist = _playlistsBox.get(playlistKey);
    if (playlist != null) {
      // Re-clone so the rebuilt list doesn't share Song instances with the
      // caller's list, which would trip Hive's object-ownership check.
      playlist.songs = songs.map(_clone).toList();
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

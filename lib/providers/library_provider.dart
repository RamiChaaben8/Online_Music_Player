// ============================================================
// providers/library_provider.dart
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../services/library_service.dart';
import '../services/firestore_service.dart';
import 'sync_provider.dart';

// ─── Library state ────────────────────────────────────────────────────────────

class LibraryState {
  final List<Song> likedSongs;
  final List<Song> recentlyPlayed;
  final List<Playlist> playlists;
  final bool isLoading;

  const LibraryState({
    this.likedSongs = const [],
    this.recentlyPlayed = const [],
    this.playlists = const [],
    this.isLoading = false,
  });

  LibraryState copyWith({
    List<Song>? likedSongs,
    List<Song>? recentlyPlayed,
    List<Playlist>? playlists,
    bool? isLoading,
  }) {
    return LibraryState(
      likedSongs: likedSongs ?? this.likedSongs,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isLiked(String songId) => likedSongs.any((s) => s.id == songId);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryService _hive;
  final FirestoreService _fs;

  String? _uid;
  StreamSubscription? _playlistsSub;
  StreamSubscription? _likesSub;

  LibraryNotifier(this._hive, this._fs) : super(const LibraryState()) {
    _loadLocal();
  }

  void _loadLocal() {
    state = LibraryState(
      likedSongs: _hive.getLikedSongs(),
      recentlyPlayed: _hive.getRecentlyPlayed(),
      playlists: _hive.getPlaylists(),
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  void initForUser(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    state = state.copyWith(isLoading: true);

    _playlistsSub?.cancel();
    _likesSub?.cancel();

    _playlistsSub = _fs.playlistsStream(uid).listen(
      (playlists) => state = state.copyWith(playlists: playlists, isLoading: false),
      onError: (_) => state = state.copyWith(isLoading: false),
    );

    _likesSub = _fs.likesStream(uid).listen((liked) {
      state = state.copyWith(likedSongs: liked);
      _syncLikesToHive(liked);
    });
  }

  void resetForLogout() {
    _playlistsSub?.cancel();
    _likesSub?.cancel();
    _uid = null;
    _loadLocal();
  }

  Future<void> _syncLikesToHive(List<Song> liked) async {
    try {
      final box = _hive.likedBox;
      await box.clear();
      for (final s in liked) {
        await box.put(s.id, s);
      }
    } catch (_) {}
  }

  // ── Likes ──────────────────────────────────────────────────────────────────

  Future<void> toggleLike(Song song) async {
    final wasLiked = state.isLiked(song.id);

    // Optimistic update
    state = state.copyWith(
      likedSongs: wasLiked
          ? state.likedSongs.where((s) => s.id != song.id).toList()
          : [song, ...state.likedSongs],
    );

    await _hive.toggleLike(song).catchError((_) {});

    if (_uid != null) {
      if (wasLiked) {
        await _fs.unlikeSong(_uid!, song.id).catchError((_) {});
      } else {
        await _fs.likeSong(_uid!, song).catchError((_) {});
      }
    }
  }

  // ── Recently played ────────────────────────────────────────────────────────

  Future<void> addToRecentlyPlayed(Song song) async {
    await _hive.addToRecentlyPlayed(song);
    state = state.copyWith(recentlyPlayed: _hive.getRecentlyPlayed());
  }

  // ── Playlists ──────────────────────────────────────────────────────────────

  Future<void> createPlaylist(String name, {String? description}) async {
    if (_uid != null) {
      try {
        await _fs.createPlaylist(_uid!, name, description: description);
        // Live listener will update state
      } catch (_) {
        await _hive.createPlaylist(name, description: description).catchError((_) {});
        state = state.copyWith(playlists: _hive.getPlaylists());
      }
    } else {
      await _hive.createPlaylist(name, description: description);
      state = state.copyWith(playlists: _hive.getPlaylists());
    }
  }

  /// Rename a playlist by Playlist object (primary — works for both Hive and Firestore playlists).
  Future<void> renamePlaylistObj(Playlist playlist, String name) async {
    final fsId = playlist.firestoreId;
    final hiveKey = playlist.key as int?;

    // Optimistic UI
    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matchesPlaylist(p, playlist)) {
          return Playlist(
              name: name,
              songs: p.songs,
              createdAt: p.createdAt,
              description: p.description);
        }
        return p;
      }).toList(),
    );

    if (hiveKey != null) {
      await _hive.renamePlaylist(hiveKey, name).catchError((_) {});
    }
    if (_uid != null && fsId != null) {
      await _fs.renamePlaylist(_uid!, fsId, name).catchError((_) {});
    }
  }

  /// Rename a playlist. Pass the Playlist object — we extract the right ID.
  /// Legacy overload that accepts a hive key integer.
  Future<void> renamePlaylist(int hiveKey, String name, {String? firestoreId}) async {
    final fsId = firestoreId ?? _firestoreIdForHiveKey(hiveKey);

    // Optimistic UI
    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matches(p, hiveKey, fsId)) {
          return Playlist(name: name, songs: p.songs,
              createdAt: p.createdAt, description: p.description);
        }
        return p;
      }).toList(),
    );

    await _hive.renamePlaylist(hiveKey, name).catchError((_) {});
    if (_uid != null && fsId != null) {
      await _fs.renamePlaylist(_uid!, fsId, name).catchError((_) {});
    }
  }

  /// Delete a playlist by Playlist object (primary — works for both Hive and Firestore playlists).
  Future<void> deletePlaylistObj(Playlist playlist) async {
    final fsId = playlist.firestoreId;
    final hiveKey = playlist.key as int?;

    state = state.copyWith(
      playlists: state.playlists
          .where((p) => !_matchesPlaylist(p, playlist))
          .toList(),
    );

    if (hiveKey != null) {
      await _hive.deletePlaylist(hiveKey).catchError((_) {});
    }
    if (_uid != null && fsId != null) {
      await _fs.deletePlaylist(_uid!, fsId).catchError((_) {});
    }
  }

  /// Delete a playlist. Accepts either hiveKey or Playlist object.
  /// Legacy overload that accepts a hive key integer.
  Future<void> deletePlaylist(int hiveKey, {String? firestoreId}) async {
    final fsId = firestoreId ?? _firestoreIdForHiveKey(hiveKey);

    state = state.copyWith(
      playlists: state.playlists
          .where((p) => !_matches(p, hiveKey, fsId))
          .toList(),
    );

    await _hive.deletePlaylist(hiveKey).catchError((_) {});
    if (_uid != null && fsId != null) {
      await _fs.deletePlaylist(_uid!, fsId).catchError((_) {});
    }
  }

  /// Add a song to a playlist — takes the Playlist object directly.
  /// This is the primary entry point used by AddToPlaylistSheet and
  /// SongContextMenu, so it doesn't need a hive key at all.
  Future<void> addSongToPlaylistObj(Playlist playlist, Song song) async {
    final fsId = playlist.firestoreId;
    final hiveKey = playlist.key as int?;

    // Optimistic UI
    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matchesPlaylist(p, playlist)) {
          if (!p.songs.any((s) => s.id == song.id)) {
            return Playlist(name: p.name, songs: [...p.songs, song],
                createdAt: p.createdAt, description: p.description);
          }
        }
        return p;
      }).toList(),
    );

    if (hiveKey != null) {
      await _hive.addSongToPlaylist(hiveKey, song).catchError((_) {});
    }
    if (_uid != null && fsId != null) {
      await _fs.addSongToPlaylist(_uid!, fsId, song).catchError((_) {});
    }
  }

  /// Legacy overload used by some existing screens that pass hiveKey.
  Future<void> addSongToPlaylist(int playlistKey, Song song,
      {String? firestoreId}) async {
    final fsId = firestoreId ?? _firestoreIdForHiveKey(playlistKey);

    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matches(p, playlistKey, fsId)) {
          if (!p.songs.any((s) => s.id == song.id)) {
            return Playlist(name: p.name, songs: [...p.songs, song],
                createdAt: p.createdAt, description: p.description);
          }
        }
        return p;
      }).toList(),
    );

    await _hive.addSongToPlaylist(playlistKey, song).catchError((_) {});
    if (_uid != null && fsId != null) {
      await _fs.addSongToPlaylist(_uid!, fsId, song).catchError((_) {});
    }
  }

  /// Remove a song from a playlist — takes the Playlist object directly.
  Future<void> removeSongFromPlaylistObj(Playlist playlist, String songId) async {
    final fsId = playlist.firestoreId;
    final hiveKey = playlist.key as int?;

    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matchesPlaylist(p, playlist)) {
          return Playlist(name: p.name,
              songs: p.songs.where((s) => s.id != songId).toList(),
              createdAt: p.createdAt, description: p.description);
        }
        return p;
      }).toList(),
    );

    if (hiveKey != null) {
      await _hive.removeSongFromPlaylist(hiveKey, songId).catchError((_) {});
    }
    if (_uid != null && fsId != null) {
      await _fs.removeSongFromPlaylist(_uid!, fsId, songId).catchError((_) {});
    }
  }

  /// Legacy overload.
  Future<void> removeSongFromPlaylist(int playlistKey, String songId,
      {String? firestoreId}) async {
    final fsId = firestoreId ?? _firestoreIdForHiveKey(playlistKey);

    state = state.copyWith(
      playlists: state.playlists.map((p) {
        if (_matches(p, playlistKey, fsId)) {
          return Playlist(name: p.name,
              songs: p.songs.where((s) => s.id != songId).toList(),
              createdAt: p.createdAt, description: p.description);
        }
        return p;
      }).toList(),
    );

    await _hive.removeSongFromPlaylist(playlistKey, songId).catchError((_) {});
    if (_uid != null && fsId != null) {
      await _fs.removeSongFromPlaylist(_uid!, fsId, songId).catchError((_) {});
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Get the Firestore ID for a playlist identified by its Hive key.
  String? _firestoreIdForHiveKey(int hiveKey) {
    try {
      return state.playlists
          .firstWhere((p) => p.key == hiveKey)
          .firestoreId;
    } catch (_) {
      return null;
    }
  }

  bool _matches(Playlist p, int? hiveKey, String? fsId) {
    if (fsId != null && p.firestoreId == fsId) return true;
    if (hiveKey != null && p.key == hiveKey) return true;
    return false;
  }

  bool _matchesPlaylist(Playlist p, Playlist target) {
    if (target.firestoreId != null && p.firestoreId == target.firestoreId) {
      return true;
    }
    if (target.key != null && p.key == target.key) return true;
    // Last resort: same name + createdAt
    return p.name == target.name && p.createdAt == target.createdAt;
  }

  @override
  void dispose() {
    _playlistsSub?.cancel();
    _likesSub?.cancel();
    super.dispose();
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final libraryServiceProvider =
    Provider<LibraryService>((ref) => LibraryService());

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(
    ref.watch(libraryServiceProvider),
    ref.watch(firestoreServiceProvider),
  );
});

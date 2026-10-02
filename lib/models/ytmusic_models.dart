// lib/models/ytmusic_models.dart
// Immutable data models for the YouTube Music Innertube integration.

import 'song.dart';

// ---------------------------------------------------------------------------
// YtSong
// ---------------------------------------------------------------------------

class YtSong {
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final String coverUrl;
  final Duration duration;

  const YtSong({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    required this.coverUrl,
    required this.duration,
  });

  bool get isValid => videoId.isNotEmpty && title.isNotEmpty;

  Song toSong() => Song(
        id: videoId,
        title: title,
        channelName: artist,
        thumbnailUrl: coverUrl,
        duration: duration,
      );

  @override
  bool operator ==(Object other) => other is YtSong && other.videoId == videoId;

  @override
  int get hashCode => videoId.hashCode;

  @override
  String toString() =>
      'YtSong(videoId: $videoId, title: $title, artist: $artist)';
}

// ---------------------------------------------------------------------------
// YtAlbumType
// ---------------------------------------------------------------------------

enum YtAlbumType { album, ep, single, unknown }

// ---------------------------------------------------------------------------
// YtAlbum
// ---------------------------------------------------------------------------

class YtAlbum {
  final String browseId;
  final String title;
  final String artist;
  final String coverUrl;
  final int? year;
  final YtAlbumType type;
  final bool isExplicit;

  const YtAlbum({
    required this.browseId,
    required this.title,
    required this.artist,
    required this.coverUrl,
    this.year,
    this.type = YtAlbumType.unknown,
    this.isExplicit = false,
  });

  bool get isValid => browseId.isNotEmpty && title.isNotEmpty;

  /// Human-readable type label: "Album", "EP", "Single".
  String get typeLabel {
    switch (type) {
      case YtAlbumType.album:
        return 'Album';
      case YtAlbumType.ep:
        return 'EP';
      case YtAlbumType.single:
        return 'Single';
      case YtAlbumType.unknown:
        return 'Album';
    }
  }

  /// Subtitle for display: "Album • Artist" or "EP • Artist".
  String get displaySubtitle {
    final artistStr = artist.isNotEmpty ? ' • $artist' : '';
    return '$typeLabel$artistStr';
  }

  @override
  bool operator ==(Object other) =>
      other is YtAlbum && other.browseId == browseId;

  @override
  int get hashCode => browseId.hashCode;

  @override
  String toString() =>
      'YtAlbum(browseId: $browseId, title: $title, artist: $artist, '
      'type: $type)';
}

// ---------------------------------------------------------------------------
// YtArtist
// ---------------------------------------------------------------------------

class YtArtist {
  final String browseId;
  final String name;
  final String pictureUrl;

  const YtArtist({
    required this.browseId,
    required this.name,
    required this.pictureUrl,
  });

  bool get isValid => browseId.isNotEmpty && name.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is YtArtist && other.browseId == browseId;

  @override
  int get hashCode => browseId.hashCode;

  @override
  String toString() => 'YtArtist(browseId: $browseId, name: $name)';
}

// ---------------------------------------------------------------------------
// YtPlaylist
// ---------------------------------------------------------------------------

class YtPlaylist {
  final String browseId;
  final String title;
  final String subtitle;
  final String coverUrl;

  const YtPlaylist({
    required this.browseId,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
  });

  bool get isValid => browseId.isNotEmpty && title.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is YtPlaylist && other.browseId == browseId;

  @override
  int get hashCode => browseId.hashCode;

  @override
  String toString() => 'YtPlaylist(browseId: $browseId, title: $title)';
}

// ---------------------------------------------------------------------------
// YtMoodChip
// ---------------------------------------------------------------------------

class YtMoodChip {
  final String label;
  final String params;

  const YtMoodChip({required this.label, required this.params});

  bool get isValid => label.isNotEmpty && params.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is YtMoodChip && other.label == label && other.params == params;

  @override
  int get hashCode => Object.hash(label, params);

  @override
  String toString() => 'YtMoodChip(label: $label)';
}

// ---------------------------------------------------------------------------
// YtSection  — one horizontal shelf on the home / explore page
// ---------------------------------------------------------------------------

class YtSection {
  final String title;
  final List<YtSong> songs;
  final List<YtAlbum> albums;
  final List<YtArtist> artists;
  final List<YtPlaylist> playlists;

  const YtSection({
    required this.title,
    required this.songs,
    required this.albums,
    required this.artists,
    required this.playlists,
  });

  bool get isNotEmpty =>
      songs.isNotEmpty ||
      albums.isNotEmpty ||
      artists.isNotEmpty ||
      playlists.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is YtSection && other.title == title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() =>
      'YtSection(title: $title, songs: ${songs.length}, '
      'albums: ${albums.length}, artists: ${artists.length}, '
      'playlists: ${playlists.length})';
}

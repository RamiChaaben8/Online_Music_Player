// ============================================================
// models/playlist.dart — Playlist data model stored in Hive
// ============================================================

import 'package:hive/hive.dart';
import 'song.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Song> songs;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  String? description;

  Playlist({
    required this.name,
    List<Song>? songs,
    DateTime? createdAt,
    this.description,
  })  : songs = songs ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// Convenience: thumbnail of the first song in the playlist.
  String? get coverThumbnail => songs.isNotEmpty ? songs.first.thumbnailUrl : null;
}

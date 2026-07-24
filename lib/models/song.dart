// ============================================================
// models/song.dart — Song data model stored in Hive
// ============================================================

import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  final String id; // YouTube video ID

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String channelName;

  @HiveField(3)
  final String thumbnailUrl;

  @HiveField(4)
  final Duration duration;

  @HiveField(5)
  final String? streamUrl; // Cached stream URL (expires ~6h)

  @HiveField(6)
  final DateTime? streamUrlFetchedAt; // For expiry checks

  Song({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.duration,
    this.streamUrl,
    this.streamUrlFetchedAt,
  });

  /// Returns a copy with updated fields.
  Song copyWith({
    String? streamUrl,
    DateTime? streamUrlFetchedAt,
  }) {
    return Song(
      id: id,
      title: title,
      channelName: channelName,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      streamUrl: streamUrl ?? this.streamUrl,
      streamUrlFetchedAt: streamUrlFetchedAt ?? this.streamUrlFetchedAt,
    );
  }

  /// Stream URLs expire after ~6 hours; check before using cached URL.
  bool get isStreamUrlExpired {
    if (streamUrl == null || streamUrlFetchedAt == null) return true;
    return DateTime.now().difference(streamUrlFetchedAt!) > const Duration(hours: 5);
  }

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

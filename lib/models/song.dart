// ============================================================
// models/song.dart — Song data model stored in Hive
// ============================================================

import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  final String id; // YouTube video ID (or file path for local songs)

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

  @HiveField(7)
  final bool isLocal; // true = downloaded file on device

  @HiveField(8)
  final String? localPath; // absolute path to the local file

  Song({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.duration,
    this.streamUrl,
    this.streamUrlFetchedAt,
    this.isLocal = false,
    this.localPath,
  });

  Song copyWith({
    String? streamUrl,
    DateTime? streamUrlFetchedAt,
    bool? isLocal,
    String? localPath,
  }) {
    return Song(
      id: id,
      title: title,
      channelName: channelName,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      streamUrl: streamUrl ?? this.streamUrl,
      streamUrlFetchedAt: streamUrlFetchedAt ?? this.streamUrlFetchedAt,
      isLocal: isLocal ?? this.isLocal,
      localPath: localPath ?? this.localPath,
    );
  }

  bool get isStreamUrlExpired {
    if (streamUrl == null || streamUrlFetchedAt == null) return true;
    return DateTime.now().difference(streamUrlFetchedAt!) > const Duration(hours: 5);
  }

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

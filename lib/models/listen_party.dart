import 'package:cloud_firestore/cloud_firestore.dart';

import 'song.dart';

enum PartyControlMode { host, everyone }

class PartyInvite {
  final String partyId;
  final String fromUid;
  final String fromName;
  final String partyName;
  final DateTime? createdAt;

  const PartyInvite({
    required this.partyId,
    required this.fromUid,
    required this.fromName,
    required this.partyName,
    required this.createdAt,
  });
}

class ListenParty {
  final String id;
  final String hostUid;
  final List<String> memberUids;
  final List<Song> queue;
  final int currentIndex;
  final Song? currentSong;
  final int positionMs;
  final bool isPlaying;
  final int version;
  final PartyControlMode controlMode;
  final bool openToFriends;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  const ListenParty({
    required this.id,
    required this.hostUid,
    required this.memberUids,
    required this.queue,
    required this.currentIndex,
    required this.currentSong,
    required this.positionMs,
    required this.isPlaying,
    required this.version,
    required this.controlMode,
    required this.openToFriends,
    required this.expiresAt,
    required this.updatedAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool canControl(String uid) =>
      uid == hostUid || controlMode == PartyControlMode.everyone;

  factory ListenParty.fromMap(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic value) =>
        value is Timestamp ? value.toDate() : value is DateTime ? value : null;
    final rawQueue = (data['queue'] as List?) ?? const [];
    Song? song(dynamic value) => value is Map
        ? Song(
            id: value['id'] as String? ?? '',
            title: value['title'] as String? ?? '',
            channelName: value['artist'] as String? ?? '',
            thumbnailUrl: value['coverUrl'] as String? ?? '',
            duration: Duration(
                milliseconds: (value['durationMs'] as num?)?.toInt() ?? 0),
          )
        : null;
    return ListenParty(
      id: id,
      hostUid: data['hostUid'] as String? ?? '',
      memberUids: (data['memberUids'] as List?)?.cast<String>() ?? const [],
      queue: rawQueue.map(song).whereType<Song>().toList(),
      currentIndex: (data['currentIndex'] as num?)?.toInt() ?? -1,
      currentSong: song(data['currentSong']),
      positionMs: (data['positionMs'] as num?)?.toInt() ?? 0,
      isPlaying: data['isPlaying'] as bool? ?? false,
      version: (data['version'] as num?)?.toInt() ?? 0,
      controlMode: data['controlMode'] == 'everyone'
          ? PartyControlMode.everyone
          : PartyControlMode.host,
      openToFriends: data['openToFriends'] as bool? ?? false,
      expiresAt: date(data['expiresAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}

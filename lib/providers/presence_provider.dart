import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import 'player_provider.dart';
import 'sync_provider.dart';

class PresenceNotifier extends StateNotifier<bool> {
  final FirestoreService _firestore;
  final SyncNotifier _sync;
  Timer? _heartbeat;
  String? _uid;
  Map<String, bool> _privacy = const {
    'showOnlineStatus': true,
    'showActivity': true,
  };
  PlayerState? _lastPlayerState;
  String? _lastTrackId;
  bool? _lastIsPlaying;

  PresenceNotifier(this._firestore, this._sync) : super(false);

  Future<void> start(String uid, {PlayerState? playerState}) async {
    if (_uid != uid) {
      await stop();
      _uid = uid;
      final profile = await _firestore.getPublicProfile(uid);
      if (profile != null) {
        _privacy = profile.privacy;
      }
    }
    _lastPlayerState = playerState ?? _lastPlayerState;
    state = true;
    await _writePresence(writeActivity: true);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      _writePresence();
    });
  }

  Future<void> updateFromPlayer(PlayerState playerState) async {
    final changed = _lastTrackId != playerState.currentSong?.id ||
        _lastIsPlaying != playerState.isPlaying;
    _lastPlayerState = playerState;
    _lastTrackId = playerState.currentSong?.id;
    _lastIsPlaying = playerState.isPlaying;
    if (changed && _uid != null && state) {
      await _writePresence(writeActivity: true);
    }
  }

  Future<void> updatePrivacy(Map<String, bool> privacy) async {
    _privacy = {
      'showOnlineStatus': privacy['showOnlineStatus'] ?? true,
      'showActivity': privacy['showActivity'] ?? true,
    };
    if (_uid != null && state) {
      await _writePresence(writeActivity: true);
    }
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_uid != null) {
      try {
        await _firestore.updatePresence(
          uid: _uid!,
          deviceName: _sync.service.deviceName ?? 'Unknown device',
          online: false,
          showOnlineStatus: _privacy['showOnlineStatus'] ?? true,
          showActivity: _privacy['showActivity'] ?? true,
          activity: null,
          writeActivity: true,
        );
      } catch (_) {}
    }
    state = false;
  }

  Future<void> _writePresence({bool writeActivity = false}) async {
    final uid = _uid;
    if (uid == null) return;
    final player = _lastPlayerState;
    await _firestore.updatePresence(
      uid: uid,
      deviceName: _sync.service.deviceName ?? 'Unknown device',
      online: true,
      showOnlineStatus: _privacy['showOnlineStatus'] ?? true,
      showActivity: _privacy['showActivity'] ?? true,
      activity: _activityFor(player),
      writeActivity: writeActivity,
    );
  }

  Map<String, dynamic>? _activityFor(PlayerState? player) {
    final song = player?.currentSong;
    if (song == null) return null;
    return {
      'trackId': song.id,
      'title': song.title,
      'artist': song.channelName,
      'coverUrl': song.thumbnailUrl,
      'durationMs': song.duration.inMilliseconds,
      'isPlaying': player?.isPlaying ?? false,
      'updatedAt': FieldValue.serverTimestamp(),
      'partyId': null,
    };
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }
}

final presenceProvider =
    StateNotifierProvider<PresenceNotifier, bool>((ref) {
  return PresenceNotifier(
    ref.watch(firestoreServiceProvider),
    ref.watch(syncProvider.notifier),
  );
});

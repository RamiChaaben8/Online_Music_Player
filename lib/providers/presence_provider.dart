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
      _heartbeatTick();
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
    // Publishing `isPlaying: true` for a track that is merely loaded but paused
    // is what made peers show the "now playing" equalizer for someone who was
    // not actually listening. Nothing to publish unless we are really playing.
    if (player?.isPlaying != true) return null;
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

  /// Heartbeat tick. Rewrites the activity block on every tick rather than only
  /// on track changes.
  ///
  /// The old path passed `writeActivity: false` here, which left the remote copy
  /// of our activity frozen at whatever it was when we last changed tracks. A
  /// peer that paused, or whose playback ended without a track change, kept
  /// advertising `isPlaying: true` until their next track change — or forever, if
  /// they closed the app. One extra small write per minute is worth not lying
  /// about what we are doing.
  Future<void> _heartbeatTick() async {
    if (!_privacy['showOnlineStatus']! && !_privacy['showActivity']!) {
      // Both off: there is nothing truthful to publish, so just expire the
      // online flag rather than re-sending the same fields every minute.
      await _firestore.updatePresence(
        uid: _uid!,
        deviceName: _sync.service.deviceName ?? 'Unknown device',
        online: false,
        showOnlineStatus: true,
        showActivity: false,
        activity: null,
        writeActivity: true,
      );
      return;
    }
    await _writePresence(writeActivity: true);
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

/// Live presence for one *other* user, keyed by uid.
///
/// Exists so the friend rows stop building a throwaway `Stream` inside their
/// `build` method. `StreamBuilder` compares `oldWidget.stream != widget.stream`
/// by identity, so a stream created during build made every parent rebuild
/// cancel and re-listen, briefly painting the previous friend's data into the
/// new friend's row. A family provider creates the stream once per uid and
/// keeps it subscribed, so rows only re-render when that friend's data changes.
final friendPresenceProvider =
    StreamProvider.autoDispose.family<PresenceInfo?, String>(
        (ref, uid) => ref.watch(firestoreServiceProvider).presenceStream(uid));

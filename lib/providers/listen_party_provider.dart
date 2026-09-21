import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listen_party.dart';
import '../services/firestore_service.dart';
import 'player_provider.dart';
import 'sync_provider.dart';

class ListenPartyState {
  final ListenParty? party;
  final bool loading;
  final String? error;
  final List<PartyInvite> invites;
  const ListenPartyState({this.party, this.loading = false, this.error, this.invites = const []});

  ListenPartyState copyWith({ListenParty? party, bool? loading, String? error,
      List<PartyInvite>? invites, bool clearParty = false, bool clearError = false}) {
    return ListenPartyState(
      party: clearParty ? null : (party ?? this.party),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      invites: invites ?? this.invites,
    );
  }

}

class ListenPartyNotifier extends StateNotifier<ListenPartyState> {
  final FirestoreService _service;
  final PlayerNotifier _player;
  StreamSubscription<ListenParty?>? _partySub;
  StreamSubscription<List<PartyInvite>>? _inviteSub;
  Timer? _partyPollTimer;
  Timer? _invitePollTimer;
  Timer? _clockSyncTimer;
  Timer? _publishTimer;
  Timer? _positionPublishTimer;
  String? _uid;
  int _serverOffsetMs = 0;
  int _lastAppliedVersion = 0;
  bool _applyingServerState = false;
  bool _skipNextServerApply = false;
  bool _publishing = false;
  bool _pollingParty = false;
  PlayerState? _latestPlayerState;
  String _lastPublishedSignature = '';

  ListenPartyNotifier(this._service, this._player) : super(const ListenPartyState());

  Future<void> create({
    PartyControlMode controlMode = PartyControlMode.host,
    bool openToFriends = false,
  }) async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(
        loading: false,
        error: 'You must be signed in to create a listen party.',
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final ps = _player.state;
      final id = await _service.createListenParty(
        uid: uid,
        queue: ps.queue,
        currentIndex: ps.currentIndex,
        currentSong: ps.currentSong,
        isPlaying: ps.isPlaying,
        controlMode: controlMode,
        openToFriends: openToFriends,
      );
      _skipNextServerApply = true;
      final initialParty = ListenParty(
        id: id,
        hostUid: uid,
        memberUids: [uid],
        queue: ps.queue,
        currentIndex: ps.currentIndex,
        currentSong: ps.currentSong,
        positionMs: ps.position.inMilliseconds,
        isPlaying: ps.isPlaying,
        version: 1,
        controlMode: controlMode,
        openToFriends: openToFriends,
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
        updatedAt: DateTime.now(),
      );
      await _attachToParty(id, uid, initialParty: initialParty);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> join(String partyId, {String? uid}) async {
    final memberUid = uid ?? _uid;
    if (memberUid == null) {
      state = state.copyWith(
        loading: false,
        error: 'You must be signed in to join a listen party.',
      );
      return false;
    }
    if (partyId.trim().isEmpty) {
      state = state.copyWith(
        loading: false,
        error: 'Enter a party ID.',
      );
      return false;
    }
    await leave();
    _lastAppliedVersion = 0;
    _skipNextServerApply = false;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _service.joinListenParty(partyId, memberUid);
      await _attachToParty(partyId, memberUid);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> _attachToParty(
    String partyId,
    String uid, {
    ListenParty? initialParty,
  }) async {
    await _partySub?.cancel();
    _partyPollTimer?.cancel();
    if (Platform.isWindows) {
      if (initialParty != null) {
        _onParty(initialParty);
      } else {
        await _pollParty(partyId);
      }
      _partyPollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(_pollParty(partyId)),
      );
    } else {
      _partySub = _service.listenPartyStream(partyId).listen(
        _onParty,
        onError: (Object error, StackTrace _) {
          if (mounted) {
            state = state.copyWith(loading: false, error: error.toString());
          }
        },
      );
    }
    if (!Platform.isWindows) unawaited(_syncClock(uid));
    _clockSyncTimer?.cancel();
    if (!Platform.isWindows) {
      _clockSyncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => unawaited(_syncClock(uid)),
      );
    }
    state = state.copyWith(loading: false);
  }

  Future<void> leave() async {
    _publishTimer?.cancel();
    _positionPublishTimer?.cancel();
    _clockSyncTimer?.cancel();
    _clockSyncTimer = null;
    _partyPollTimer?.cancel();
    _partyPollTimer = null;
    await _partySub?.cancel();
    _partySub = null;
    final party = state.party;
    final uid = _uid;
    state = state.copyWith(clearParty: true, loading: false);

    // The Windows Firebase plugin can crash while a Firestore read/write is
    // issued during listener teardown. Detach locally first and avoid that
    // native channel path on Windows; the party expires automatically.
    if (Platform.isWindows) return;

    if (party != null && uid != null) {
      try {
        await _service.leaveListenParty(party.id, uid);
      } catch (_) {}
    }
  }

  Future<void> invite(String toUid) async {
    final party = state.party;
    final uid = _uid;
    if (party == null || uid == null) {
      state = state.copyWith(
        error: 'Join a listen party before inviting a friend.',
      );
      return;
    }
    if (toUid.trim().isEmpty) {
      state = state.copyWith(error: 'Enter a friend UID.');
      return;
    }
    final wasPolling = Platform.isWindows && _partyPollTimer != null;
    _partyPollTimer?.cancel();
    _partyPollTimer = null;
    try {
      await _service.inviteToListenParty(partyId: party.id, fromUid: uid, toUid: toUid);
      if (wasPolling && mounted && state.party?.id == party.id) {
        _partyPollTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => unawaited(_pollParty(party.id)),
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      if (wasPolling && mounted && state.party?.id == party.id) {
        _partyPollTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => unawaited(_pollParty(party.id)),
        );
      }
    }
  }

  Future<void> _pollParty(String partyId) async {
    if (_pollingParty) return;
    _pollingParty = true;
    try {
      _onParty(await _service.getListenParty(partyId));
    } catch (error) {
      if (mounted) {
        state = state.copyWith(loading: false, error: error.toString());
      }
    } finally {
      _pollingParty = false;
    }
  }

  Future<void> acceptInvite(PartyInvite invite) async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(error: 'You must be signed in to join a party.');
      return;
    }

    try {
      final joined = await join(invite.partyId);
      if (joined) {
        await _service.deleteListenPartyInvite(uid, invite.partyId);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> declineInvite(PartyInvite invite) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _service.deleteListenPartyInvite(uid, invite.partyId);
      state = state.copyWith(
        invites: state.invites
            .where((item) => item.partyId != invite.partyId)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void initForUser(String uid) {
    if (Platform.isWindows) return;
    if (_uid == uid) return;
    _uid = uid;
    _inviteSub?.cancel();
    _invitePollTimer?.cancel();
    if (Platform.isWindows) {
      Future<void> pollInvites() async {
        try {
          final items = await _service.getListenPartyInvites(uid);
          if (mounted) state = state.copyWith(invites: items);
        } catch (_) {}
      }

      unawaited(pollInvites());
      _invitePollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(pollInvites()),
      );
    } else {
      _inviteSub = _service.listenPartyInvites(uid).listen((items) {
        if (mounted) state = state.copyWith(invites: items);
      });
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void _onParty(ListenParty? party) {
    if (!mounted) return;
    if (party == null || party.isExpired) {
      state = state.copyWith(clearParty: true, loading: false);
      _partySub?.cancel();
      _partySub = null;
      return;
    }
    state = state.copyWith(party: party, loading: false, clearError: true);
    if (party.version <= _lastAppliedVersion) return;
    _lastAppliedVersion = party.version;
    if (_skipNextServerApply) {
      _skipNextServerApply = false;
      return;
    }
    // The Windows media backend can terminate the native runner when a
    // polled party update replaces/ seeks the active audio source. Keep the
    // party state synchronized on Windows, but let its local player remain
    // under direct user control.
    if (Platform.isWindows) return;
    _applyServerState(party);
  }

  Future<void> _applyServerState(ListenParty party) async {
    final song = party.currentSong;
    if (song == null) return;
    final current = _player.state.currentSong;
    final sameQueue = _player.state.queue.length == party.queue.length &&
        _player.state.queue.asMap().entries.every(
              (entry) => entry.value.id == party.queue[entry.key].id,
            );
    if (current?.id != song.id ||
        _player.state.currentIndex != party.currentIndex ||
        !sameQueue) {
      _applyingServerState = true;
      try {
        _player.playSong(
          song,
          queue: party.queue,
          suppressRemoteCommand: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _player.seek(Duration(milliseconds: _syncedPosition(party)));
        if (!party.isPlaying) await _player.pause();
      } finally {
        _applyingServerState = false;
      }
    } else {
      await _player.seek(Duration(milliseconds: _syncedPosition(party)));
      if (party.isPlaying && !_player.state.isPlaying) {
        await _player.play();
      } else if (!party.isPlaying && _player.state.isPlaying) {
        await _player.pause();
      }
    }
  }

  int _syncedPosition(ListenParty party) {
    if (!party.isPlaying || party.updatedAt == null) return party.positionMs;
    final serverNow = DateTime.now().add(Duration(milliseconds: _serverOffsetMs));
    final elapsed = serverNow.difference(party.updatedAt!).inMilliseconds;
    return (party.positionMs + elapsed).clamp(0, 1 << 31);
  }

  Future<void> _syncClock(String uid) async {
    try {
      _serverOffsetMs = await _service.estimateServerClockOffset(uid);
    } catch (_) {}
  }

  void _schedulePublish(PlayerState ps) {
    final party = state.party;
    final uid = _uid;
    if (_applyingServerState || party == null || uid == null || !party.canControl(uid)) return;
    _latestPlayerState = ps;
    final signature = [
      ps.currentSong?.id ?? '',
      ps.currentIndex,
      ps.queue.map((song) => song.id).join(','),
      ps.isPlaying,
    ].join('|');
    final changed = signature != _lastPublishedSignature;
    if (!changed && !ps.isPlaying) return;
    _publishTimer?.cancel();
    if (changed) {
      _publishTimer = Timer(const Duration(milliseconds: 150), _publishLatest);
    }
    if (ps.isPlaying && _positionPublishTimer == null) {
      _positionPublishTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _publishLatest(),
      );
    } else if (!ps.isPlaying) {
      _positionPublishTimer?.cancel();
      _positionPublishTimer = null;
    }
  }

  Future<void> _publishLatest() async {
    final party = state.party;
    final uid = _uid;
    final ps = _latestPlayerState;
    if (_publishing ||
        party == null ||
        uid == null ||
        ps == null ||
        _applyingServerState ||
        !party.canControl(uid)) {
      return;
    }
    _publishing = true;
    try {
      await _service.updateListenPartyState(
        partyId: party.id,
        uid: uid,
        expectedVersion: party.version,
        queue: ps.queue,
        currentIndex: ps.currentIndex,
        currentSong: ps.currentSong,
        positionMs: ps.position.inMilliseconds,
        isPlaying: ps.isPlaying,
      );
      _lastPublishedSignature = [
        ps.currentSong?.id ?? '',
        ps.currentIndex,
        ps.queue.map((song) => song.id).join(','),
        ps.isPlaying,
      ].join('|');
    } catch (_) {
      // The next player event or heartbeat retries with the latest party
      // version received from Firestore.
    } finally {
      _publishing = false;
    }
  }

  @override
  void dispose() {
    _partySub?.cancel();
    _inviteSub?.cancel();
    _partyPollTimer?.cancel();
    _invitePollTimer?.cancel();
    _clockSyncTimer?.cancel();
    _publishTimer?.cancel();
    _positionPublishTimer?.cancel();
    super.dispose();
  }
}

final listenPartyProvider = StateNotifierProvider<ListenPartyNotifier, ListenPartyState>((ref) {
  final notifier = ListenPartyNotifier(
    ref.watch(firestoreServiceProvider),
    ref.watch(playerProvider.notifier),
  );
  ref.listen<PlayerState>(playerProvider, (_, next) => notifier._schedulePublish(next));
  return notifier;
});

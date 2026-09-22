import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

class CollaborationInvitesNotifier extends StateNotifier<List<PlaylistInvite>> {
  final FirestoreService _service;
  final Ref _ref;
  StreamSubscription<List<PlaylistInvite>>? _subscription;
  String? _listenedUid;

  CollaborationInvitesNotifier(this._service, this._ref) : super(const []) {
    // Watch auth state so invites refresh whenever the signed-in user changes.
    _ref.listen(authServiceProvider, (_, __) => _restart(), fireImmediately: true);
  }

  void _restart() {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == _listenedUid) return; // nothing changed
    _subscription?.cancel();
    _subscription = null;
    _listenedUid = uid;
    if (uid == null) {
      state = const [];
      return;
    }
    _subscription = _service.playlistInvitesStream(uid).listen(
          (items) => state = items,
          onError: (_) => state = const [],
        );
  }

  Future<void> accept(PlaylistInvite invite) async {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await _service.acceptPlaylistInvite(uid, invite);
  }

  Future<void> decline(PlaylistInvite invite) async {
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await _service.declinePlaylistInvite(uid, invite.sharedPlaylistId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final collaborationInvitesProvider =
    StateNotifierProvider<CollaborationInvitesNotifier, List<PlaylistInvite>>(
        (ref) {
  return CollaborationInvitesNotifier(
    ref.watch(firestoreServiceProvider),
    ref,
  );
});

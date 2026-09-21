import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_service.dart';
import 'sync_provider.dart';

class FriendsState {
  final List<Friendship> friendships;
  final List<Friendship> incomingRequests;
  final bool loading;
  final String? error;

  const FriendsState({
    this.friendships = const [],
    this.incomingRequests = const [],
    this.loading = false,
    this.error,
  });

  FriendsState copyWith({
    List<Friendship>? friendships,
    List<Friendship>? incomingRequests,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return FriendsState(
      friendships: friendships ?? this.friendships,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<Friendship> get accepted =>
      friendships.where((item) => item.status == 'accepted').toList();
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final FirestoreService _service;
  StreamSubscription<List<Friendship>>? _friendshipsSubscription;
  StreamSubscription<List<Friendship>>? _requestsSubscription;
  String? _uid;

  FriendsNotifier(this._service) : super(const FriendsState());

  void initForUser(String uid) {
    if (_uid == uid) return;
    reset();
    _uid = uid;
    state = state.copyWith(loading: true);
    if (Platform.isWindows) {
      refresh();
      return;
    }
    _friendshipsSubscription = _service.friendshipsStream(uid).listen(
          (items) => state = state.copyWith(friendships: items, loading: false),
          onError: (Object error, StackTrace _) =>
              state = state.copyWith(loading: false, error: error.toString()),
        );
    _requestsSubscription = _service.incomingFriendRequestsStream(uid).listen(
          (items) => state = state.copyWith(incomingRequests: items),
          onError: (Object error, StackTrace _) =>
              state = state.copyWith(error: error.toString()),
        );
  }

  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final friendships = await _service.getFriendships(uid);
      final requests = await _service.getFriendships(uid, incomingOnly: true);
      state = state.copyWith(
        friendships: friendships,
        incomingRequests: requests,
        loading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<List<PublicProfile>> search(String query) async {
    try {
      return await _service.searchPublicProfiles(query);
    } on FirebaseException catch (error) {
      state = state.copyWith(error: _firebaseError(error));
      return [];
    } catch (_) {
      state = state.copyWith(
          error:
              'Could not search users. Check your connection and try again.');
      return [];
    }
  }

  Future<void> sendRequest(String toUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _run(() => _service.sendFriendRequest(uid, toUid));
  }

  Future<void> accept(Friendship friendship) =>
      _run(() => _service.acceptFriendRequest(friendship.id));

  Future<void> decline(Friendship friendship) =>
      _run(() => _service.declineFriendRequest(friendship.id));

  Future<void> unfriend(Friendship friendship) =>
      _run(() => _service.unfriend(friendship.id));

  Future<void> block(String otherUid) async {
    final uid = _uid;
    if (uid != null) await _run(() => _service.blockUser(uid, otherUid));
  }

  Future<void> unblock(String otherUid) async {
    final uid = _uid;
    if (uid != null) await _run(() => _service.unblockUser(uid, otherUid));
  }

  Future<void> _run(Future<void> Function() action) async {
    state = state.copyWith(clearError: true);
    try {
      await action();
      if (Platform.isWindows) await refresh();
    } on FirestoreFriendException catch (error) {
      state = state.copyWith(error: error.message);
    } on FirebaseException catch (error) {
      state = state.copyWith(error: _firebaseError(error));
    } catch (error) {
      state = state.copyWith(error: 'Could not complete that action: $error');
    }
  }

  String _firebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore denied this action. The stored profile/privacy data does not satisfy the deployed rules. Re-save Privacy on both accounts, then retry.';
      case 'failed-precondition':
        return 'Firestore needs an index or is not ready yet. Deploy the latest rules/indexes and try again.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Firestore is temporarily unavailable. Check your connection and try again.';
      default:
        return 'Firestore error (${error.code}): ${error.message ?? 'unknown error'}';
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void reset() {
    _friendshipsSubscription?.cancel();
    _requestsSubscription?.cancel();
    _friendshipsSubscription = null;
    _requestsSubscription = null;
    _uid = null;
    state = const FriendsState();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier(ref.watch(firestoreServiceProvider));
});

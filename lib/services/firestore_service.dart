// ============================================================
// services/firestore_service.dart
//
// All Firestore reads and writes for Tuneify.
//
// Data model (all under users/{uid}/):
//   profile                  — display name, email, photoURL
//   playlists/{playlistId}   — playlist doc
//   likes/{trackId}          — liked track doc
//   state/playback           — single playback state doc
//   devices/{deviceId}       — device registration doc
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import '../models/song.dart';
import '../models/playlist.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  // ── Root helpers ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _userCol(String uid, String col) =>
      _db.collection('users').doc(uid).collection(col);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid, String sub) =>
      _db.collection('users').doc(uid).collection('state').doc(sub);

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<void> upsertProfile(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoURL': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<PublicProfile?> getPublicProfile(String uid) async {
    final doc = await _db.collection('publicProfiles').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final profile = PublicProfile.fromMap(uid, doc.data()!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friend_profile_$uid', jsonEncode(profile.toMap()));
    return profile;
  }

  Future<PublicProfile?> getCachedPublicProfile(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('friend_profile_$uid');
    if (encoded == null) return null;
    try {
      return PublicProfile.fromMap(
          uid, jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPublicProfile(String uid) async {
    return (await _db.collection('publicProfiles').doc(uid).get()).exists;
  }

  Future<void> createPublicProfile({
    required User user,
    required String username,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (!usernamePattern.hasMatch(normalized)) {
      throw const FirestoreProfileException(
          'Username must be 3-20 characters using lowercase letters, numbers, or _.');
    }

    final profileRef = _db.collection('publicProfiles').doc(user.uid);
    final usernameRef = _db.collection('usernames').doc(normalized);
    final existingUsername = await usernameRef.get();
    if (existingUsername.exists) {
      throw const FirestoreProfileException('That username is already taken.');
    }
    final existingProfile = await profileRef.get();
    if (existingProfile.exists) {
      throw const FirestoreProfileException(
          'Your public profile already exists.');
    }

    // The batch is atomic. Firestore rules enforce that the username
    // reservation does not already exist, so concurrent claims cannot both
    // succeed without using the Windows Firestore transaction channel.
    final batch = _db.batch();
    batch.set(usernameRef, {'uid': user.uid});
    batch.set(profileRef, {
      'username': normalized,
      'usernameLower': normalized,
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'privacy': {
        'showOnlineStatus': true,
        'showActivity': true,
        'allowFriendRequests': true,
      },
    });
    await batch.commit();
  }

  Future<void> updatePrivacy(String uid, Map<String, bool> privacy) async {
    await _db.collection('publicProfiles').doc(uid).update({
      'privacy': privacy,
    });
  }

  Future<void> updatePresence({
    required String uid,
    required String deviceName,
    required bool online,
    required bool showOnlineStatus,
    required bool showActivity,
    required Map<String, dynamic>? activity,
    bool writeActivity = true,
  }) async {
    final data = <String, dynamic>{
      'online': online && showOnlineStatus,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'deviceName': deviceName,
    };
    if (writeActivity || !showActivity || !showOnlineStatus) {
      data['activity'] = showActivity && showOnlineStatus ? activity : null;
    }
    await _db.collection('presence').doc(uid).set(data, SetOptions(merge: true));
  }

  Stream<PresenceInfo?> presenceStream(String uid) {
    return _db.collection('presence').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PresenceInfo.fromMap(doc.data()!);
    });
  }

  String friendshipId(String a, String b) {
    final members = [a, b]..sort();
    return '${members[0]}_${members[1]}';
  }

  Future<List<PublicProfile>> searchPublicProfiles(String query,
      {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final snapshot = await _db
        .collection('publicProfiles')
        .where('usernameLower', isGreaterThanOrEqualTo: normalized)
        .where('usernameLower', isLessThan: '$normalized\uf8ff')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => PublicProfile.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Friendship>> friendshipsStream(String uid) {
    return _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final result = <Friendship>[];
      for (final doc in snapshot.docs) {
        final friendship = Friendship.fromMap(doc.id, doc.data());
        final otherUid =
            friendship.members.firstWhere((member) => member != uid);
        final profile = await getCachedPublicProfile(otherUid) ??
            await getPublicProfile(otherUid);
        result.add(friendship.copyWith(otherUid: otherUid, profile: profile));
      }

      return result;
    });
  }

  Future<List<Friendship>> getFriendships(String uid,
      {bool incomingOnly = false}) async {
    final snapshot = await _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .get();
    final result = <Friendship>[];
    for (final doc in snapshot.docs) {
      final friendship = Friendship.fromMap(doc.id, doc.data());
      if (incomingOnly &&
          (friendship.status != 'pending' || friendship.requestedBy == uid)) {
        continue;
      }
      final otherUid = friendship.members.firstWhere((member) => member != uid);
      final profile = await getCachedPublicProfile(otherUid) ??
          await getPublicProfile(otherUid);
      result.add(friendship.copyWith(otherUid: otherUid, profile: profile));
    }
    return result;
  }

  Stream<List<Friendship>> incomingFriendRequestsStream(String uid) {
    return _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final result = <Friendship>[];
      for (final doc in snapshot.docs) {
        final friendship = Friendship.fromMap(doc.id, doc.data());
        if (friendship.status != 'pending' || friendship.requestedBy == uid) {
          continue;
        }
        final otherUid =
            friendship.members.firstWhere((member) => member != uid);
        final profile = await getCachedPublicProfile(otherUid) ??
            await getPublicProfile(otherUid);
        result.add(friendship.copyWith(otherUid: otherUid, profile: profile));
      }
      return result;
    });
  }

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    if (fromUid == toUid) {
      throw const FirestoreFriendException('You cannot add yourself.');
    }
    final target = await getPublicProfile(toUid);
    if (target == null) {
      throw const FirestoreFriendException('User not found.');
    }
    final sender = await getPublicProfile(fromUid);
    if (sender == null) {
      throw const FirestoreFriendException(
          'Your profile is not ready yet. Sign out and sign in again to finish setup.');
    }
    if (!target.privacy.containsKey('allowFriendRequests')) {
      throw const FirestoreFriendException(
          'The recipient has an incomplete privacy profile. They must open Privacy, save the settings, then try again.');
    }
    if (!target.privacy['allowFriendRequests']!) {
      throw const FirestoreFriendException(
          'This user is not accepting friend requests.');
    }
    final ref = _db.collection('friendships').doc(friendshipId(fromUid, toUid));
    final existing = await ref.get();
    if (existing.exists) {
      final status = existing.data()?['status'];
      throw FirestoreFriendException(status == 'accepted'
          ? 'You are already friends.'
          : 'Request already sent.');
    }
    await ref.set({
      'members': [fromUid, toUid]..sort(),
      'status': 'pending',
      'requestedBy': fromUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineFriendRequest(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).delete();
  }

  Future<void> unfriend(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).delete();
  }

  Future<void> blockUser(String uid, String blockedUid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .set({'blockedAt': FieldValue.serverTimestamp()});
    await _db
        .collection('friendships')
        .doc(friendshipId(uid, blockedUid))
        .delete();
  }

  Future<void> unblockUser(String uid, String blockedUid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .delete();
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  Stream<List<Playlist>> playlistsStream(String uid) {
    return _userCol(uid, 'playlists')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _docToPlaylist(d)).toList());
  }

  Future<List<Playlist>> getPlaylists(String uid) async {
    final snap = await _userCol(uid, 'playlists')
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs.map((d) => _docToPlaylist(d)).toList();
  }

  Future<List<Playlist>> getFriendPlaylists(String uid) async {
    final publicSnap = await _userCol(uid, 'playlists')
        .where('visibility', isEqualTo: 'public')
        .get();
    final friendsSnap = await _userCol(uid, 'playlists')
        .where('visibility', isEqualTo: 'friends')
        .get();
    final playlists = [
      ...publicSnap.docs.map(_docToPlaylist),
      ...friendsSnap.docs.map(_docToPlaylist),
    ];
    playlists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return playlists;
  }

  Future<void> ensurePlaylistVisibilityDefaults(String uid) async {
    final snap = await _userCol(uid, 'playlists').get();
    final batch = _db.batch();
    var changed = false;
    for (final doc in snap.docs) {
      if (!doc.data().containsKey('visibility')) {
        batch.update(doc.reference, {
          'visibility': 'private',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        changed = true;
      }
    }
    if (changed) await batch.commit();
  }

  Future<String> createPlaylist(
    String uid,
    String name, {
    String? description,
    String visibility = 'private',
  }) async {
    if (!{'private', 'friends', 'public'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    final ref = _userCol(uid, 'playlists').doc();
    await ref.set({
      'name': name,
      'description': description ?? '',
      'coverUrl': '',
      'trackIds': <String>[],
      'tracks': <Map>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'visibility': visibility,
    });
    return ref.id;
  }

  Future<String> createPlaylistWithSongs(
    String uid,
    String name,
    List<Song> songs, {
    String? description,
  }) async {
    final ref = _userCol(uid, 'playlists').doc();
    await ref.set({
      'name': name,
      'description': description ?? '',
      'coverUrl': songs.isEmpty ? '' : songs.first.thumbnailUrl,
      'trackIds': songs.map((song) => song.id).toList(),
      'tracks': songs.map(_songToMap).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'visibility': 'private',
    });
    return ref.id;
  }

  Future<void> renamePlaylist(
      String uid, String playlistId, String name) async {
    await _userCol(uid, 'playlists').doc(playlistId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPlaylistVisibility(
      String uid, String playlistId, String visibility) async {
    if (!{'private', 'friends', 'public'}.contains(visibility)) {
      throw ArgumentError.value(visibility, 'visibility');
    }
    await _userCol(uid, 'playlists').doc(playlistId).update({
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlaylist(String uid, String playlistId) async {
    await _userCol(uid, 'playlists').doc(playlistId).delete();
  }

  Future<void> addSongToPlaylist(
      String uid, String playlistId, Song song) async {
    final ref = _userCol(uid, 'playlists').doc(playlistId);
    await ref.update({
      'trackIds': FieldValue.arrayUnion([song.id]),
      'tracks': FieldValue.arrayUnion([_songToMap(song)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSongFromPlaylist(
      String uid, String playlistId, String songId) async {
    final ref = _userCol(uid, 'playlists').doc(playlistId);
    // arrayRemove on tracks requires the exact map — read first then update
    final doc = await ref.get();
    if (!doc.exists) return;
    final tracks = List<Map>.from(doc.data()?['tracks'] ?? []);
    tracks.removeWhere((t) => t['id'] == songId);
    await ref.update({
      'trackIds': FieldValue.arrayRemove([songId]),
      'tracks': tracks,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Likes ─────────────────────────────────────────────────────────────────

  Stream<List<Song>> likesStream(String uid) {
    return _userCol(uid, 'likes')
        .orderBy('likedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _docToSong(d.data())).toList());
  }

  Future<List<Song>> getLikes(String uid) async {
    final snap =
        await _userCol(uid, 'likes').orderBy('likedAt', descending: true).get();
    return snap.docs.map((d) => _docToSong(d.data())).toList();
  }

  Future<void> likeSong(String uid, Song song) async {
    await _userCol(uid, 'likes').doc(song.id).set({
      ..._songToMap(song),
      'likedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlikeSong(String uid, String songId) async {
    await _userCol(uid, 'likes').doc(songId).delete();
  }

  // ── Remote command (simple remote-control sync) ───────────────────────────

  /// Write a remote command doc. Called by SyncService.sendCommand().
  /// Caps the queue at 200 items to stay well under 1 MB doc limit.
  Future<void> writeRemoteCommand({
    required String uid,
    required String deviceId,
    required String deviceName,
    required String
        command, // 'play' | 'pause' | 'next' | 'prev' | 'playSong' | 'none'
    required Song? currentSong,
    required List<Song> queue,
    required int queueIndex,
    required int positionMs,
    required bool isPlaying,
  }) async {
    final cappedQueue = queue.take(200).toList();
    await _userDoc(uid, 'remoteCommand').set({
      'command': command,
      'currentTrack': currentSong != null ? _songToMap(currentSong) : null,
      'queue': cappedQueue.map(_songToMap).toList(),
      'queueIndex': queueIndex,
      'positionMs': positionMs,
      'isPlaying': isPlaying,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of the remote command doc as a raw map.
  /// SyncService parses this into a RemoteCommandDoc.
  Stream<Map<String, dynamic>?> remoteCommandStream(String uid) {
    return _userDoc(uid, 'remoteCommand').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return _expandRemoteCommand(doc.data()!);
    });
  }

  /// One-shot read of the last remote command doc (used on login to restore queue).
  Future<Map<String, dynamic>?> getLastRemoteCommand(String uid) async {
    final doc = await _userDoc(uid, 'remoteCommand').get();
    if (!doc.exists || doc.data() == null) return null;
    return _expandRemoteCommand(doc.data()!);
  }

  /// Converts Firestore data into a plain map with Song objects resolved.
  Map<String, dynamic> _expandRemoteCommand(Map<String, dynamic> d) {
    final trackMap = d['currentTrack'] as Map<String, dynamic>?;
    final queueList = (d['queue'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return {
      'command': d['command'] as String? ?? 'none',
      'currentSong': trackMap != null ? _docToSong(trackMap) : null,
      'queue': queueList.map(_docToSong).toList(),
      'queueIndex': (d['queueIndex'] as num?)?.toInt() ?? 0,
      'positionMs': (d['positionMs'] as num?)?.toInt() ?? 0,
      'isPlaying': d['isPlaying'] as bool? ?? false,
      'deviceId': d['deviceId'] as String? ?? '',
      'deviceName': d['deviceName'] as String? ?? 'Unknown Device',
    };
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  Future<void> registerDevice(
      String uid, String deviceId, String deviceName, String platform) async {
    await _userCol(uid, 'devices').doc(deviceId).set({
      'name': deviceName,
      'platform': platform,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregisterDevice(String uid, String deviceId) async {
    await _userCol(uid, 'devices').doc(deviceId).delete();
  }

  /// Remove device registrations that have not sent a heartbeat recently.
  Future<void> removeStaleDevices(String uid,
      {required String keepDeviceId,
      Duration maxAge = const Duration(minutes: 2)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final snap = await _userCol(uid, 'devices').get();
    final deletions = <Future<void>>[];

    for (final doc in snap.docs) {
      if (doc.id == keepDeviceId) continue;
      final value = doc.data()['lastActiveAt'];
      final lastActiveAt = value is Timestamp
          ? value.toDate()
          : value is DateTime
              ? value
              : null;
      if (lastActiveAt == null || lastActiveAt.isBefore(cutoff)) {
        deletions.add(doc.reference.delete());
      }
    }
    await Future.wait(deletions);
  }

  // ── Active device ─────────────────────────────────────────────────────────

  /// Claim this device as the active playback device.
  /// Writes {activeDeviceId, activeDeviceName, activeAt} to users/{uid}/state/activeDevice.
  Future<void> claimActiveDevice(
      String uid, String deviceId, String deviceName) async {
    await _userDoc(uid, 'activeDevice').set({
      'activeDeviceId': deviceId,
      'activeDeviceName': deviceName,
      'activeAt': FieldValue.serverTimestamp(),
    });
  }

  /// Release the active device claim (only if this device is currently active).
  Future<void> releaseActiveDevice(String uid, String deviceId) async {
    final doc = await _userDoc(uid, 'activeDevice').get();
    if (!doc.exists) return;
    final current = doc.data()?['activeDeviceId'] as String?;
    if (current == deviceId) {
      await _userDoc(uid, 'activeDevice').delete();
    }
  }

  /// Live stream of the active device doc. Emits null when no device is active.
  Stream<ActiveDeviceDoc?> activeDeviceStream(String uid) {
    return _userDoc(uid, 'activeDevice').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final d = doc.data()!;
      return ActiveDeviceDoc(
        deviceId: d['activeDeviceId'] as String? ?? '',
        deviceName: d['activeDeviceName'] as String? ?? 'Unknown Device',
      );
    });
  }

  /// One-shot read of the active device.
  Future<ActiveDeviceDoc?> getActiveDevice(String uid) async {
    final doc = await _userDoc(uid, 'activeDevice').get();
    if (!doc.exists || doc.data() == null) return null;
    final d = doc.data()!;
    return ActiveDeviceDoc(
      deviceId: d['activeDeviceId'] as String? ?? '',
      deviceName: d['activeDeviceName'] as String? ?? 'Unknown Device',
    );
  }

  /// Stream of all registered devices (users/{uid}/devices collection).
  /// Each device doc has: name, platform, lastActiveAt.
  Stream<List<DeviceInfo>> devicesStream(String uid) {
    final controller = StreamController<List<DeviceInfo>>();
    Timer? refreshTimer;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;

    List<DeviceInfo> parse(QuerySnapshot<Map<String, dynamic>> snap) {
      final devices = snap.docs.map((d) {
        final lastActive = d.data()['lastActiveAt'];
        final lastActiveAt = lastActive is Timestamp
            ? lastActive.toDate()
            : lastActive is DateTime
                ? lastActive
                : null;
        return DeviceInfo(
          deviceId: d.id,
          name: d.data()['name'] as String? ?? 'Unknown',
          platform: d.data()['platform'] as String? ?? 'unknown',
          lastActiveAt: lastActiveAt,
        );
      });

      return devices
          .where((device) =>
              device.lastActiveAt != null &&
              DateTime.now().difference(device.lastActiveAt!) <
                  const Duration(seconds: 75))
          .toList();
    }

    Future<void> refresh() async {
      try {
        controller.add(parse(await _userCol(uid, 'devices').get()));
      } catch (_) {
        // The live snapshot subscription remains the source of truth.
      }
    }

    subscription = _userCol(uid, 'devices').snapshots().listen((snap) {
      controller.add(parse(snap));
    });
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
    controller.onCancel = () async {
      refreshTimer?.cancel();
      await subscription?.cancel();
    };
    return controller.stream;
  }

  // ── Delete user data ──────────────────────────────────────────────────────
  //
  // Deletes all subcollections. Called before deleting the Auth account.

  Future<void> deleteUserData(String uid) async {
    final futures = <Future>[];

    for (final col in ['playlists', 'likes', 'devices']) {
      final snap = await _userCol(uid, col).get();
      for (final doc in snap.docs) {
        futures.add(doc.reference.delete());
      }
    }
    // Delete the state/remoteCommand doc
    futures.add(_userDoc(uid, 'remoteCommand').delete().catchError((_) {}));
    // Delete the state/activeDevice doc
    futures.add(_userDoc(uid, 'activeDevice').delete().catchError((_) {}));

    // Delete the root user doc
    futures.add(_db.collection('users').doc(uid).delete().catchError((_) {}));

    await Future.wait(futures);
  }

  // ── Migration: upload local Hive data ─────────────────────────────────────

  Future<void> migrateLikedSongs(String uid, List<Song> songs) async {
    final batch = _db.batch();
    for (final song in songs) {
      final ref = _userCol(uid, 'likes').doc(song.id);
      batch.set(
          ref,
          {
            ..._songToMap(song),
            'likedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> migratePlaylist(String uid, Playlist playlist) async {
    final ref = _userCol(uid, 'playlists').doc();
    await ref.set({
      'name': playlist.name,
      'description': playlist.description ?? '',
      'coverUrl': '',
      'trackIds': playlist.songs.map((s) => s.id).toList(),
      'tracks': playlist.songs.map(_songToMap).toList(),
      'createdAt': Timestamp.fromDate(playlist.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'visibility': playlist.visibility,
    });
  }

  // ── Converters ────────────────────────────────────────────────────────────

  Map<String, dynamic> _songToMap(Song s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.channelName,
        'coverUrl': s.thumbnailUrl,
        'durationMs': s.duration.inMilliseconds,
      };

  Song _docToSong(Map<String, dynamic> d) => Song(
        id: d['id'] as String? ?? '',
        title: d['title'] as String? ?? '',
        channelName: d['artist'] as String? ?? '',
        thumbnailUrl: d['coverUrl'] as String? ?? '',
        duration:
            Duration(milliseconds: (d['durationMs'] as num?)?.toInt() ?? 0),
      );

  Playlist _docToPlaylist(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final tracks = (d['tracks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final playlist = Playlist(
      name: d['name'] as String? ?? 'Untitled',
      description: d['description'] as String?,
      visibility: d['visibility'] as String? ?? 'private',
      songs: tracks.map(_docToSong).toList(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
    playlistFirestoreIds[playlist] = doc.id;
    return playlist;
  }
}

class FirestoreProfileException implements Exception {
  final String message;
  const FirestoreProfileException(this.message);
  @override
  String toString() => message;
}

class PublicProfile {
  final String uid;
  final String username;
  final String usernameLower;
  final String displayName;
  final String photoURL;
  final Map<String, bool> privacy;

  const PublicProfile({
    required this.uid,
    required this.username,
    required this.usernameLower,
    required this.displayName,
    required this.photoURL,
    required this.privacy,
  });

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> data) {
    final rawPrivacy = (data['privacy'] as Map?)?.cast<String, dynamic>() ?? {};
    return PublicProfile(
      uid: uid,
      username: data['username'] as String? ?? '',
      usernameLower: data['usernameLower'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoURL: data['photoURL'] as String? ?? '',
      privacy: {
        'showOnlineStatus': rawPrivacy['showOnlineStatus'] as bool? ?? true,
        'showActivity': rawPrivacy['showActivity'] as bool? ?? true,
        'allowFriendRequests':
            rawPrivacy['allowFriendRequests'] as bool? ?? true,
      },
    );
  }

  Map<String, dynamic> toMap() => {
        'username': username,
        'usernameLower': usernameLower,
        'displayName': displayName,
        'photoURL': photoURL,
        'privacy': privacy,
      };
}

class FirestoreFriendException implements Exception {
  final String message;
  const FirestoreFriendException(this.message);
  @override
  String toString() => message;
}

class PresenceInfo {
  final bool online;
  final DateTime? lastActiveAt;
  final String deviceName;
  final Map<String, dynamic>? activity;

  const PresenceInfo({
    required this.online,
    required this.lastActiveAt,
    required this.deviceName,
    required this.activity,
  });

  factory PresenceInfo.fromMap(Map<String, dynamic> data) {
    final timestamp = data['lastActiveAt'];
    final rawActivity = data['activity'];
    return PresenceInfo(
      online: data['online'] as bool? ?? false,
      lastActiveAt:
          timestamp is Timestamp ? timestamp.toDate() : null,
      deviceName: data['deviceName'] as String? ?? 'Unknown device',
      activity: rawActivity is Map
          ? rawActivity.cast<String, dynamic>()
          : null,
    );
  }

  bool get isOnline =>
      online &&
      lastActiveAt != null &&
      DateTime.now().difference(lastActiveAt!) <
          const Duration(seconds: 150);
}

class Friendship {
  final String id;
  final List<String> members;
  final String status;
  final String requestedBy;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final String? otherUid;
  final PublicProfile? profile;

  const Friendship({
    required this.id,
    required this.members,
    required this.status,
    required this.requestedBy,
    this.createdAt,
    this.acceptedAt,
    this.otherUid,
    this.profile,
  });

  factory Friendship.fromMap(String id, Map<String, dynamic> data) {
    DateTime? timestamp(dynamic value) =>
        value is Timestamp ? value.toDate() : null;
    return Friendship(
      id: id,
      members: (data['members'] as List?)?.cast<String>() ?? const [],
      status: data['status'] as String? ?? 'pending',
      requestedBy: data['requestedBy'] as String? ?? '',
      createdAt: timestamp(data['createdAt']),
      acceptedAt: timestamp(data['acceptedAt']),
    );
  }

  Friendship copyWith({String? otherUid, PublicProfile? profile}) {
    return Friendship(
      id: id,
      members: members,
      status: status,
      requestedBy: requestedBy,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      otherUid: otherUid ?? this.otherUid,
      profile: profile ?? this.profile,
    );
  }
}

// Expando to attach a Firestore document ID to a Playlist instance without
// touching the Hive-annotated model class.
final Expando<String> playlistFirestoreIds = Expando<String>('firestoreId');

extension PlaylistFirestoreExt on Playlist {
  /// The Firestore document ID for this playlist (null for local-only playlists).
  String? get firestoreId => playlistFirestoreIds[this];
}

// (RemoteCommandDoc is defined in sync_service.dart)

/// Identifies which device currently owns playback.
class ActiveDeviceDoc {
  final String deviceId;
  final String deviceName;
  const ActiveDeviceDoc({required this.deviceId, required this.deviceName});
}

/// A registered device entry from the devices subcollection.
class DeviceInfo {
  final String deviceId;
  final String name;
  final String platform;
  final DateTime? lastActiveAt;

  const DeviceInfo({
    required this.deviceId,
    required this.name,
    required this.platform,
    this.lastActiveAt,
  });
}

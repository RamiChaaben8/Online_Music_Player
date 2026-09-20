// ============================================================
// services/sync_service.dart
//
// Simple remote-control sync + active-device ownership.
//
// Active device model (Spotify-style)
// ─────────────────────────────────────────────────────────────
// • Exactly one device is "active" at a time — it owns playback,
//   loads audio, and executes transport commands.
// • All other devices are "passive" — they show the device picker
//   and can send commands (play/pause/next/prev) to the active
//   device via Firestore, but they do NOT load audio.
// • A passive device becomes active by tapping itself in the
//   device picker (calls claimAsActiveDevice()).
// • The previous active device becomes passive immediately.
//
// What syncs
// ─────────────────────────────────────────────────────────────
// • play / pause / next / prev / playSong commands
// • Queue + current song (so every device shows the same queue)
// • activeDeviceId (who owns playback right now)
// • Device name (for the picker list)
//
// What does NOT sync
// ─────────────────────────────────────────────────────────────
// • Playback position and play state
// • Volume — local only
// ============================================================

import 'dart:async';

import '../models/song.dart';
import 'firestore_service.dart';
import 'device_id_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// ── Types ────────────────────────────────────────────────────────────────────

/// The command written to Firestore by the acting device.
enum RemoteCommand { play, pause, next, prev, playSong, seek, none }

/// Parsed remote-command document from Firestore.
class RemoteCommandDoc {
  final RemoteCommand command;
  final String deviceId;
  final String deviceName;
  final Song? currentSong;
  final List<Song> queue;
  final int queueIndex;
  final int positionMs;
  final bool isPlaying;

  const RemoteCommandDoc({
    required this.command,
    required this.deviceId,
    required this.deviceName,
    this.currentSong,
    required this.queue,
    required this.queueIndex,
    required this.positionMs,
    required this.isPlaying,
  });

  /// Parse the raw map returned by FirestoreService.
  factory RemoteCommandDoc.fromMap(Map<String, dynamic> m) {
    final cmdStr = m['command'] as String? ?? 'none';
    final command = RemoteCommand.values.firstWhere(
      (c) => c.name == cmdStr,
      orElse: () => RemoteCommand.none,
    );
    return RemoteCommandDoc(
      command: command,
      deviceId: m['deviceId'] as String? ?? '',
      deviceName: m['deviceName'] as String? ?? 'Unknown Device',
      currentSong: m['currentSong'] as Song?,
      queue: (m['queue'] as List?)?.cast<Song>() ?? const [],
      queueIndex: m['queueIndex'] as int? ?? 0,
      positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
      isPlaying: m['isPlaying'] as bool? ?? false,
    );
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class SyncService {
  final FirestoreService _fs;

  SyncService(this._fs);

  String? _uid;
  String? _deviceId;
  String? _deviceName;

  StreamSubscription? _cmdSub;
  StreamSubscription? _activeDeviceSub;
  Timer? _heartbeatTimer;

  // Broadcast stream of remote commands — PlayerNotifier listens.
  final StreamController<RemoteCommandDoc> _cmdController =
      StreamController<RemoteCommandDoc>.broadcast();
  Stream<RemoteCommandDoc> get remoteCommandStream => _cmdController.stream;

  // Broadcast stream of active device changes — PlayerNotifier + UI listens.
  final StreamController<ActiveDeviceDoc?> _activeDeviceController =
      StreamController<ActiveDeviceDoc?>.broadcast();
  Stream<ActiveDeviceDoc?> get activeDeviceStream =>
      _activeDeviceController.stream;

  /// Whether this device is currently the active playback device.
  bool _isActive = false;
  bool get isActive => _isActive;

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    _uid = uid;
    _deviceId = await deviceIdService.getDeviceId();
    _deviceName = await deviceIdService.getDeviceName();
    final platform = _detectPlatform();

    await _fs.registerDevice(uid, _deviceId!, _deviceName!, platform);
    await _fs.removeStaleDevices(uid, keepDeviceId: _deviceId!);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fs
          .registerDevice(uid, _deviceId!, _deviceName!, platform)
          .catchError((_) {});
    });

    // Subscribe to remote commands.
    _cmdSub?.cancel();
    _cmdSub = _fs.remoteCommandStream(uid).listen(_onRawCmd);

    // Subscribe to active device changes.
    _activeDeviceSub?.cancel();
    _activeDeviceSub = _fs.activeDeviceStream(uid).listen(_onActiveDevice);

    // Determine initial active state.
    final current = await _fs.getActiveDevice(uid);
    _isActive = current?.deviceId == _deviceId;
    _activeDeviceController.add(current);
  }

  void dispose() {
    _cmdSub?.cancel();
    _cmdSub = null;
    _activeDeviceSub?.cancel();
    _activeDeviceSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isActive = false;
    _uid = null;
    _deviceId = null;
    // Do NOT close the broadcast controllers — listeners survive logout/re-login.
  }

  void _onRawCmd(Map<String, dynamic>? raw) {
    if (raw == null) return;
    if (_deviceId == null) return;
    final doc = RemoteCommandDoc.fromMap(raw);
    // Ignore commands we sent ourselves.
    if (doc.deviceId == _deviceId) return;
    // Emit to ALL devices (active AND passive).
    // Active device will EXECUTE; passive device will OBSERVE (UI sync only).
    _cmdController.add(doc);
  }

  void _onActiveDevice(ActiveDeviceDoc? doc) {
    _isActive = doc?.deviceId == _deviceId;
    _activeDeviceController.add(doc);
  }

  // ── Active device claim ───────────────────────────────────────────────────

  /// Make this device the active playback device.
  Future<void> claimAsActiveDevice() async {
    if (_uid == null || _deviceId == null) return;
    await _fs.claimActiveDevice(_uid!, _deviceId!, _deviceName ?? 'Unknown');
    _isActive = true;
  }

  /// Release this device's active claim (on logout / app close).
  Future<void> releaseIfActive() async {
    if (_uid == null || _deviceId == null) return;
    await _fs.releaseActiveDevice(_uid!, _deviceId!);
    _isActive = false;
  }

  /// Transfer active playback to another device by claiming it as active.
  /// This device becomes passive immediately.
  Future<void> transferToDevice(
      String targetDeviceId, String targetDeviceName) async {
    if (_uid == null) return;
    await _fs.claimActiveDevice(_uid!, targetDeviceId, targetDeviceName);
    _isActive = false;
  }

  // ── Write API ─────────────────────────────────────────────────────────────

  Future<void> sendCommand({
    required RemoteCommand command,
    required Song? currentSong,
    required List<Song> queue,
    required int queueIndex,
    required int positionMs,
    required bool isPlaying,
  }) async {
    if (_uid == null || _deviceId == null) return;
    await _fs.writeRemoteCommand(
      uid: _uid!,
      deviceId: _deviceId!,
      deviceName: _deviceName ?? 'Unknown',
      command: command.name,
      currentSong: currentSong,
      queue: queue,
      queueIndex: queueIndex,
      positionMs: positionMs,
      isPlaying: isPlaying,
    );
  }

  /// Persist the current queue and track without asking another device to
  /// perform an action. Used during app backgrounding/shutdown.
  Future<void> savePlaybackState({
    required Song? currentSong,
    required List<Song> queue,
    required int queueIndex,
    required int positionMs,
    required bool isPlaying,
  }) {
    return sendCommand(
      command: RemoteCommand.none,
      currentSong: currentSong,
      queue: queue,
      queueIndex: queueIndex,
      positionMs: positionMs,
      isPlaying: isPlaying,
    );
  }

  // ── Restore on login ──────────────────────────────────────────────────────

  /// Returns the last saved queue/song for session restore.
  Future<RemoteCommandDoc?> getLastState() async {
    if (_uid == null) return null;
    final raw = await _fs.getLastRemoteCommand(_uid!);
    if (raw == null) return null;
    return RemoteCommandDoc.fromMap(raw);
  }

  // ── Device list stream ────────────────────────────────────────────────────

  Stream<List<DeviceInfo>> devicesStream() {
    if (_uid == null) return const Stream.empty();
    return _fs.devicesStream(_uid!);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}

// ============================================================
// services/device_id_service.dart
//
// Generates and persists a stable UUID for this device/install.
// Stored in SharedPreferences so it survives app restarts but
// is cleared on uninstall (which is correct — new install = new device).
//
// Also provides a human-readable device name used in the
// "Playing on [device]" cross-device banner.
// ============================================================

import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DeviceIdService {
  static const _kDeviceIdKey = 'tuneify_device_id';
  static const _kDeviceNameKey = 'tuneify_device_name';

  String? _deviceId;
  String? _deviceName;

  /// Returns the stable deviceId, generating one on first call.
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null) {
      id = _generateUuid();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  /// Returns a human-readable name for this device.
  Future<String> getDeviceName() async {
    if (_deviceName != null) return _deviceName!;
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString(_kDeviceNameKey);
    if (name == null) {
      name = _defaultName();
      await prefs.setString(_kDeviceNameKey, name);
    }
    _deviceName = name;
    return name;
  }

  String _defaultName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isLinux) return 'Linux PC';
    return 'Unknown Device';
  }

  /// Simple UUID v4 generator (no external dependency needed).
  String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

/// Singleton provider-style accessor used by services that need the device ID
/// before Riverpod providers are available (e.g. SyncService constructor).
final deviceIdService = DeviceIdService();

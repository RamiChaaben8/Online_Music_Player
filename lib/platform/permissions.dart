// ============================================================
// platform/permissions.dart
//
// The permission_handler package ships a Windows plugin that uses
// deprecated MSVC coroutine headers and fails to compile on VS2022+.
//
// Strategy: the stub is always exported at the Dart level.
// The mobile file imports permission_handler and is only reached
// via a runtime Platform.isAndroid check inside it, but we still
// need the Windows *native plugin* excluded.
//
// The real exclusion happens because permission_mobile.dart is NOT
// imported here — the stub is always used at the Dart level.
// On Android, app.dart calls requestStoragePermission() which is
// the stub's no-op... so we need a different split.
//
// Correct split: use dart.library.io to separate web from native,
// then inside permission_mobile.dart gate on Platform.isAndroid.
// The Windows native plugin is excluded by NOT listing it in
// windows/flutter/generated_plugins.cmake — which flutter tool
// does automatically because permission_handler has no Windows
// ffigen support in its pubspec platforms map.
// ============================================================

// Default: stub (web and any platform that doesn't override)
export 'permission_stub.dart'
    // On dart:io platforms (mobile + desktop), use the mobile file
    // which internally checks Platform.isAndroid at runtime.
    if (dart.library.io) 'permission_mobile.dart';

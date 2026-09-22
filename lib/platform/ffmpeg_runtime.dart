// lib/platform/ffmpeg_runtime.dart
//
// Runtime dispatcher for MP3 conversion (not used for downloads — downloads
// are saved as .mp4 directly). Kept for future use or playlist export.
// On Android → uses ffmpeg_kit_flutter_new_audio (bundled native lib).
// On Windows / other → calls system ffmpeg.exe via Process.run.

import 'dart:io';

import 'ffmpeg_mobile.dart' as mobile;
import 'ffmpeg_stub.dart' as stub;

Future<void> convertToMp3(String inputPath, String outputPath) {
  if (Platform.isAndroid) {
    return mobile.convertToMp3(inputPath, outputPath);
  }
  return stub.convertToMp3(inputPath, outputPath);
}

Future<void> downloadStreamOnAndroid(
  String url,
  String outputPath,
  int totalDurationMs, {
  void Function(double progress)? onProgress,
  bool Function()? isCancelled,
}) {
  if (Platform.isAndroid) {
    return mobile.downloadStream(
      url,
      outputPath,
      totalDurationMs,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
  throw UnsupportedError('downloadStreamOnAndroid is only for Android');
}

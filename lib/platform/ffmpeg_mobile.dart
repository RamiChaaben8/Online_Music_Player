// lib/platform/ffmpeg_mobile.dart
//
// Android FFmpeg wrapper.
// Uses ffmpeg_kit_flutter_new_audio which bundles libffmpeg.so on Android.

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

Future<void> convertToMp3(String inputPath, String outputPath) async {
  // Single-quote paths and escape any embedded single quotes.
  String q(String v) => "'${v.replaceAll("'", "'\\''")}'" ;

  final session = await FFmpegKit.execute(
    '-y -i ${q(inputPath)} -vn -codec:a libmp3lame -q:a 2 ${q(outputPath)}',
  );

  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final output = await session.getOutput();
    throw Exception(
      'ffmpeg_kit conversion failed'
      '${output == null ? '' : ': $output'}',
    );
  }
}

Future<void> downloadStream(
  String url,
  String outputPath,
  int totalDurationMs, {
  void Function(double progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  String q(String v) => "'${v.replaceAll("'", "'\\''")}'";

  FFmpegKitConfig.enableStatisticsCallback((stats) {
    if (isCancelled?.call() == true) {
      FFmpegKit.cancel();
      return;
    }
    final ms = stats.getTime();
    if (ms > 0 && totalDurationMs > 0) {
      // Scale progress up to 0.99
      final p = (ms / totalDurationMs).clamp(0.0, 1.0) * 0.99;
      onProgress?.call(p);
    }
  });

  // -c copy just muxes the stream directly to .mp4 without re-encoding
  final session = await FFmpegKit.execute(
    '-y -i ${q(url)} -c copy ${q(outputPath)}',
  );

  FFmpegKitConfig.enableStatisticsCallback(null);

  if (isCancelled?.call() == true) {
    throw Exception('Cancelled');
  }

  final returnCode = await session.getReturnCode();
  if (!ReturnCode.isSuccess(returnCode)) {
    final output = await session.getOutput();
    throw Exception(
      'ffmpeg_kit download failed'
      '${output == null ? '' : ': $output'}',
    );
  }
}

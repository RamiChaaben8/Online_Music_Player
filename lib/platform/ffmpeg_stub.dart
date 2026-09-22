// lib/platform/ffmpeg_stub.dart
//
// Windows / desktop FFmpeg wrapper (not used for downloads — downloads are
// saved as .mp4 directly). Kept for future use or playlist export.
// Calls the system `ffmpeg` executable via Process.run.

import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> convertToMp3(String inputPath, String outputPath) async {
  final candidates = <String>[
    'ffmpeg',
    r'C:\ffmpeg\bin\ffmpeg.exe',
    r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
    r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
  ];

  var ffmpegExe = await _findFfmpeg(candidates);
  ffmpegExe ??= await _downloadFfmpeg();

  if (ffmpegExe == null) {
    throw Exception(
      'Unable to prepare the Windows MP3 converter. '
      'Check your internet connection and try again.',
    );
  }

  final result = await Process.run(
    ffmpegExe,
    [
      '-y',
      '-i', inputPath,
      '-vn',
      '-codec:a', 'libmp3lame',
      '-q:a', '2',
      outputPath,
    ],
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw Exception(
        'ffmpeg conversion failed (exit ${result.exitCode}): ${result.stderr}');
  }
}

Future<String?> _findFfmpeg(List<String> candidates) async {
  for (final candidate in candidates) {
    try {
      final result = await Process.run(candidate, ['-version'],
          runInShell: true);
      if (result.exitCode == 0) return candidate;
    } catch (_) {}
  }
  return null;
}

Future<String?> _downloadFfmpeg() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory('${support.path}\\ffmpeg');
  final executable = File('${root.path}\\bin\\ffmpeg.exe');
  if (await executable.exists()) return executable.path;

  await root.create(recursive: true);
  final archive = File('${support.path}\\ffmpeg-essentials.zip');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'));
    final response = await request.close().timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) return null;
    await response.pipe(archive.openWrite());
  } finally {
    client.close(force: true);
  }

  final escapedArchive = archive.path.replaceAll("'", "''");
  final escapedRoot = root.path.replaceAll("'", "''");
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    "Expand-Archive -LiteralPath '$escapedArchive' "
        "-DestinationPath '$escapedRoot' -Force",
  ]);
  await archive.delete().catchError((_) => archive);
  if (result.exitCode != 0) return null;

  await for (final entity in root.list(recursive: true)) {
    if (entity is File &&
        entity.path.toLowerCase().endsWith('\\bin\\ffmpeg.exe')) {
      return entity.path;
    }
  }
  return null;
}

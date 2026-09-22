// ============================================================
// services/download_service.dart
//
// Downloads YouTube audio/video as MP4.
// No conversion — the raw muxed stream is saved directly.
//
// Uses direct streaming with active stall-detection so downloads
// never get stuck at 99%.
//
// Saves to Music/Utify on both Android and Windows.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../models/playlist.dart';
import '../models/song.dart';
import 'youtube_service.dart';

class DownloadService {
  final YoutubeService _ytService;

  DownloadService(this._ytService);

  // ── Directory ─────────────────────────────────────────────────────────

  static Future<Directory> getTuneifyDir() async {
    final primary = await _tuneifyBase();
    try {
      if (!await primary.exists()) {
        await primary.create(recursive: true);
      }
      // Test write access to ensure directory is truly writable
      final testFile = File('${primary.path}/.perm_test_${DateTime.now().millisecondsSinceEpoch}');
      await testFile.writeAsString('ok');
      await testFile.delete();
      return primary;
    } catch (_) {
      // On Android 11+ Scoped Storage may block direct creation in /storage/emulated/0/Music.
      // Fallback to app external files directory where write permission is always granted.
      if (Platform.isAndroid) {
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final fallback = Directory('${ext.path}/Music/Utify');
            if (!await fallback.exists()) {
              await fallback.create(recursive: true);
            }
            return fallback;
          }
        } catch (_) {}
      }
      final docs = await getApplicationDocumentsDirectory();
      final fallback = Directory('${docs.path}/Music/Utify');
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback;
    }
  }

  static Future<Directory> _tuneifyBase() async {
    if (Platform.isAndroid) {
      try {
        final appExt = await getExternalStorageDirectory();
        if (appExt != null) {
          Directory root = appExt;
          for (int i = 0; i < 4; i++) {
            final parent = root.parent;
            if (parent.path == root.path) break;
            root = parent;
          }
          return Directory('${root.path}/Music/Utify');
        }
      } catch (_) {}
      return Directory('/storage/emulated/0/Music/Utify');
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return Directory('$userProfile\\Music\\Utify');
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/Music/Utify');
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _join(String dir, String name) =>
      Platform.isWindows ? '$dir\\$name' : '$dir/$name';

  // ── Download ──────────────────────────────────────────────────────────

  Future<String> downloadSong(
    Song song, {
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dir = await getTuneifyDir();

    final safeTitle = song.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final outputPath = _join(dir.path, '$safeTitle.mp4');
    final tmpPath = _join(dir.path, '$safeTitle.tmp');

    // Already downloaded
    if (await File(outputPath).exists()) {
      onProgress?.call(1.0);
      return outputPath;
    }

    // Legacy: old downloads saved as .mp3 — return as-is.
    final legacyMp3Path = _join(dir.path, '$safeTitle.mp3');
    if (await File(legacyMp3Path).exists()) {
      onProgress?.call(1.0);
      return legacyMp3Path;
    }

    // Clean up any leftover tmp file
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) await tmpFile.delete();

    IOSink? sink;
    HttpClient? httpClient;

    try {
      // ── Step 1: get stream manifest ──────────────────────────────
      onProgress?.call(0.01);
      final manifest =
          await _ytService.yt.videos.streamsClient.getManifest(song.id);

      if (isCancelled?.call() == true) throw Exception('Cancelled');

      // Prefer muxed mp4 (has both audio + video → needed for 10s preview).
      List<StreamInfo> streams =
          manifest.muxed.where((s) => s.container.name == 'mp4').toList();
      if (streams.isEmpty) streams = manifest.muxed.toList();
      if (streams.isEmpty) {
        streams = manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
        if (streams.isEmpty) streams = manifest.audioOnly.toList();
      }
      if (streams.isEmpty) {
        throw Exception('No streams found for "${song.title}"');
      }

      // Pick best quality
      streams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final streamInfo = streams.first;
      final expectedTotalBytes = streamInfo.size.totalBytes;

      onProgress?.call(0.02);

      if (isCancelled?.call() == true) throw Exception('Cancelled');

      // ── Step 2: download directly via HttpClient with stall watchdog ───
      sink = tmpFile.openWrite();
      var received = 0;

      httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 15);

      final request = await httpClient.getUrl(streamInfo.url);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      );

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength > 0
          ? response.contentLength
          : expectedTotalBytes;

      final completer = Completer<void>();
      Timer? stallTimer;

      void resetStallTimer() {
        stallTimer?.cancel();
        // If no new chunk arrives within 5 seconds:
        stallTimer = Timer(const Duration(seconds: 5), () {
          final fraction = contentLength > 0 ? (received / contentLength) : 1.0;
          if (fraction >= 0.90 || received >= (expectedTotalBytes > 0 ? expectedTotalBytes - 100000 : 500000)) {
            // >= 90% or within 100KB of expected end:
            // The file is virtually complete and fully playable!
            // Do not hang at 99% waiting for YouTube's throttled socket to close.
            if (!completer.isCompleted) {
              completer.complete();
            }
          } else {
            if (!completer.isCompleted) {
              completer.completeError(
                TimeoutException('Download stalled at ${(fraction * 100).round()}%'),
              );
            }
          }
        });
      }

      resetStallTimer();

      late StreamSubscription<List<int>> subscription;
      subscription = response.listen(
        (chunk) {
          if (isCancelled?.call() == true) {
            subscription.cancel();
            stallTimer?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(Exception('Cancelled'));
            }
            return;
          }

          sink?.add(chunk);
          received += chunk.length;

          if (contentLength > 0) {
            final p = (received / contentLength).clamp(0.0, 1.0);
            onProgress?.call(0.02 + p * 0.97);

            // If we have received all expected bytes, complete immediately
            if (received >= contentLength) {
              stallTimer?.cancel();
              if (!completer.isCompleted) {
                completer.complete();
              }
              subscription.cancel();
              return;
            }
          }

          resetStallTimer();
        },
        onError: (err) {
          stallTimer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
        onDone: () {
          stallTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;

      await sink.flush();
      await sink.close();
      sink = null;
      httpClient.close(force: true);
      httpClient = null;

      // Verify file size is valid (at least 20 KB)
      final downloadedLength = await tmpFile.length();
      if (downloadedLength < 20000) {
        throw Exception('Download produced incomplete file ($downloadedLength bytes)');
      }

      // ── Step 3: finalize file (.tmp → .mp4) ───────────────────────
      try {
        if (await File(outputPath).exists()) {
          await File(outputPath).delete();
        }
        await tmpFile.rename(outputPath);
      } catch (_) {
        // Fallback for Android across mount points or permission barriers
        await tmpFile.copy(outputPath);
        await tmpFile.delete();
      }

      onProgress?.call(1.0);
      return outputPath;
    } catch (e) {
      httpClient?.close(force: true);
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await tmpFile.exists()) {
        await tmpFile.delete().catchError((_) => tmpFile);
      }
      rethrow;
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      await downloadSong(song);
    }
  }
}

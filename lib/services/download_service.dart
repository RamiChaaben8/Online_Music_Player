// ============================================================
// services/download_service.dart
//
// Uses the SAME stream URL that just_audio uses for playback
// (muxed mp4, already proven to work) fetched via YoutubeService's
// cache. Downloads with dart:io HttpClient + identical headers to
// what AudioPlayerService sends — so YouTube CDN accepts the request.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import 'youtube_service.dart';

const _kStreamTimeout = Duration(minutes: 5);

// Same user-agent as AudioPlayerService / just_audio
const _kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

class DownloadService {
  final YoutubeService _ytService;

  DownloadService(this._ytService);

  // ── Directory ──────────────────────────────────────────────────────────

  static Future<Directory> getTuneifyDir() async {
    final base = await _tuneifyBase();
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  static Future<Directory> _tuneifyBase() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return Directory('${ext.path}/Music/Tuneify');
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/Music/Tuneify');
  }

  // ── Download ───────────────────────────────────────────────────────────

  Future<String> downloadSong(
    Song song, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTuneifyDir();

    final safeTitle = song.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Save as .mp4 — it's a muxed mp4 stream; just_audio plays it fine.
    final filePath = '${dir.path}/$safeTitle.mp4';
    final file = File(filePath);

    // Also check legacy .mp3 path in case user has files from earlier versions
    final legacyPath = '${dir.path}/$safeTitle.mp3';
    if (await File(legacyPath).exists() || await file.exists()) {
      onProgress?.call(1.0);
      return await file.exists() ? filePath : legacyPath;
    }

    final tmpPath = '${dir.path}/$safeTitle.tmp';
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) await tmpFile.delete();

    IOSink? sink;

    try {
      // ── 1. Get stream URL (same one just_audio uses) ──────────────
      // This hits the cache first so it's instant if the song was
      // recently played; otherwise fetches the manifest.
      onProgress?.call(0.01);
      final streamUrl = await _ytService.getAudioStreamUrl(song.id);

      // ── 2. HEAD request to get Content-Length ─────────────────────
      final uri = Uri.parse(streamUrl);
      int totalBytes = 0;
      try {
        final client = HttpClient();
        final headReq = await client.headUrl(uri)
            .timeout(const Duration(seconds: 15));
        headReq.headers.set(HttpHeaders.userAgentHeader, _kUserAgent);
        final headRes = await headReq.close()
            .timeout(const Duration(seconds: 15));
        totalBytes = headRes.contentLength;
        await headRes.drain<void>();
        client.close();
      } catch (_) {
        // If HEAD fails, total is unknown — progress will be indeterminate
      }

      onProgress?.call(0.02);

      // ── 3. Download via HttpClient with same headers as just_audio ─
      sink = tmpFile.openWrite();
      var received = 0;
      final completer = Completer<void>();

      final dlClient = HttpClient();
      final request = await dlClient.getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers
        ..set(HttpHeaders.userAgentHeader, _kUserAgent)
        ..set('Accept', '*/*')
        ..set('Accept-Encoding', 'identity')
        ..set('Connection', 'keep-alive');

      final response = await request.close()
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 && response.statusCode != 206) {
        dlClient.close(force: true);
        throw Exception('HTTP ${response.statusCode} downloading "${song.title}"');
      }

      // Use content-length from response if HEAD failed
      if (totalBytes <= 0) {
        totalBytes = response.contentLength;
      }

      Timer? watchdog;
      StreamSubscription<List<int>>? sub;

      sub = response.listen(
        (List<int> chunk) {
          sink!.add(chunk);
          received += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call(0.02 + (received / totalBytes) * 0.98);
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        cancelOnError: true,
      );

      watchdog = Timer(_kStreamTimeout, () {
        if (!completer.isCompleted) {
          sub?.cancel();
          completer.completeError(
              TimeoutException('Download timed out for "${song.title}"'));
        }
      });

      try {
        await completer.future;
      } finally {
        watchdog.cancel();
        dlClient.close(force: true);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // ── 4. Rename tmp → final ─────────────────────────────────────
      await tmpFile.rename(filePath);
      onProgress?.call(1.0);
      return filePath;
    } catch (e) {
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await tmpFile.exists()) {
        await tmpFile.delete().catchError((_) => tmpFile);
      }
      if (await file.exists()) {
        await file.delete().catchError((_) => file);
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

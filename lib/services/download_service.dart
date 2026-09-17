// ============================================================
// services/download_service.dart
//
// Downloads songs from YouTube to device storage.
//
// WHY youtube_explode's stream client (not dart:io HttpClient):
//   YouTube stream URLs are signed and require the exact same User-Agent,
//   cookies, and headers that youtube_explode sends.  A plain HttpClient
//   request gets a 403 Forbidden because Google's CDN rejects unauthenticated
//   direct-download attempts.  By piping through _yt.videos.streamsClient we
//   inherit all the correct headers automatically.
//
// File extension: muxed streams are MP4 containers (H.264 + AAC), so we save
//   as .mp4.  Most media players on Android recognise this correctly; saving
//   as .mp3 causes metadata parsing to fail.
// ============================================================

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../models/playlist.dart';
import '../models/song.dart';
import 'youtube_service.dart';

class DownloadService {
  final YoutubeService _ytService;

  DownloadService(this._ytService);

  Future<void> downloadSong(Song song) async {
    // ── 1. Permissions (Android only) ────────────────────────────────────
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      // On Android 13+ the storage permission is split; if still denied, bail
      if (!status.isGranted) {
        throw Exception('Storage permission denied — cannot save file');
      }
    }

    // ── 2. Resolve save directory ─────────────────────────────────────────
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    // ── 3. Build the output file path (.mp4, not .mp3) ────────────────────
    //   Muxed YouTube streams are MP4 containers (H.264 video + AAC audio).
    //   Saving as .mp3 confuses media players because the container signature
    //   does not match.  .mp4 works correctly on both Android and iOS.
    final safeTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeTitle.mp4');

    if (await file.exists()) return; // already downloaded

    // ── 4. Resolve the best stream info ───────────────────────────────────
    //   We use youtube_explode's streamsClient so the request goes through
    //   the same authenticated HTTP client that avoids 403 errors.
    try {
      final yt = _ytService.yt; // shared YoutubeExplode instance
      final manifest =
          await yt.videos.streamsClient.getManifest(song.id);

      // Prefer MP4 muxed; fall back to any muxed stream
      var muxedStreams = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (muxedStreams.isEmpty) {
        muxedStreams = manifest.muxed.toList();
      }
      if (muxedStreams.isEmpty) {
        throw Exception('No downloadable streams found for "${song.title}"');
      }

      // Pick the lowest-quality stream to save bandwidth on download
      muxedStreams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxedStreams.first;

      // ── 5. Pipe the stream directly to disk ────────────────────────────
      //   youtube_explode's get(streamInfo) handles all headers/auth for us.
      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = file.openWrite();
      try {
        await stream.pipe(sink);
      } finally {
        await sink.flush();
        await sink.close();
      }
    } catch (e) {
      // Remove partial file on failure
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

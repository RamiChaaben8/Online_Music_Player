// ============================================================
// services/download_service.dart
//
// Downloads songs to /Music/Tuneify on the device.
// Creates the folder if it doesn't exist.
// Uses youtube_explode's own HTTP client to avoid 403 errors.
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

  /// Returns the Tuneify music folder, creating it if needed.
  static Future<Directory> getTuneifyDir() async {
    Directory? base;

    if (Platform.isAndroid) {
      // /storage/emulated/0/Music/Tuneify — visible in Files app
      try {
        final ext = await getExternalStorageDirectory();
        // getExternalStorageDirectory() returns something like
        // /storage/emulated/0/Android/data/…/files — walk up to the root
        if (ext != null) {
          // Go up 4 levels: files → data → Android → emulated/0
          Directory root = ext;
          for (int i = 0; i < 4; i++) {
            final parent = root.parent;
            if (parent.path == root.path) break;
            root = parent;
          }
          base = Directory('${root.path}/Music/Tuneify');
        }
      } catch (_) {}
      base ??= Directory('/storage/emulated/0/Music/Tuneify');
    } else if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      base = Directory('${docs.path}/Music/Tuneify');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      base = Directory('${docs.path}/Music/Tuneify');
    }

    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    return base;
  }

  Future<String> downloadSong(Song song) async {
    // ── 1. Permissions ────────────────────────────────────────────────────
    if (Platform.isAndroid) {
      // Android 13+ (SDK 33) removed READ_EXTERNAL_STORAGE; use audio/video
      // permissions instead. permission_handler handles the split automatically.
      bool granted = false;

      // Try the modern granular permissions first (Android 13+)
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        granted = true;
      } else {
        // Fallback for Android 10-12
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        granted = status.isGranted;
      }

      if (!granted) {
        throw Exception('Storage permission denied — cannot save file');
      }
    }

    // ── 2. Resolve the Tuneify directory ──────────────────────────────────
    final dir = await getTuneifyDir();
    final safeTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${dir.path}/$safeTitle.mp4';
    final file = File(filePath);

    if (await file.exists()) return filePath; // already downloaded

    // ── 3. Fetch stream via youtube_explode (avoids 403) ─────────────────
    try {
      final yt = _ytService.yt;
      final manifest = await yt.videos.streamsClient.getManifest(song.id);

      var muxed = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (muxed.isEmpty) muxed = manifest.muxed.toList();
      if (muxed.isEmpty) {
        throw Exception('No downloadable streams for "${song.title}"');
      }

      muxed.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final streamInfo = muxed.first;

      final stream = yt.videos.streamsClient.get(streamInfo);
      final sink = file.openWrite();
      try {
        await stream.pipe(sink);
      } finally {
        await sink.flush();
        await sink.close();
      }

      return filePath;
    } catch (e) {
      if (await file.exists()) await file.delete().catchError((_) => file);
      rethrow;
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      await downloadSong(song);
    }
  }
}

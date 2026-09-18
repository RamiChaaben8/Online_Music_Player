// ============================================================
// services/local_music_service.dart
//
// Scans device storage for audio files.
// Duplicates are eliminated at two levels:
//   1. Directory level  — candidate dirs are resolved to their real
//      path (resolveSymbolicLinksSync) before scanning, so /sdcard
//      and /storage/emulated/0 (which are symlinks to the same place)
//      are only scanned once.
//   2. File level       — absolute file paths are tracked in a Set so
//      no file is added twice even if reachable via multiple paths.
// ============================================================

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import 'download_service.dart';

const _audioExts = {
  '.mp3', '.m4a', '.aac', '.ogg', '.flac',
  '.wav', '.opus', '.webm', '.mp4',
};

class LocalMusicService {

  Future<List<Song>> scanLocalSongs() async {
    // Resolve every candidate to its real path so symlinks don't
    // cause the same directory to be scanned multiple times.
    final seenDirs  = <String>{};   // canonical dir paths already queued
    final seenFiles = <String>{};   // canonical file paths already added
    final songs     = <Song>[];

    for (final raw in await _candidateDirs()) {
      if (!await raw.exists()) continue;

      // Resolve symlinks → real path
      String canonical;
      try {
        canonical = raw.resolveSymbolicLinksSync();
      } catch (_) {
        canonical = raw.path;
      }

      if (!seenDirs.add(canonical)) continue; // already scheduled

      try {
        await _scanDir(
          Directory(canonical),
          songs,
          seenFiles,
          seenDirs,
          maxDepth: 3,
        );
      } catch (_) {}
    }

    songs.sort((a, b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return songs;
  }

  // ── Candidate directories ──────────────────────────────────────────────

  Future<List<Directory>> _candidateDirs() async {
    final dirs = <Directory>[];

    // 1. Always include the app-scoped Tuneify download folder
    try {
      dirs.add(await DownloadService.getTuneifyDir());
    } catch (_) {}

    if (!Platform.isAndroid) return dirs;

    // 2. Derive the storage root from the app's external dir
    try {
      final appExt = await getExternalStorageDirectory();
      if (appExt != null) {
        // appExt = /storage/emulated/0/Android/data/<pkg>/files
        // Walk up 4 levels → /storage/emulated/0
        Directory root = appExt;
        for (int i = 0; i < 4; i++) {
          final p = root.parent;
          if (p.path == root.path) break;
          root = p;
        }
        for (final name in [
          'Music', 'Download', 'Downloads',
          'Ringtones', 'Notifications', 'Alarms',
        ]) {
          dirs.add(Directory('${root.path}/$name'));
        }
      }
    } catch (_) {}

    // 3. SD cards via getExternalStorageDirectories()
    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null) {
        for (final d in extDirs) {
          Directory root = d;
          for (int i = 0; i < 4; i++) {
            final p = root.parent;
            if (p.path == root.path) break;
            root = p;
          }
          dirs.add(Directory('${root.path}/Music'));
          dirs.add(Directory('${root.path}/Download'));
        }
      }
    } catch (_) {}

    // NOTE: we deliberately do NOT add hard-coded /sdcard or
    // /storage/sdcard0 — they are symlinks to /storage/emulated/0
    // and would be deduplicated anyway, but skipping them avoids
    // the resolveSymbolicLinks overhead.

    return dirs;
  }

  // ── Recursive scanner ──────────────────────────────────────────────────

  Future<void> _scanDir(
    Directory dir,
    List<Song> songs,
    Set<String> seenFiles,
    Set<String> seenDirs, {
    required int maxDepth,
  }) async {
    if (maxDepth < 0) return;

    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final entry in entries) {
      if (entry is File) {
        final ext = _ext(entry.path);
        if (!_audioExts.contains(ext)) continue;

        // Resolve file path to handle any symlinks
        String canonical;
        try {
          canonical = entry.resolveSymbolicLinksSync();
        } catch (_) {
          canonical = entry.path;
        }
        if (!seenFiles.add(canonical)) continue;

        final song = _fileToSong(File(canonical));
        if (song != null) songs.add(song);
      } else if (entry is Directory && maxDepth > 0) {
        final name = entry.path.split('/').last;
        if (name.startsWith('.')) continue;
        if (name == 'Android') continue; // skip app sandboxes

        String canonical;
        try {
          canonical = entry.resolveSymbolicLinksSync();
        } catch (_) {
          canonical = entry.path;
        }
        if (!seenDirs.add(canonical)) continue; // already scanned

        await _scanDir(
          Directory(canonical),
          songs,
          seenFiles,
          seenDirs,
          maxDepth: maxDepth - 1,
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot).toLowerCase();
  }

  Song? _fileToSong(File file) {
    try {
      final filename = file.uri.pathSegments.last;
      final ext = _ext(filename);
      final nameWithoutExt = ext.isNotEmpty && filename.endsWith(ext)
          ? filename.substring(0, filename.length - ext.length)
          : filename;

      final title = nameWithoutExt.trim();
      if (title.isEmpty) return null;

      return Song(
        id: 'local:${file.path}',
        title: title,
        channelName: 'Local',
        thumbnailUrl: '',
        duration: Duration.zero,
        isLocal: true,
        localPath: file.path,
      );
    } catch (_) {
      return null;
    }
  }
}

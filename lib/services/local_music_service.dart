// ============================================================
// services/local_music_service.dart
//
// Scans the Music/Tuneify folder for downloaded songs and
// converts them to Song objects with isLocal = true.
// ============================================================

import 'dart:io';

import '../models/song.dart';
import 'download_service.dart';

class LocalMusicService {
  /// Scans the Tuneify folder and returns all found songs as Song objects.
  /// Supports .mp4 and .mp3 files.
  Future<List<Song>> scanLocalSongs() async {
    try {
      final dir = await DownloadService.getTuneifyDir();
      if (!await dir.exists()) return [];

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) {
            final ext = f.path.toLowerCase();
            return ext.endsWith('.mp4') || ext.endsWith('.mp3');
          })
          .toList();

      final songs = <Song>[];
      for (final file in files) {
        final song = _fileToSong(file);
        if (song != null) songs.add(song);
      }

      // Sort alphabetically by title
      songs.sort((a, b) => a.title.compareTo(b.title));
      return songs;
    } catch (_) {
      return [];
    }
  }

  Song? _fileToSong(File file) {
    try {
      final filename = file.uri.pathSegments.last;
      // Strip extension
      final nameWithoutExt = filename.contains('.')
          ? filename.substring(0, filename.lastIndexOf('.'))
          : filename;

      // Restore characters we replaced during download
      final title = nameWithoutExt.replaceAll('_', ' ').trim();
      if (title.isEmpty) return null;

      final path = file.path;

      return Song(
        // Use the file path as the unique ID for local songs
        id: 'local:$path',
        title: title,
        channelName: 'Local',
        // No network thumbnail for local files — empty triggers placeholder
        thumbnailUrl: '',
        duration: Duration.zero, // Duration requires reading file metadata
        isLocal: true,
        localPath: path,
      );
    } catch (_) {
      return null;
    }
  }
}

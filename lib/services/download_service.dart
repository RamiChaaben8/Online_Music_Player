// ============================================================
// services/download_service.dart
// ============================================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'youtube_service.dart';

class DownloadService {
  final YoutubeService _ytService;
  
  DownloadService(this._ytService);

  Future<void> downloadSong(Song song) async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
    }
    
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    final safeTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeTitle.mp3');
    
    if (await file.exists()) return;
    
    try {
      final streamUrl = await _ytService.getAudioStreamUrl(song.id);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(streamUrl));
      final response = await request.close();
      await response.pipe(file.openWrite());
    } catch (e) {
      print('Failed to download song: $e');
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      await downloadSong(song);
    }
  }
}

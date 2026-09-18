// ============================================================
// main.dart
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/song.dart';
import 'models/playlist.dart';
import 'app.dart';
import 'services/youtube_service.dart';
import 'services/library_service.dart';
import 'services/audio_player_service.dart';
import 'services/audio_handler.dart';
import 'providers/player_provider.dart';

/// Global handler — initialised once in main(), shared via provider.
late final TuneifyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(PlaylistAdapter());

  await Future.wait([
    Hive.openBox<Song>('liked_songs'),
    Hive.openBox<Song>('recently_played'),
    Hive.openBox<Playlist>('playlists'),
    Hive.openBox('settings'),
    Hive.openBox('stream_url_cache'),
  ]);

  // Register the audio handler with the OS.
  // audio_service takes over notification management from just_audio_background.
  audioHandler = await AudioService.init(
    builder: () {
      final yt = YoutubeService();
      final player = AudioPlayerService(yt);
      return TuneifyAudioHandler(player);
    },
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.testf.channel.audio',
      androidNotificationChannelName: 'Tuneify',
      androidShowNotificationBadge: true,
      // White monochrome icon for the status bar (Android requirement)
      androidNotificationIcon: 'drawable/ic_notification',
      // Keep notification alive when paused so the user can resume from
      // the lock screen or notification shade.
      // Note: androidNotificationOngoing must be false when
      // androidStopForegroundOnPause is false (audio_service assertion).
      androidStopForegroundOnPause: false,
      notificationColor: Color(0xFF1DB954),
      artDownscaleWidth: 300,
      artDownscaleHeight: 300,
    ),
  );

  runApp(ProviderScope(
    overrides: [
      // Give every provider in the tree the same handler instance that
      // audio_service registered — this is how playerProvider gets it.
      audioHandlerProvider.overrideWithValue(audioHandler),
    ],
    child: const TuneifyApp(),
  ));

  WidgetsBinding.instance.addPostFrameCallback((_) => _warmCache());
}

void _warmCache() {
  try {
    final lib = LibraryService();
    final yt = YoutubeService();

    final recent = lib.getRecentlyPlayed().take(6).toList();
    final liked  = lib.getLikedSongs().take(4).toList();

    final Map<String, Song> byId = {};
    for (final s in [...recent, ...liked]) {
      byId[s.id] = s;
    }

    for (final song in byId.values) {
      yt.seedFromSong(song);
    }

    final needsFetch = byId.values
        .where((s) => s.isStreamUrlExpired)
        .map((s) => s.id)
        .toList();

    if (needsFetch.isNotEmpty) {
      yt.prefetchBatch(needsFetch, maxConcurrent: 3);
    }
  } catch (_) {}
}

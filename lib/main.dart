// ============================================================
// main.dart
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'dart:io';

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

  // Initialise the media_kit backend for Windows/Linux.
  // On Android, just_audio uses its own native backend — this call is a no-op.
  if (Platform.isWindows || Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized(
      windows: true,
      linux: true,
      android: false,
      iOS: false,
      macOS: false,
    );
  }

  // Register fvp as the video_player backend for desktop platforms.
  // This enables video_player to work on Windows/Linux/macOS using libmdk.
  fvp.registerWith(options: {
    'platforms': ['windows', 'linux', 'macos'],
  });

  // Register the audio handler with the OS.
  // audio_service takes over notification management from just_audio_background.
  audioHandler = await AudioService.init(
    builder: () {
      final yt = YoutubeService();
      final player = AudioPlayerService(yt);
      return TuneifyAudioHandler(player);
    },
    config: AudioServiceConfig(
      // Android-only notification fields — audio_service requires non-null
      // Strings, so we pass empty strings on desktop (they are ignored).
      androidNotificationChannelId: Platform.isAndroid
          ? 'com.example.testf.channel.audio'
          : 'tuneify.desktop',
      androidNotificationChannelName:
          Platform.isAndroid ? 'Tuneify' : 'Tuneify',
      androidShowNotificationBadge: Platform.isAndroid,
      androidNotificationIcon: Platform.isAndroid
          ? 'drawable/ic_notification'
          : 'mipmap/ic_launcher',
      // On Android: keep foreground service alive when paused (lock-screen resume).
      // On desktop: must be true (no foreground service concept).
      androidStopForegroundOnPause: !Platform.isAndroid,
      notificationColor: const Color(0xFF1DB954),
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

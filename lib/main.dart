// ============================================================
// main.dart
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'dart:io';

import 'firebase_options.dart';

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

  // Initialise Firebase first — required before any Firebase service is used.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence.
  // On mobile this is the default; on Web/Desktop we enable it explicitly.
  // This lets the app read/write while offline and sync when back online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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

  // ── Audio handler initialisation ─────────────────────────────────────────
  //
  // audio_service only supports Android, iOS, macOS and Web.
  // On Windows it has no platform implementation — AudioService.init() calls
  // the builder but wraps the result in a stub that silently no-ops every
  // transport call (play, pause, skipToNext, …), making ALL playback broken.
  //
  // Fix: on Windows, construct TuneifyAudioHandler directly — no wrapping,
  // no stub.  just_audio + just_audio_media_kit handle the actual audio.
  // We simply don't get OS media-key integration on Windows (which
  // audio_service wouldn't provide anyway since it has no Windows impl).
  //
  // On Android/iOS/macOS AudioService.init keeps working normally for
  // lock-screen controls, notifications and the foreground service.
  if (Platform.isWindows || Platform.isLinux) {
    final yt     = YoutubeService();
    final player = AudioPlayerService(yt);
    audioHandler = TuneifyAudioHandler(player);
  } else {
    audioHandler = await AudioService.init(
      builder: () {
        final yt     = YoutubeService();
        final player = AudioPlayerService(yt);
        return TuneifyAudioHandler(player);
      },
      config: AudioServiceConfig(
        androidNotificationChannelId: Platform.isAndroid
            ? 'com.example.testf.channel.audio'
            : 'tuneify.desktop',
        androidNotificationChannelName:
            Platform.isAndroid ? 'Tuneify' : 'Tuneify',
        androidShowNotificationBadge: Platform.isAndroid,
        androidNotificationIcon: Platform.isAndroid
            ? 'drawable/ic_notification'
            : 'mipmap/ic_launcher',
        androidStopForegroundOnPause: !Platform.isAndroid,
        notificationColor: const Color(0xFF1DB954),
        artDownscaleWidth: 300,
        artDownscaleHeight: 300,
      ),
    );
  }

  // Restore local audio settings before the first frame. This prevents the
  // first playback request from using a default volume for one track.
  await audioHandler.service.initialize();

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

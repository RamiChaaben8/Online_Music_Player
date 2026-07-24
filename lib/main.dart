// ============================================================
// main.dart — App entry point
// Initialises Hive, just_audio_background, and Riverpod.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'models/song.dart';
import 'models/playlist.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise just_audio_background for lock-screen / notification controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.testf.channel.audio',
    androidNotificationChannelName: 'Tuneify Audio Playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );

  // Initialise Hive for local persistence.
  await Hive.initFlutter();

  // Register type adapters.
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(PlaylistAdapter());

  // Open boxes.
  await Hive.openBox<Song>('liked_songs');
  await Hive.openBox<Song>('recently_played');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox('settings');

  runApp(
    // ProviderScope is required for Riverpod.
    const ProviderScope(
      child: TuneifyApp(),
    ),
  );
}

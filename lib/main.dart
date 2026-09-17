// ============================================================
// main.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'models/song.dart';
import 'models/playlist.dart';
import 'app.dart';
import 'services/youtube_service.dart';
import 'services/library_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.testf.channel.audio',
    androidNotificationChannelName: 'Tuneify Audio Playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
  );

  await Hive.initFlutter();

  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(PlaylistAdapter());

  await Future.wait([
    Hive.openBox<Song>('liked_songs'),
    Hive.openBox<Song>('recently_played'),
    Hive.openBox<Playlist>('playlists'),
    Hive.openBox('settings'),
    // Persistent stream URL cache — survives app restarts.
    // Key: videoId  Value: {'url': String, 'ts': int (ms since epoch)}
    Hive.openBox('stream_url_cache'),
  ]);

  runApp(const ProviderScope(child: TuneifyApp()));

  // After the first frame is drawn, warm the URL cache for recently played
  // and liked songs in the background. These are the songs most likely to be
  // played next, so resolving their URLs while the home screen loads means
  // they start instantly when tapped.
  WidgetsBinding.instance.addPostFrameCallback((_) => _warmCache());
}

/// Silently prefetch stream URLs for the user's most-played songs.
/// Runs entirely in the background — never blocks the UI.
void _warmCache() {
  try {
    final lib = LibraryService();
    final yt = YoutubeService();

    final recent = lib.getRecentlyPlayed().take(6).toList();
    final liked = lib.getLikedSongs().take(4).toList();

    // Deduplicate
    final Map<String, Song> byId = {};
    for (final s in [...recent, ...liked]) {
      byId[s.id] = s;
    }

    // Step 1 — seed L1 memory cache from streamUrl already stored on each
    // Song object. This is completely free (no Hive box reads, no network).
    for (final song in byId.values) {
      yt.seedFromSong(song);
    }

    // Step 2 — for any songs whose stored URL is missing/expired, kick off
    // a background manifest fetch now so it's ready before the user taps.
    final needsFetch = byId.values
        .where((s) => s.isStreamUrlExpired)
        .map((s) => s.id)
        .toList();

    if (needsFetch.isNotEmpty) {
      yt.prefetchBatch(needsFetch, maxConcurrent: 3);
    }
  } catch (_) {
    // Warm-up is best-effort; never crash on startup because of this
  }
}

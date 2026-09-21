// ============================================================
// providers/home_provider.dart
//
// Manages the home feed sections:
//   • Recommended  — based on top artist from liked/recent songs
//   • Trending     — global hot tracks right now
//   • Your Taste   — based on 2nd-most-played artist/genre
//   • New Releases — freshest uploads query
//   • Chill Mix    — mood-based section
//
// Each section loads independently so the screen can render
// sections as they arrive (skeleton → content).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/youtube_service.dart';
import 'youtube_provider.dart';
import 'library_provider.dart';

// ─── Section model ────────────────────────────────────────────────────────────

enum HomeSectionType { music, podcasts, videos }
enum HomeFilter { all, music, podcasts, videos }

final homeFilterProvider = StateProvider<HomeFilter>((_) => HomeFilter.all);

bool isHomeVideo(Song song) {
  final text = '${song.title} ${song.channelName}'.toLowerCase();
  const markers = [
    'official video',
    'music video',
    'video clip',
    'trailer',
    'movie',
    'film',
    'episode',
    'scene',
    'shorts',
    'gameplay',
    'reaction',
    'prank',
    'interview',
    'news',
    'documentary',
    'story',
  ];
  return markers.any(text.contains);
}

bool isHomePodcast(Song song) {
  final text = '${song.title} ${song.channelName}'.toLowerCase();
  const markers = [
    'podcast',
    'podcasts',
    'episode',
    'interview',
    'talk show',
    'radio',
  ];
  return markers.any(text.contains);
}

bool isHomeMusic(Song song) {
  if (isHomePodcast(song)) return false;
  final text = '${song.title} ${song.channelName}'.toLowerCase();
  const nonMusicMarkers = [
    'trailer',
    'movie',
    'film',
    'episode',
    'scene',
    'gameplay',
    'reaction',
    'prank',
    'news',
    'documentary',
    'story',
    'compilation',
    'funny',
    'challenge',
  ];
  return !nonMusicMarkers.any(text.contains);
}

List<Song> homeSongsForFilter(HomeSection section, HomeFilter filter) {
  if (filter == HomeFilter.all) return section.songs;
  if (filter == HomeFilter.music) {
    return section.songs.where(isHomeMusic).toList();
  }
  if (filter == HomeFilter.podcasts) {
    return section.songs.where(isHomePodcast).toList();
  }
  return section.songs.where(isHomeVideo).toList();
}

class HomeSection {
  final String title;
  final String subtitle;
  final List<Song> songs;
  final bool isLoading;
  final HomeSectionType type;

  const HomeSection({
    required this.title,
    required this.subtitle,
    this.songs = const [],
    this.isLoading = true,
    this.type = HomeSectionType.music,
  });

  HomeSection copyWith({
    String? title,
    String? subtitle,
    List<Song>? songs,
    bool? isLoading,
    HomeSectionType? type,
  }) {
    return HomeSection(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      type: type ?? this.type,
    );
  }
}

// ─── Home state ───────────────────────────────────────────────────────────────

class HomeState {
  final List<HomeSection> sections;
  final bool initialLoading;

  const HomeState({
    this.sections = const [],
    this.initialLoading = true,
  });

  HomeState copyWith({
    List<HomeSection>? sections,
    bool? initialLoading,
  }) {
    return HomeState(
      sections: sections ?? this.sections,
      initialLoading: initialLoading ?? this.initialLoading,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class HomeNotifier extends StateNotifier<HomeState> {
  final YoutubeService _youtube;
  final LibraryState _library;

  HomeNotifier(this._youtube, this._library) : super(const HomeState()) {
    _buildSections();
  }

  List<Song> _songsForType(List<Song> songs, HomeSectionType type) {
    final filtered = switch (type) {
      HomeSectionType.music => songs.where(isHomeMusic).toList(),
      HomeSectionType.podcasts => songs.where(isHomePodcast).toList(),
      HomeSectionType.videos => songs.where(isHomeVideo).toList(),
    };

    filtered.sort((a, b) => _score(b, type).compareTo(_score(a, type)));
    return filtered;
  }

  int _score(Song song, HomeSectionType type) {
    final text = '${song.title} ${song.channelName}'.toLowerCase();
    var score = 0;
    if (type == HomeSectionType.music) {
      if (text.contains('official audio')) score += 8;
      if (text.contains('lyrics')) score += 5;
      if (text.contains('audio')) score += 3;
      if (text.contains('live')) score += 1;
      if (text.contains('remix')) score += 1;
    } else if (type == HomeSectionType.videos) {
      if (text.contains('official video')) score += 8;
      if (text.contains('music video')) score += 6;
      if (text.contains('video')) score += 3;
    } else if (text.contains('podcast')) {
      score += 8;
    }
    return score;
  }

  /// Derive smart queries from the user's library.
  List<String> _topArtists() {
    final all = [..._library.recentlyPlayed, ..._library.likedSongs];
    if (all.isEmpty) return [];
    final freq = <String, int>{};
    for (final s in all) {
      freq[s.channelName] = (freq[s.channelName] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  Future<void> _buildSections() async {
    final artists = _topArtists();
    final hasHistory = artists.isNotEmpty;

    // ── Define all sections up-front (shown as skeletons immediately) ──────
    final defs = <({
      String title,
      String subtitle,
      String query,
      HomeSectionType type
    })>[
      if (hasHistory)
        (
          title: 'Recommended For You',
          subtitle: 'Based on what you play',
          query:
              '${artists.first} official audio songs -trailer -movie -episode -reaction',
          type: HomeSectionType.music,
        ),
      (
        title: 'Trending Now',
        subtitle: 'Hot tracks right now',
        query:
            'top hits 2024 official audio -trailer -movie -episode -reaction',
        type: HomeSectionType.music,
      ),
      if (hasHistory && artists.length > 1)
        (
          title: 'Your Taste',
          subtitle: 'More of what you love',
          query:
              '${artists[1]} best songs official audio -trailer -movie -episode',
          type: HomeSectionType.music,
        ),
      (
        title: 'New Releases',
        subtitle: 'Fresh drops this week',
        query: 'new music 2024 official audio -trailer -movie -episode',
        type: HomeSectionType.music,
      ),
      (
        title: 'Chill Mix',
        subtitle: 'Relax and unwind',
        query: 'chill music mix lofi vibes -trailer -movie -episode',
        type: HomeSectionType.music,
      ),
      (
        title: 'Hip-Hop & R&B',
        subtitle: 'Street to studio',
        query: 'hip hop rnb hits 2024 official audio -trailer -movie',
        type: HomeSectionType.music,
      ),
      (
        title: 'Pop Hits',
        subtitle: "Today's biggest bangers",
        query: 'pop hits playlist 2024 official audio -trailer -movie',
        type: HomeSectionType.music,
      ),
      (
        title: 'Podcasts',
        subtitle: 'Talk shows and podcasts',
        query: 'popular podcasts episodes',
        type: HomeSectionType.podcasts,
      ),
      (
        title: 'Videos',
        subtitle: 'Music videos and more',
        query: 'popular music videos',
        type: HomeSectionType.videos,
      ),
    ];

    // Initialise state with all sections in loading state
    state = HomeState(
      initialLoading: false,
      sections: defs
          .map((d) => HomeSection(
                title: d.title,
                subtitle: d.subtitle,
                type: d.type,
                isLoading: true,
              ))
          .toList(),
    );

    // Load each section concurrently, update state as each one completes
    await Future.wait(
      List.generate(defs.length, (i) async {
        final songs = _songsForType(
          await _youtube.searchSection(defs[i].query),
          defs[i].type,
        );
        if (!mounted) return;
        final updated = List<HomeSection>.from(state.sections);
        updated[i] = updated[i].copyWith(songs: songs, isLoading: false);
        state = state.copyWith(sections: updated);
      }),
    );
  }

  Future<void> refresh() async {
    state = const HomeState(initialLoading: true);
    await _buildSections();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(
    ref.watch(youtubeServiceProvider),
    // Use read so homeProvider is NOT recreated every time libraryProvider
    // changes (e.g. when a song is added to recently played on each play).
    // The home feed only needs the library snapshot at startup to build
    // personalised sections — not a live subscription.
    ref.read(libraryProvider),
  );
});

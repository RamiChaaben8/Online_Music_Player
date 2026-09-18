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

class HomeSection {
  final String title;
  final String subtitle;
  final List<Song> songs;
  final bool isLoading;

  const HomeSection({
    required this.title,
    required this.subtitle,
    this.songs = const [],
    this.isLoading = true,
  });

  HomeSection copyWith({
    String? title,
    String? subtitle,
    List<Song>? songs,
    bool? isLoading,
  }) {
    return HomeSection(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
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
    final defs = <({String title, String subtitle, String query})>[
      if (hasHistory)
        (
          title: 'Recommended For You',
          subtitle: 'Based on what you play',
          query: '${artists.first} songs mix',
        ),
      (
        title: 'Trending Now',
        subtitle: 'Hot tracks right now',
        query: 'top hits 2024 official audio',
      ),
      if (hasHistory && artists.length > 1)
        (
          title: 'Your Taste',
          subtitle: 'More of what you love',
          query: '${artists[1]} best songs',
        ),
      (
        title: 'New Releases',
        subtitle: 'Fresh drops this week',
        query: 'new music 2024 official audio',
      ),
      (
        title: 'Chill Mix',
        subtitle: 'Relax and unwind',
        query: 'chill music mix lofi vibes',
      ),
      (
        title: 'Hip-Hop & R&B',
        subtitle: 'Street to studio',
        query: 'hip hop rnb hits 2024',
      ),
      (
        title: 'Pop Hits',
        subtitle: "Today's biggest bangers",
        query: 'pop hits playlist 2024',
      ),
    ];

    // Initialise state with all sections in loading state
    state = HomeState(
      initialLoading: false,
      sections: defs
          .map((d) => HomeSection(
                title: d.title,
                subtitle: d.subtitle,
                isLoading: true,
              ))
          .toList(),
    );

    // Load each section concurrently, update state as each one completes
    await Future.wait(
      List.generate(defs.length, (i) async {
        final songs = await _youtube.searchSection(defs[i].query);
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
    ref.watch(libraryProvider),
  );
});

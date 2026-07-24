// ============================================================
// providers/youtube_provider.dart
//
// Provides the YoutubeService singleton and a search state.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/youtube_service.dart';

// Singleton YoutubeService
final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(service.dispose);
  return service;
});

// ─── Search state ────────────────────────────────────────────────────────────

class SearchState {
  final List<Song> results;
  final bool isLoading;
  final String? error;
  final String query;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<Song>? results,
    bool? isLoading,
    String? error,
    String? query,
    bool clearError = false,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final YoutubeService _youtube;

  SearchNotifier(this._youtube) : super(const SearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: query, clearError: true);

    try {
      final results = await _youtube.search(query);
      state = state.copyWith(results: results, isLoading: false);
    } on YoutubeServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Check your connection.',
      );
    }
  }

  void clear() => state = const SearchState();
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(youtubeServiceProvider));
});

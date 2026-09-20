// ============================================================
// providers/lyrics_provider.dart
//
// Fetches YouTube closed captions for the current song and
// exposes them as a Riverpod AsyncNotifier.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/youtube_service.dart';
import 'player_provider.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class LyricsState {
  final String? videoId;       // which video the lines belong to
  final bool isLoading;
  final String? error;
  final List<LyricLine> lines;

  const LyricsState({
    this.videoId,
    this.isLoading = false,
    this.error,
    this.lines = const [],
  });

  bool get hasLyrics => lines.isNotEmpty;

  LyricsState copyWith({
    String? videoId,
    bool? isLoading,
    String? error,
    List<LyricLine>? lines,
    bool clearError = false,
  }) {
    return LyricsState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lines: lines ?? this.lines,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class LyricsNotifier extends StateNotifier<LyricsState> {
  final YoutubeService _yt;

  LyricsNotifier(this._yt) : super(const LyricsState());

  Future<void> fetchFor(String videoId) async {
    // Already loaded (or loading) for this video
    if (state.videoId == videoId) return;

    state = LyricsState(videoId: videoId, isLoading: true);

    try {
      final lines = await _yt.getLyrics(videoId);
      if (!mounted) return;
      state = LyricsState(
        videoId: videoId,
        isLoading: false,
        lines: lines,
        error: lines.isEmpty ? 'No lyrics available for this song.' : null,
      );
    } catch (e) {
      if (!mounted) return;
      state = LyricsState(
        videoId: videoId,
        isLoading: false,
        error: 'Failed to load lyrics: $e',
      );
    }
  }

  void clear() => state = const LyricsState();
}

// ─── Providers ───────────────────────────────────────────────────────────────

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((ref) {
  // Re-use the YoutubeService from audioHandlerProvider's service to avoid
  // creating a second YoutubeExplode instance — share via provider.
  final handler = ref.watch(audioHandlerProvider);
  return LyricsNotifier(handler.service.youtubeService);
});

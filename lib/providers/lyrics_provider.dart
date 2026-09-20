// ============================================================
// providers/lyrics_provider.dart
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/youtube_service.dart';
import 'player_provider.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class LyricsState {
  final String? videoId;
  final bool isLoading;
  final String? error;
  final List<LyricLine> lines;

  // Available caption tracks for the current video (empty = only one/none)
  final List<CaptionTrackInfo> availableTracks;
  // The currently selected track code (null = default auto-pick)
  final String? selectedTrackCode;

  const LyricsState({
    this.videoId,
    this.isLoading = false,
    this.error,
    this.lines = const [],
    this.availableTracks = const [],
    this.selectedTrackCode,
  });

  bool get hasLyrics => lines.isNotEmpty;

  /// The label of the currently selected track, or null.
  String? get selectedTrackLabel => availableTracks
      .where((t) => t.code == selectedTrackCode)
      .map((t) => t.label)
      .firstOrNull;

  LyricsState copyWith({
    String? videoId,
    bool? isLoading,
    String? error,
    List<LyricLine>? lines,
    List<CaptionTrackInfo>? availableTracks,
    String? selectedTrackCode,
    bool clearError = false,
    bool clearSelectedTrack = false,
  }) {
    return LyricsState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lines: lines ?? this.lines,
      availableTracks: availableTracks ?? this.availableTracks,
      selectedTrackCode: clearSelectedTrack
          ? null
          : (selectedTrackCode ?? this.selectedTrackCode),
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class LyricsNotifier extends StateNotifier<LyricsState> {
  final YoutubeService _yt;

  LyricsNotifier(this._yt) : super(const LyricsState());

  /// Fetch lyrics for a new video (auto-picks best track, loads available tracks).
  Future<void> fetchFor(String videoId) async {
    if (state.videoId == videoId && !state.isLoading && (state.hasLyrics || state.error != null)) return;

    state = LyricsState(videoId: videoId, isLoading: true);

    try {
      // Load available tracks and default lyrics in parallel
      final results = await Future.wait([
        _yt.getLyrics(videoId),
        _yt.getAvailableCaptionTracks(videoId),
      ]);

      if (!mounted) return;

      final lines  = results[0] as List<LyricLine>;
      final tracks = results[1] as List<CaptionTrackInfo>;

      // Find which track was auto-selected (prefer English)
      String? autoCode;
      if (tracks.isNotEmpty) {
        final eng = tracks.where((t) => t.code.startsWith('en')).firstOrNull;
        autoCode = (eng ?? tracks.first).code;
      }

      state = LyricsState(
        videoId: videoId,
        isLoading: false,
        lines: lines,
        availableTracks: tracks,
        selectedTrackCode: autoCode,
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

  /// Switch to a different caption track.
  Future<void> selectTrack(String languageCode) async {
    final videoId = state.videoId;
    if (videoId == null) return;
    if (state.selectedTrackCode == languageCode) return;

    state = state.copyWith(isLoading: true, selectedTrackCode: languageCode);

    try {
      final lines = await _yt.getLyricsForTrack(videoId, languageCode);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        lines: lines,
        selectedTrackCode: languageCode,
        error: lines.isEmpty ? 'No lyrics for this track.' : null,
        clearError: lines.isNotEmpty,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load track: $e',
      );
    }
  }

  void clear() => state = const LyricsState();
}

// ─── Providers ───────────────────────────────────────────────────────────────

final lyricsProvider =
    StateNotifierProvider<LyricsNotifier, LyricsState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return LyricsNotifier(handler.service.youtubeService);
});

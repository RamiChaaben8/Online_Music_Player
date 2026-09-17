// ============================================================
// providers/player_provider.dart
//
// Central playback state provider.
// Exposes current song, play/pause state, queue, position, etc.
// Delegates actual audio work to AudioPlayerService.
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/youtube_service.dart';
import 'youtube_provider.dart';
import 'library_provider.dart';

// ─── State class ─────────────────────────────────────────────────────────────

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final Duration position;
  final Duration duration;
  final List<Song> queue;
  final int currentIndex;
  final bool shuffle;
  final LoopMode loopMode;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.shuffle = false,
    this.loopMode = LoopMode.off,
  });

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    Duration? position,
    Duration? duration,
    List<Song>? queue,
    int? currentIndex,
    bool? shuffle,
    LoopMode? loopMode,
    bool clearSong = false,
    bool clearError = false,
  }) {
    return PlayerState(
      currentSong: clearSong ? null : (currentSong ?? this.currentSong),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffle: shuffle ?? this.shuffle,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayerService _service;
  final LibraryNotifier _library;

  final List<StreamSubscription> _subs = [];

  PlayerNotifier(this._service, this._library) : super(const PlayerState()) {
    _subscribeToPlayerStreams();
  }

  void _subscribeToPlayerStreams() {
    // Position updates
    _subs.add(_service.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    }));

    // Duration updates
    _subs.add(_service.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    }));

    // Play/pause + loading state
    _subs.add(_service.playerStateStream.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        isLoading: ps.processingState == ProcessingState.loading ||
            ps.processingState == ProcessingState.buffering,
      );
    }));

    // Async errors from fire-and-forget setAudioSource calls
    _subs.add(_service.errorStream.listen((msg) {
      state = state.copyWith(isLoading: false, error: msg);
    }));
  }

  /// Start playing [song], optionally with a surrounding [queue].
  ///
  /// Returns immediately after updating UI state — URL resolution and
  /// buffering happen in the background so the Now Playing screen opens
  /// with zero perceived delay. Progress is reflected via playerStateStream.
  void playSong(Song song, {List<Song>? queue}) {
    // Update UI instantly: show the song + loading spinner right away.
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      isPlaying: false,
      clearError: true,
    );

    // Fire URL resolution + audio load without blocking the caller.
    _service.playSong(song, queue: queue).then((_) {
      state = state.copyWith(
        currentSong: _service.currentSong,
        queue: _service.queue,
        currentIndex: _service.currentIndex,
      );
      // Fire-and-forget Hive write — never block playback on disk I/O.
      _library.addToRecentlyPlayed(song).catchError((_) {});
    }).catchError((e) {
      state = state.copyWith(
        isLoading: false,
        error: e is YoutubeServiceException ? e.message : 'Playback failed: $e',
      );
    });
  }

  Future<void> play() async {
    await _service.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> pause() async {
    await _service.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => _service.seek(position);

  Future<void> skipToNext() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.skipToNext();
    state = state.copyWith(
      currentSong: _service.currentSong,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
    if (_service.currentSong != null) {
      // Fire-and-forget — don't block on Hive write
      _library.addToRecentlyPlayed(_service.currentSong!).catchError((_) {});
    }
  }

  Future<void> skipToPrevious() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.skipToPrevious();
    state = state.copyWith(
      currentSong: _service.currentSong,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
  }

  void addToQueue(Song song) {
    _service.addToQueue(song);
    state = state.copyWith(queue: _service.queue);
  }

  void playNext(Song song) {
    _service.playNext(song);
    state = state.copyWith(queue: _service.queue);
  }

  void removeFromQueue(int index) {
    _service.removeFromQueue(index);
    state = state.copyWith(queue: _service.queue);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _service.reorderQueue(oldIndex, newIndex);
    state = state.copyWith(
      queue: _service.queue,
      currentIndex: _service.currentIndex,
    );
  }

  void toggleShuffle() {
    _service.toggleShuffle();
    state = state.copyWith(shuffle: _service.shuffle);
  }

  void toggleLoopMode() {
    _service.toggleLoopMode();
    state = state.copyWith(loopMode: _service.loopMode);
  }

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _service.dispose();
    super.dispose();
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final youtube = ref.watch(youtubeServiceProvider);
  final service = AudioPlayerService(youtube);
  ref.onDispose(service.dispose);
  return service;
});

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(
    ref.watch(audioPlayerServiceProvider),
    ref.watch(libraryProvider.notifier),
  );
});

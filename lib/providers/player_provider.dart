// ============================================================
// providers/player_provider.dart
//
// Central playback state provider.
// ALL playback is delegated to TuneifyAudioHandler so that
// audio_service starts its foreground service and the OS
// notification + lock-screen controls appear correctly.
// ============================================================

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/audio_handler.dart';
import '../services/audio_player_service.dart';
import '../services/youtube_service.dart';
import 'library_provider.dart';

const _marqueeChannel = MethodChannel('com.example.testf/marquee');

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
  // The handler IS the single audio authority — it owns AudioPlayerService
  // internally and drives the OS notification / foreground service.
  final TuneifyAudioHandler _handler;
  final LibraryNotifier _library;

  // Convenience getter — exposes the underlying service for stream access
  AudioPlayerService get _service => _handler.service;

  final List<StreamSubscription> _subs = [];

  PlayerNotifier(this._handler, this._library) : super(const PlayerState()) {
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

    // Play/pause + loading state + marquee icon sync
    _subs.add(_service.playerStateStream.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        isLoading: ps.processingState == ProcessingState.loading ||
            ps.processingState == ProcessingState.buffering,
      );
      if (!state.isLoading) _pushMarquee();
    }));

    // Async errors from fire-and-forget setAudioSource calls
    _subs.add(_service.errorStream.listen((msg) {
      state = state.copyWith(isLoading: false, error: msg);
    }));

    // Song changes triggered internally by the service (auto-next, etc.)
    // This ensures the UI (thumbnail, title, marquee) updates immediately.
    _subs.add(_service.songChangeStream.listen((song) {
      state = state.copyWith(
        currentSong: song,
        currentIndex: _service.currentIndex,
        queue: _service.queue,
        isLoading: true,
        isPlaying: false,
        clearError: true,
      );
      _handler.updateCurrentSong();
      _pushMarquee();
      _library.addToRecentlyPlayed(song).catchError((_) {});
    }));
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  void playSong(Song song, {List<Song>? queue}) {
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      isPlaying: false,
      clearError: true,
    );

    _service.playSong(song, queue: queue).then((_) {
      state = state.copyWith(
        currentSong: _service.currentSong,
        queue: _service.queue,
        currentIndex: _service.currentIndex,
      );
      // Tell the handler to push the new MediaItem to the notification
      _handler.updateCurrentSong();
      _pushMarquee();
      _library.addToRecentlyPlayed(song).catchError((_) {});
    }).catchError((e) {
      state = state.copyWith(
        isLoading: false,
        error: e is YoutubeServiceException ? e.message : 'Playback failed: $e',
      );
    });
  }

  Future<void> play() async {
    await _handler.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> pause() async {
    await _handler.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> skipToNext() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _handler.skipToNext();
    state = state.copyWith(
      currentSong: _service.currentSong,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
    _handler.updateCurrentSong();
    _pushMarquee();
    if (_service.currentSong != null) {
      _library.addToRecentlyPlayed(_service.currentSong!).catchError((_) {});
    }
  }

  Future<void> skipToPrevious() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _handler.skipToPrevious();
    state = state.copyWith(
      currentSong: _service.currentSong,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
    _handler.updateCurrentSong();
    _pushMarquee();
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

  /// The song that will play after the current one, or null.
  Song? get nextSong {
    final q = state.queue;
    final idx = state.currentIndex;
    if (q.length <= 1 || idx < 0) return null;
    return q[(idx + 1) % q.length];
  }

  // ── Marquee notification ──────────────────────────────────────────────

  /// Posts to the native MarqueeNotificationHelper via MethodChannel.
  /// Called from the main UI isolate — the only place MethodChannel works.
  void _pushMarquee() {
    final song = state.currentSong;
    if (song == null) return;
    final next = nextSong;
    final nextLine = next != null ? 'Next: ${next.title}' : '';
    _marqueeChannel.invokeMethod<void>('update', {
      'title':     song.title,
      'artist':    song.channelName,
      'nextLine':  nextLine,
      'artUrl':    song.thumbnailUrl,
      'isPlaying': state.isPlaying,
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Holds the single TuneifyAudioHandler instance created in main().
/// Overridden in ProviderScope so the same object is shared everywhere.
final audioHandlerProvider = Provider<TuneifyAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(
    ref.watch(audioHandlerProvider),
    ref.watch(libraryProvider.notifier),
  );
});

// ============================================================
// providers/player_provider.dart
//
// Central playback state provider.
//
// Active-device model (Spotify-style)
// ─────────────────────────────────────────────────────────────
// • Only the ACTIVE device loads audio and executes commands.
// • Passive devices: show a device-picker banner; tap "Listen
//   here" to become active.
// • A device becomes active by calling claimAsActiveDevice().
// • On first app open with no active device, this device
//   auto-claims (becomes active).
// • On second open when another device is already active, this
//   device stays passive — no audio load, no loop.
//
// Key rules
// ─────────────────────────────────────────────────────────────
// • All transport calls go to _service, never _handler.
//   Handler callbacks (onPlay/onPause/…) are OS-button routing:
//   OS → handler override → notifier method → service.
// • _sendCommand() only fires from explicit user actions.
// • _applyingRemote flag prevents songChangeStream from echoing
//   remote-triggered loads back to Firestore.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../services/audio_handler.dart';
import '../services/audio_player_service.dart';
import '../services/youtube_service.dart';
import '../services/sync_service.dart';
import '../services/firestore_service.dart';
import 'library_provider.dart';
import 'sync_provider.dart';

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

  /// Non-null while another device's command is visible in the banner.
  final RemoteCommandDoc? remoteCommand;

  /// The currently active device (null = no one active yet).
  final ActiveDeviceDoc? activeDevice;

  /// Whether THIS device is the active playback device.
  final bool isActiveDevice;

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
    this.remoteCommand,
    this.activeDevice,
    this.isActiveDevice = false,
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
    RemoteCommandDoc? remoteCommand,
    ActiveDeviceDoc? activeDevice,
    bool? isActiveDevice,
    bool clearSong = false,
    bool clearError = false,
    bool clearRemote = false,
    bool clearActiveDevice = false,
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
      remoteCommand: clearRemote ? null : (remoteCommand ?? this.remoteCommand),
      activeDevice: clearActiveDevice ? null : (activeDevice ?? this.activeDevice),
      isActiveDevice: isActiveDevice ?? this.isActiveDevice,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PlayerNotifier extends StateNotifier<PlayerState> {
  final TuneifyAudioHandler _handler;
  final LibraryNotifier _library;
  final SyncNotifier _sync;

  AudioPlayerService get _service => _handler.service;

  final List<StreamSubscription> _subs = [];

  /// True while a remote-triggered load is in progress.
  bool _applyingRemote = false;

  PlayerNotifier(this._handler, this._library, this._sync)
      : super(const PlayerState()) {
    _subscribeToPlayerStreams();
    _subscribeToRemoteCommands();
    _subscribeToActiveDevice();
    // Wire OS media-button callbacks.
    _handler.onPlay           = () => play();
    _handler.onPause          = () => pause();
    _handler.onSkipToNext     = () => skipToNext();
    _handler.onSkipToPrevious = () => skipToPrevious();
    _handler.onSeek           = (pos) => seek(pos);
  }

  // ── Internal stream subscriptions ────────────────────────────────────────

  void _subscribeToPlayerStreams() {
    _subs.add(_service.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    }));

    _subs.add(_service.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    }));

    _subs.add(_service.playerStateStream.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        isLoading: ps.processingState == ProcessingState.loading ||
            ps.processingState == ProcessingState.buffering,
      );
      if (!state.isLoading) _pushMarquee();
    }));

    _subs.add(_service.errorStream.listen((msg) {
      state = state.copyWith(isLoading: false, error: msg);
    }));

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

      if (!_applyingRemote) {
        _library.addToRecentlyPlayed(song).catchError((_) {});
        _sendCommand(RemoteCommand.playSong);
      }
    }));
  }

  void _subscribeToRemoteCommands() {
    _subs.add(_sync.service.remoteCommandStream.listen(_onRemoteCommand));
  }

  void _subscribeToActiveDevice() {
    _subs.add(_sync.service.activeDeviceStream.listen((doc) {
      final isActive = doc?.deviceId == _sync.service.deviceId;
      state = state.copyWith(activeDevice: doc, isActiveDevice: isActive);
    }));
  }

  // ── Remote command handler — only fires on active device ──────────────────

  void _onRemoteCommand(RemoteCommandDoc doc) {
    // SyncService already filters to active device only.
    state = state.copyWith(remoteCommand: doc);

    switch (doc.command) {
      case RemoteCommand.play:
        if (state.currentSong != null) {
          _service.play().catchError((_) {});
          state = state.copyWith(isPlaying: true);
        } else if (doc.currentSong != null) {
          _applyRemotePlaySong(doc);
        }
      case RemoteCommand.pause:
        _service.pause().catchError((_) {});
        state = state.copyWith(isPlaying: false);
      case RemoteCommand.next:
        _applyRemoteSkip(skipForward: true, doc: doc);
      case RemoteCommand.prev:
        _applyRemoteSkip(skipForward: false, doc: doc);
      case RemoteCommand.playSong:
        _applyRemotePlaySong(doc);
      case RemoteCommand.none:
        break;
    }
  }

  void _applyRemoteSkip({required bool skipForward, required RemoteCommandDoc doc}) {
    _applyingRemote = true;
    final fut = skipForward ? _service.skipToNext() : _service.skipToPrevious();
    fut.then((_) {
      if (!mounted) return;
      _updateFromService();
      _handler.updateCurrentSong();
      _pushMarquee();
    }).catchError((_) {}).whenComplete(() => _applyingRemote = false);
  }

  void _applyRemotePlaySong(RemoteCommandDoc doc) {
    final song = doc.currentSong;
    if (song == null) return;

    _applyingRemote = true;
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      isPlaying: false,
      clearError: true,
    );

    _service.playSong(song, queue: doc.queue).then((_) {
      if (!mounted) return;
      _updateFromService();
      _handler.updateCurrentSong();
      _pushMarquee();
    }).catchError((e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e is YoutubeServiceException ? e.message : 'Playback failed: $e',
      );
    }).whenComplete(() => _applyingRemote = false);
  }

  void _updateFromService() {
    state = state.copyWith(
      currentSong: _service.currentSong,
      queue: _service.queue,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
  }

  // ── Sync helper ───────────────────────────────────────────────────────────

  void _sendCommand(RemoteCommand command) {
    _sync.service.sendCommand(
      command: command,
      currentSong: state.currentSong,
      queue: state.queue,
      queueIndex: state.currentIndex,
    ).catchError((_) {});
  }

  // ── Active device management ──────────────────────────────────────────────

  /// Called by DevicePickerSheet when user taps "Listen here".
  /// Claims this device as active and restores the last session.
  Future<void> listenHere() async {
    await _sync.service.claimAsActiveDevice();
    state = state.copyWith(isActiveDevice: true);
    await restoreLastSession();
  }

  // ── Restore on login ─────────────────────────────────────────────────────

  /// Called after login. Only runs if this device is the active device.
  Future<void> restoreLastSession() async {
    if (!_sync.service.isActive) return; // passive device — do nothing
    try {
      final doc = await _sync.service.getLastState();
      if (doc == null || doc.currentSong == null) return;
      if (!mounted) return;

      final song = doc.currentSong!;

      _applyingRemote = true;
      state = state.copyWith(
        currentSong: song,
        isLoading: true,
        isPlaying: false,
        clearError: true,
      );

      await _service.playSong(song, queue: doc.queue);
      await _service.pause();

      if (!mounted) {
        _applyingRemote = false;
        return;
      }

      state = state.copyWith(
        currentSong: _service.currentSong ?? song,
        queue: _service.queue,
        currentIndex: _service.currentIndex,
        isLoading: false,
        isPlaying: false,
      );
      _handler.updateCurrentSong();
      _pushMarquee();
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    } finally {
      _applyingRemote = false;
    }
  }

  // ── Dismiss banner ────────────────────────────────────────────────────────

  void dismissRemoteBanner() => state = state.copyWith(clearRemote: true);

  // ── Playback ─────────────────────────────────────────────────────────────

  void playSong(Song song, {List<Song>? queue}) {
    // If this device is passive, claim it first.
    if (!state.isActiveDevice) {
      _sync.service.claimAsActiveDevice().then((_) {
        if (!mounted) return;
        state = state.copyWith(isActiveDevice: true);
        _doPlaySong(song, queue: queue);
      });
      return;
    }
    _doPlaySong(song, queue: queue);
  }

  void _doPlaySong(Song song, {List<Song>? queue}) {
    state = state.copyWith(
      currentSong: song,
      isLoading: true,
      isPlaying: false,
      clearError: true,
      clearRemote: true,
    );

    _service.playSong(song, queue: queue).then((_) {
      if (!mounted) return;
      state = state.copyWith(
        currentSong: _service.currentSong,
        queue: _service.queue,
        currentIndex: _service.currentIndex,
      );
      _handler.updateCurrentSong();
      _pushMarquee();
      _library.addToRecentlyPlayed(song).catchError((_) {});
      _sendCommand(RemoteCommand.playSong);
    }).catchError((e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e is YoutubeServiceException ? e.message : 'Playback failed: $e',
      );
    });
  }

  Future<void> play() async {
    await _service.play();
    state = state.copyWith(isPlaying: true);
    _handler.updateCurrentSong();
    _sendCommand(RemoteCommand.play);
  }

  Future<void> pause() async {
    await _service.pause();
    state = state.copyWith(isPlaying: false);
    _sendCommand(RemoteCommand.pause);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position);
  }

  Future<void> skipToNext() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.skipToNext();
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
    _sendCommand(RemoteCommand.next);
  }

  Future<void> skipToPrevious() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.skipToPrevious();
    state = state.copyWith(
      currentSong: _service.currentSong,
      currentIndex: _service.currentIndex,
      isLoading: false,
    );
    _handler.updateCurrentSong();
    _pushMarquee();
    _sendCommand(RemoteCommand.prev);
  }

  void addToQueue(Song song) {
    _service.addToQueue(song);
    state = state.copyWith(queue: _service.queue);
    _sendCommand(RemoteCommand.playSong);
  }

  void playNext(Song song) {
    _service.playNext(song);
    state = state.copyWith(queue: _service.queue);
    _sendCommand(RemoteCommand.playSong);
  }

  void removeFromQueue(int index) {
    _service.removeFromQueue(index);
    state = state.copyWith(queue: _service.queue);
    _sendCommand(RemoteCommand.playSong);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _service.reorderQueue(oldIndex, newIndex);
    state = state.copyWith(
      queue: _service.queue,
      currentIndex: _service.currentIndex,
    );
    _sendCommand(RemoteCommand.playSong);
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

  Song? get nextSong {
    final q = state.queue;
    final idx = state.currentIndex;
    if (q.length <= 1 || idx < 0) return null;
    return q[(idx + 1) % q.length];
  }

  // ── Marquee notification (Android only) ──────────────────────────────────

  void _pushMarquee() {
    if (!Platform.isAndroid) return;
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
    _handler.onPlay           = null;
    _handler.onPause          = null;
    _handler.onSkipToNext     = null;
    _handler.onSkipToPrevious = null;
    _handler.onSeek           = null;
    super.dispose();
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final audioHandlerProvider = Provider<TuneifyAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(
    ref.watch(audioHandlerProvider),
    ref.watch(libraryProvider.notifier),
    ref.watch(syncProvider.notifier),
  );
});

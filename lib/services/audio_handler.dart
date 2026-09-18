// ============================================================
// services/audio_handler.dart
// ============================================================

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'audio_player_service.dart';

class TuneifyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _service;
  final List<StreamSubscription> _subs = [];

  AudioPlayerService get service => _service;

  TuneifyAudioHandler(this._service) {
    _subs.add(_service.playerStateStream.listen(_onPlayerState));

    _subs.add(_service.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    }));

    _subs.add(_service.durationStream.listen((dur) {
      if (dur == null) return;
      final item = mediaItem.value;
      if (item != null) mediaItem.add(item.copyWith(duration: dur));
    }));

    _subs.add(_service.currentIndexStream.listen((_) {
      updateCurrentSong();
    }));

    _pushPlaybackState(
      playing: false,
      processingState: AudioProcessingState.idle,
    );
  }

  void _onPlayerState(PlayerState ps) {
    _pushPlaybackState(
      playing: ps.playing,
      processingState: _mapProcessingState(ps.processingState),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState ps) {
    switch (ps) {
      case ProcessingState.idle:       return AudioProcessingState.idle;
      case ProcessingState.loading:    return AudioProcessingState.loading;
      case ProcessingState.buffering:  return AudioProcessingState.buffering;
      case ProcessingState.ready:      return AudioProcessingState.ready;
      case ProcessingState.completed:  return AudioProcessingState.completed;
    }
  }

  void _pushPlaybackState({
    required bool playing,
    required AudioProcessingState processingState,
  }) {
    final queue = _service.queue;
    final idx   = _service.currentIndex;

    playbackState.add(PlaybackState(
      controls: [
        const MediaControl(
          androidIcon: 'drawable/ic_skip_previous',
          label: 'Previous',
          action: MediaAction.skipToPrevious,
        ),
        if (playing)
          const MediaControl(
            androidIcon: 'drawable/ic_pause',
            label: 'Pause',
            action: MediaAction.pause,
          )
        else
          const MediaControl(
            androidIcon: 'drawable/ic_play_arrow',
            label: 'Play',
            action: MediaAction.play,
          ),
        const MediaControl(
          androidIcon: 'drawable/ic_skip_next',
          label: 'Next',
          action: MediaAction.skipToNext,
        ),
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _service.player.position,
      bufferedPosition: _service.player.bufferedPosition,
      speed: _service.player.speed,
      queueIndex: idx >= 0 ? idx : null,
    ));
  }

  void updateCurrentSong() {
    final queue = _service.queue;
    final idx   = _service.currentIndex;
    if (idx < 0 || idx >= queue.length) return;

    final current = queue[idx];
    final next    = queue.length > 1 ? queue[(idx + 1) % queue.length] : null;

    final item = MediaItem(
      id: current.id,
      // Keep title and artist separate so Android can scroll/show them properly
      title: current.title,
      artist: current.channelName,
      album: next != null ? 'Next: ${next.title}' : 'Tuneify',
      artUri: current.thumbnailUrl.isNotEmpty
          ? Uri.parse(current.thumbnailUrl) : null,
      duration: current.duration == Duration.zero ? null : current.duration,
      extras: next != null ? {
        'nextSongId':     next.id,
        'nextSongTitle':  next.title,
        'nextSongArtist': next.channelName,
        'nextSongArt':    next.thumbnailUrl,
      } : null,
    );

    mediaItem.add(item);

    this.queue.add(queue.map((s) => MediaItem(
      id: s.id,
      title: s.title,
      artist: s.channelName,
      artUri: s.thumbnailUrl.isNotEmpty ? Uri.parse(s.thumbnailUrl) : null,
    )).toList());
  }

  Song? get nextSong {
    final q   = _service.queue;
    final idx = _service.currentIndex;
    if (q.length <= 1 || idx < 0) return null;
    return q[(idx + 1) % q.length];
  }

  @override Future<void> play()   => _service.play();
  @override Future<void> pause()  => _service.pause();
  @override Future<void> seek(Duration position) => _service.seek(position);
  @override Future<void> skipToNext()     => _service.skipToNext();
  @override Future<void> skipToPrevious() => _service.skipToPrevious();

  @override
  Future<void> stop() async {
    await _service.pause();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final q = _service.queue;
    if (index < 0 || index >= q.length) return;
    await _service.playSong(q[index], queue: q);
  }

  void disposeHandler() {
    for (final s in _subs) s.cancel();
  }
}

// ============================================================
// services/audio_player_service.dart
// ============================================================

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'youtube_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer(
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
  );
  final YoutubeService _youtube;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;

  StreamSubscription<PlayerState>? _completionSub;

  /// Exposed so PlayerNotifier can listen for async load errors that occur
  /// after _loadAndPlay returns (e.g. setAudioSource fails mid-buffer).
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  AudioPlayerService(this._youtube);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  AudioPlayer get player => _player;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;

  // ── Public playback API ───────────────────────────────────────────────────

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      if (!_queue.any((s) => s.id == song.id)) {
        _queue = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }
    }
    await _loadAndPlay(_currentIndex);
  }

  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) _queue.add(song);
  }

  void playNext(Song song) {
    _queue.removeWhere((s) => s.id == song.id);
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    final next = _shuffle
        ? (DateTime.now().millisecondsSinceEpoch % _queue.length)
        : (_currentIndex + 1) % _queue.length;
    _currentIndex = next;
    await _loadAndPlay(_currentIndex);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _loadAndPlay(_currentIndex);
  }

  void toggleShuffle() => _shuffle = !_shuffle;

  void toggleLoopMode() {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
        _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        _loopMode = LoopMode.one;
        _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        _loopMode = LoopMode.off;
        _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  // ── Core load logic ───────────────────────────────────────────────────────

  /// Resolves the stream URL (fast if prefetched), then starts playback.
  ///
  /// Speed strategy:
  ///  1. getAudioStreamUrl() returns immediately when the URL was prefetched.
  ///  2. setAudioSource() + play() are called without awaiting setAudioSource —
  ///     just_audio starts buffering and plays as soon as the first bytes arrive.
  ///     This cuts perceived latency because the Now Playing screen opens and
  ///     the spinner shows instantly rather than after the entire source load.
  ///  3. Any error from setAudioSource is forwarded to [errorStream] so the
  ///     UI can still show it (since we can't rethrow from a fire-and-forget).
  Future<void> _loadAndPlay(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];

    await _completionSub?.cancel();
    _completionSub = null;

    // Step 1: resolve URL — this is the only truly async step.
    // Returns instantly when prefetch already ran; ~2–4 s on first tap otherwise.
    final streamUrl = await _youtube.getAudioStreamUrl(song.id);

    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.channelName,
      duration: song.duration,
      artUri: Uri.parse(song.thumbnailUrl),
    );

    // Step 2: hand the source to just_audio and immediately call play().
    // We do NOT await setAudioSource — just_audio queues the play() command
    // and executes it as soon as the source is ready. The player transitions
    // through loading → buffering → playing automatically.
    _player
        .setAudioSource(
          AudioSource.uri(
            Uri.parse(streamUrl),
            tag: mediaItem,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/114.0.0.0 Safari/537.36',
            },
          ),
        )
        .then((_) => _player.play())
        .catchError((e) {
          // Surface the error through the broadcast stream so PlayerNotifier
          // can update its state even though we didn't await this future.
          _errorController.add(
            e is YoutubeServiceException ? e.message : 'Playback failed: $e',
          );
        });

    // Step 3: prefetch the next song while this one buffers
    _prefetchNext();

    // Step 4: auto-advance when track finishes
    _completionSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed &&
          _loopMode != LoopMode.one) {
        skipToNext();
      }
    });
  }

  void _prefetchNext() {
    if (_queue.length <= 1) return;
    final nextIndex = (_currentIndex + 1) % _queue.length;
    if (nextIndex == _currentIndex) return;
    _youtube.prefetchUrl(_queue[nextIndex].id);
  }

  void dispose() {
    _completionSub?.cancel();
    _errorController.close();
    _player.dispose();
    _youtube.dispose();
  }
}

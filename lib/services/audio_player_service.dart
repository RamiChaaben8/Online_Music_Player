// ============================================================
// services/audio_player_service.dart
//
// Wraps just_audio + just_audio_background.
// Handles:
//  - Playback of a single song
//  - Queue management (skip, previous, shuffle, repeat)
//  - Stream URL refresh when URLs expire
//  - Background/lock-screen media controls via AudioServiceTask
// ============================================================

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'youtube_service.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer(
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
  );
  final YoutubeService _youtube;

  // Current queue managed by this service
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;

  AudioPlayerService(this._youtube);

  // ── Expose underlying player streams ──────────────────────────────────────

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
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;

  // ── Playback control ──────────────────────────────────────────────────────

  /// Play [song] immediately, optionally replacing the queue.
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else {
      // If queue is empty or song not in queue, reset to single-song queue
      if (!_queue.any((s) => s.id == song.id)) {
        _queue = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }
    }

    await _loadAndPlay(_currentIndex);
  }

  /// Add [song] to end of queue.
  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
    }
  }

  /// Insert [song] right after the current track (play next).
  void playNext(Song song) {
    _queue.removeWhere((s) => s.id == song.id);
    final insertAt = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertAt, song);
  }

  /// Remove a song from the queue by index.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
  }

  /// Reorder queue: move item from [oldIndex] to [newIndex].
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
    int next;
    if (_shuffle) {
      next = (DateTime.now().millisecondsSinceEpoch % _queue.length);
    } else {
      next = (_currentIndex + 1) % _queue.length;
    }
    _currentIndex = next;
    await _loadAndPlay(_currentIndex);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    // If more than 3 seconds in, restart current song
    if ((_player.position.inSeconds) > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = (_currentIndex - 1 + _queue.length) % _queue.length;
    _currentIndex = prev;
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

  // ── Internal: load a song at [index] and start playing ───────────────────

  Future<void> _loadAndPlay(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];

    try {
      // Fetch a fresh stream URL (YouTube URLs expire ~6h)
      final streamUrl = await _youtube.getAudioStreamUrl(song.id);

      // Build MediaItem for the notification/lock-screen
      final mediaItem = MediaItem(
        id: song.id,
        title: song.title,
        artist: song.channelName,
        duration: song.duration,
        artUri: Uri.parse(song.thumbnailUrl),
      );

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: mediaItem,
        ),
      );

      await _player.play();

      // Auto-skip to next when track ends (unless looping one)
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed &&
            _loopMode != LoopMode.one) {
          skipToNext();
        }
      });
    } catch (e) {
      // Rethrow so the UI provider can catch and show an error
      rethrow;
    }
  }

  void dispose() {
    _player.dispose();
    _youtube.dispose();
  }
}

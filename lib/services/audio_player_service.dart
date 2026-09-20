// ============================================================
// services/audio_player_service.dart
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'download_service.dart';
import 'youtube_service.dart';

class AudioPlayerService {
  // Build platform-appropriate load config.
  // AndroidLoadControl must only be passed on Android — the type is harmless
  // to reference in Dart but passing it causes an assertion inside just_audio
  // on non-Android platforms.
  static AudioLoadConfiguration? _loadConfig() {
    if (Platform.isAndroid) {
      return const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 10),
          maxBufferDuration: Duration(seconds: 30),
          prioritizeTimeOverSizeThresholds: true,
          targetBufferBytes: 32 * 1024,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return const AudioLoadConfiguration(
        darwinLoadControl: DarwinLoadControl(
          preferredForwardBufferDuration: Duration(seconds: 5),
          automaticallyWaitsToMinimizeStalling: false,
        ),
      );
    }
    // Windows / Linux — media_kit backend, no load config needed.
    return null;
  }

  final AudioPlayer _player = AudioPlayer(
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
    audioLoadConfiguration: _loadConfig(),
  );

  final YoutubeService _youtube;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;

  StreamSubscription<PlayerState>? _completionSub;

  // Serial counter — incremented on every _loadAndPlay call.
  // Used by the setAudioSource callback to discard itself if superseded.
  int _loadSerial = 0;

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// Emits the new current song's id every time the track changes
  /// (auto-skip, manual skip, or play a new song).
  final StreamController<Song> _songChangeController =
      StreamController<Song>.broadcast();
  Stream<Song> get songChangeStream => _songChangeController.stream;

  AudioPlayerService(this._youtube);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  AudioPlayer get player => _player;
  YoutubeService get youtubeService => _youtube;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;

  // ── Public API ────────────────────────────────────────────────────────────

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

  // ── Core load ────────────────────────────────────────────────────────────

  Future<void> _loadAndPlay(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];

    _completionSub?.cancel();
    _completionSub = null;

    // Stamp this load. If another _loadAndPlay starts before setAudioSource
    // resolves, the stale callback will see a different serial and skip play().
    final mySerial = ++_loadSerial;

    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.channelName,
      duration: song.duration,
      artUri: song.thumbnailUrl.isNotEmpty ? Uri.parse(song.thumbnailUrl) : null,
    );

    AudioSource source;

    final localPath = song.isLocal && song.localPath != null
        ? song.localPath
        : await _findDownloadedFile(song);

    // After an await, check if we've been superseded.
    if (_loadSerial != mySerial) return;

    if (localPath != null) {
      source = AudioSource.file(localPath, tag: mediaItem);
    } else {
      final streamUrl = await _youtube.getAudioStreamUrl(song.id);
      if (_loadSerial != mySerial) return; // superseded during URL fetch
      _persistStreamUrl(song, streamUrl);

      source = AudioSource.uri(
        Uri.parse(streamUrl),
        tag: mediaItem,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/114.0.0.0 Safari/537.36',
        },
      );
    }

    // Await setAudioSource so errors surface correctly, then play if still current.
    try {
      await _player.setAudioSource(source, preload: true);
      if (_loadSerial == mySerial) {
        await _player.play();
      }
    } catch (e) {
      if (_loadSerial == mySerial) {
        _errorController.add(
          e is YoutubeServiceException ? e.message : 'Playback failed: $e',
        );
      }
      return;
    }

    // Only notify / prefetch / subscribe if this load is still current.
    if (_loadSerial != mySerial) return;

    _songChangeController.add(song);
    _prefetchNext();

    _completionSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed &&
          _loopMode != LoopMode.one) {
        skipToNext();
      }
    });
  }

  /// Checks the Tuneify download folder for a file matching this song's title.
  /// Returns the absolute path if found, null otherwise.
  Future<String?> _findDownloadedFile(Song song) async {
    try {
      final dir = await DownloadService.getTuneifyDir();
      if (!await dir.exists()) return null;

      final safeTitle = song.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Check both .mp4 (current) and .mp3 (legacy) extensions
      for (final ext in ['.mp4', '.mp3', '.m4a', '.webm']) {
        final f = File('${dir.path}/$safeTitle$ext');
        if (await f.exists()) return f.path;
      }
    } catch (_) {}
    return null;
  }

  /// Write the resolved stream URL back into the Song stored in Hive
  /// (liked_songs / recently_played) so cold starts can use it directly.
  void _persistStreamUrl(Song song, String url) {
    try {
      if (song.isInBox) {
        // Song is already a Hive object — update it in place
        final updated = song.copyWith(
          streamUrl: url,
          streamUrlFetchedAt: DateTime.now(),
        );
        song.box?.put(song.key, updated);
      }
    } catch (_) {
      // Non-critical — ignore failures silently
    }
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
    _songChangeController.close();
    _player.dispose();
    _youtube.dispose();
  }
}

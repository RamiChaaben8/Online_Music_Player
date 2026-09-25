// ============================================================
// services/audio_player_service.dart
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'download_service.dart';
import 'youtube_service.dart';

class AudioPlayerService {
  static const _streamAttemptTimeout = Duration(seconds: 7);
  static const _maxStreamsPerLoad = 3;
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
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
    audioLoadConfiguration: _loadConfig(),
  );

  final YoutubeService _youtube;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  List<Song>? _unshuffledQueue;
  final Set<int> _shufflePlayed = {};
  final Random _random = Random();
  LoopMode _loopMode = LoopMode.off;
  double _volume = 1.0;

  StreamSubscription<PlayerState>? _completionSub;
  StreamSubscription<PlaybackEvent>? _playbackErrorSub;
  Timer? _startupWatchdog;

  // Serial counter — incremented on every _loadAndPlay call.
  // Used by the setAudioSource callback to discard itself if superseded.
  int _loadSerial = 0;
  int? _recoveringSerial;

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// Emits the new current song's id every time the track changes
  /// (auto-skip, manual skip, or play a new song).
  final StreamController<Song> _songChangeController =
      StreamController<Song>.broadcast();
  Stream<Song> get songChangeStream => _songChangeController.stream;

  AudioPlayerService(this._youtube);

  double get volume => _volume;

  /// Restore the last local volume before the app starts accepting playback.
  Future<void> initialize() async {
    final settings = Hive.box('settings');
    final saved = settings.get('volume');
    if (saved is num) {
      _volume = saved.toDouble().clamp(0.0, 1.0);
    }
    await _player.setVolume(_volume);
  }

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

  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length)
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
      _unshuffledQueue = _shuffle ? List<Song>.from(_queue) : null;
      _shufflePlayed
        ..clear()
        ..add(_currentIndex);
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

  void setQueue(List<Song> queue, {int? currentIndex}) {
    _queue = List.from(queue);
    if (_shuffle) _unshuffledQueue = List<Song>.from(_queue);
    if (_queue.isEmpty) {
      _currentIndex = -1;
    } else if (currentIndex != null) {
      _currentIndex = currentIndex.clamp(0, _queue.length - 1);
    }
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
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    await Hive.box('settings').put('volume', _volume);
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    int next;
    if (_shuffle && _queue.length > 1) {
      var candidates = List<int>.generate(_queue.length, (index) => index)
          .where((index) => !_shufflePlayed.contains(index))
          .toList();
      if (candidates.isEmpty) {
        _shufflePlayed
          ..clear()
          ..add(_currentIndex);
        candidates = List<int>.generate(_queue.length, (index) => index)
            .where((index) => index != _currentIndex)
            .toList();
      }
      next = candidates[_random.nextInt(candidates.length)];
      _shufflePlayed.add(next);
    } else {
      next = (_currentIndex + 1) % _queue.length;
    }
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

  void toggleShuffle() {
    if (!_shuffle) {
      _unshuffledQueue = List<Song>.from(_queue);
      // Keep the current track where it is and shuffle only what is still
      // ahead, so enabling shuffle never interrupts the song already playing.
      for (var i = _queue.length - 1; i > _currentIndex + 1; i--) {
        final j = _currentIndex + 1 + _random.nextInt(i - _currentIndex);
        final song = _queue[i];
        _queue[i] = _queue[j];
        _queue[j] = song;
      }
      _shuffle = true;
    } else {
      final currentId = currentSong?.id;
      final original = _unshuffledQueue;
      if (original != null) {
        _queue = List<Song>.from(original);
        final restoredIndex = currentId == null
            ? -1
            : _queue.indexWhere((song) => song.id == currentId);
        if (restoredIndex >= 0) _currentIndex = restoredIndex;
      }
      _unshuffledQueue = null;
      _shuffle = false;
    }
    _shufflePlayed
      ..clear()
      ..addAll(_shuffle && _currentIndex >= 0
          ? Iterable<int>.generate(_currentIndex + 1)
          : [_currentIndex]);
  }

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

  Future<void> _loadAndPlay(
    int index, {
    Set<String> failedStreamUrls = const {},
  }) async {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];
    _youtube.seedFromSong(song);

    _completionSub?.cancel();
    _completionSub = null;
    _playbackErrorSub?.cancel();
    _playbackErrorSub = null;
    _startupWatchdog?.cancel();
    _startupWatchdog = null;

    // Stamp this load. If another _loadAndPlay starts before setAudioSource
    // resolves, the stale callback will see a different serial and skip play().
    final mySerial = ++_loadSerial;

    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.channelName,
      duration: song.duration,
      artUri:
          song.thumbnailUrl.isNotEmpty ? Uri.parse(song.thumbnailUrl) : null,
    );

    final localPath = song.isLocal && song.localPath != null
        ? song.localPath
        : await _findDownloadedFile(song);

    // After an await, check if we've been superseded.
    if (_loadSerial != mySerial) return;

    final isRemoteSource = localPath == null;
    final attemptedUrls = Set<String>.from(failedStreamUrls);
    String? activeStreamUrl;

    try {
      if (localPath != null) {
        await _player.setAudioSource(
          AudioSource.file(localPath, tag: mediaItem),
          preload: true,
        );
      } else {
        final cachedUrl = await _youtube
            .getAudioStreamUrl(song.id)
            .timeout(_streamAttemptTimeout);
        final candidates = <String>[cachedUrl];
        var candidatesFetched = false;
        if (attemptedUrls.contains(cachedUrl)) {
          candidates
            ..clear()
            ..addAll(await _youtube
                .getAudioStreamCandidates(song.id)
                .timeout(_streamAttemptTimeout));
          candidatesFetched = true;
        }

        Object? lastError;
        var loaded = false;
        for (final streamUrl in candidates) {
          if (attemptedUrls.length >= _maxStreamsPerLoad) break;
          if (!attemptedUrls.add(streamUrl)) continue;
          if (_loadSerial != mySerial) return;
          try {
            await _player.setAudioSource(
              _remoteAudioSource(streamUrl, mediaItem),
              preload: true,
            ).timeout(_streamAttemptTimeout);
            activeStreamUrl = streamUrl;
            _youtube.rememberAudioStreamUrl(song.id, streamUrl);
            _persistStreamUrl(song, streamUrl);
            loaded = true;
            break;
          } catch (error) {
            lastError = error;
          }
        }

        if (!loaded && attemptedUrls.length < _maxStreamsPerLoad) {
          final alternatives = candidatesFetched
              ? candidates
              : await _youtube
                  .getAudioStreamCandidates(song.id)
                  .timeout(_streamAttemptTimeout);
          for (final streamUrl in alternatives) {
            if (attemptedUrls.length >= _maxStreamsPerLoad) break;
            if (!attemptedUrls.add(streamUrl)) continue;
            if (_loadSerial != mySerial) return;
            try {
              await _player.setAudioSource(
                _remoteAudioSource(streamUrl, mediaItem),
                preload: true,
              ).timeout(_streamAttemptTimeout);
              activeStreamUrl = streamUrl;
              _youtube.rememberAudioStreamUrl(song.id, streamUrl);
              _persistStreamUrl(song, streamUrl);
              loaded = true;
              break;
            } catch (error) {
              lastError = error;
            }
          }
        }
        if (!loaded) {
          throw lastError ?? YoutubeServiceException(
            'No compatible audio stream could be opened for ${song.title}.',
          );
        }
      }
      _playbackErrorSub = _player.playbackEventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          _handlePlaybackError(
            index,
            mySerial,
            isRemoteSource,
            activeStreamUrl,
            attemptedUrls,
            error,
          );
        },
      );
      if (_loadSerial == mySerial) {
        // just_audio's play future stays pending until playback pauses or ends.
        // Do not block track-change notifications and next-track prefetch on it.
        unawaited(_player.play().catchError((Object error) {
          _handlePlaybackError(
            index,
            mySerial,
            isRemoteSource,
            activeStreamUrl,
            attemptedUrls,
            error,
          );
        }));
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
    _prefetchUpcoming();

    _completionSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed &&
          _loopMode != LoopMode.one) {
        skipToNext();
      }
    }, onError: (Object error, StackTrace stackTrace) {
      _handlePlaybackError(
        index,
        mySerial,
        isRemoteSource,
        activeStreamUrl,
        attemptedUrls,
        error,
      );
    });
    if (isRemoteSource) {
      _startupWatchdog = Timer(const Duration(seconds: 8), () {
        if (_loadSerial == mySerial &&
            _player.playing &&
            _player.position == Duration.zero) {
          _handlePlaybackError(
            index,
            mySerial,
            isRemoteSource,
            activeStreamUrl,
            attemptedUrls,
            TimeoutException('The audio stream did not start.'),
          );
        }
      });
    }
  }

  AudioSource _remoteAudioSource(String streamUrl, MediaItem mediaItem) {
    return AudioSource.uri(
      Uri.parse(streamUrl),
      tag: mediaItem,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/114.0.0.0 Safari/537.36',
      },
    );
  }

  void _handlePlaybackError(
    int index,
    int serial,
    bool isRemoteSource,
    String? activeStreamUrl,
    Set<String> attemptedUrls,
    Object error,
  ) {
    if (_loadSerial != serial) return;
    if (_recoveringSerial == serial) return;
    if (!isRemoteSource || attemptedUrls.length >= _maxStreamsPerLoad) {
      _player.pause().catchError((_) {});
      _errorController.add('Playback failed: $error');
      return;
    }

    _recoveringSerial = serial;
    unawaited(() async {
      try {
        final failed = Set<String>.from(attemptedUrls);
        if (activeStreamUrl != null) failed.add(activeStreamUrl);
        if (_loadSerial != serial) return;
        await _loadAndPlay(index, failedStreamUrls: failed);
      } catch (retryError) {
        if (_loadSerial == serial) {
          _errorController.add('Playback failed: $retryError');
        }
      } finally {
        if (_recoveringSerial == serial) _recoveringSerial = null;
      }
    }());
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

  void _prefetchUpcoming() {
    if (_queue.length <= 1) return;
    final ids = <String>[];
    for (var offset = 1; offset <= 2 && offset < _queue.length; offset++) {
      final song = _queue[(_currentIndex + offset) % _queue.length];
      if (song.id != _queue[_currentIndex].id) ids.add(song.id);
    }
    _youtube.prefetchBatch(ids, maxConcurrent: 2);
  }

  void dispose() {
    _completionSub?.cancel();
    _playbackErrorSub?.cancel();
    _startupWatchdog?.cancel();
    _errorController.close();
    _songChangeController.close();
    _player.dispose();
    _youtube.dispose();
  }
}

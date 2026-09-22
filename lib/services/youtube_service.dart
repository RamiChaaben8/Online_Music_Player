// ============================================================
// services/youtube_service.dart
//
// Two-level stream URL cache:
//   L1 — in-memory Map  (instant, lost on restart)
//   L2 — Hive box       (fast disk read, survives restarts)
//
// Resolution order on getAudioStreamUrl(id):
//   1. L1 hit  → return immediately (0 ms)
//   2. L2 hit  → populate L1, return (< 1 ms)
//   3. Miss    → fetch manifest (~2–4 s), write to both caches, return
//
// This means songs the user played before will start with zero manifest
// round-trip, exactly like YT Music's behaviour.
// ============================================================

import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

const _kTtl = Duration(hours: 5);
const _kHiveBox = 'stream_url_cache';

class _CachedUrl {
  final String url;
  final DateTime fetchedAt;
  _CachedUrl(this.url, this.fetchedAt);
  bool get isExpired => DateTime.now().difference(fetchedAt) > _kTtl;
}

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  // L1 — in-memory
  final Map<String, _CachedUrl> _mem = {};

  // In-flight deduplication
  final Map<String, Future<String>> _inflight = {};

  YoutubeExplode get yt => _yt;

  // ── Hive helpers ─────────────────────────────────────────────────────────

  Box get _hive => Hive.box(_kHiveBox);

  _CachedUrl? _readHive(String id) {
    final map = _hive.get(id);
    if (map == null) return null;
    final ts = map['ts'] as int?;
    final url = map['url'] as String?;
    if (ts == null || url == null || url.isEmpty) return null;
    return _CachedUrl(url, DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Future<void> _writeHive(String id, String url) async {
    await _hive.put(id, {
      'url': url,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ── Search ───────────────────────────────────────────────────────────────

  Future<List<Song>> search(String query, {int maxResults = 20}) async {
    try {
      final results = await _yt.search.search(query);
      return results.take(maxResults).map(_videoToSong).toList();
    } on VideoUnavailableException catch (e) {
      throw YoutubeServiceException('Video unavailable: ${e.message}');
    } catch (e) {
      throw YoutubeServiceException('Search failed: $e');
    }
  }

  /// Fetch a section of songs by a curated query string.
  /// Used for home feed sections (trending, new releases, mood, etc.)
  Future<List<Song>> searchSection(String query, {int maxResults = 10}) async {
    try {
      final results = await _yt.search.search(query);
      return results.take(maxResults).map(_videoToSong).toList();
    } catch (_) {
      return [];
    }
  }

  // ── URL resolution ────────────────────────────────────────────────────────

  Future<String> getAudioStreamUrl(String videoId) async {
    // L1 — memory
    final mem = _mem[videoId];
    if (mem != null && !mem.isExpired) return mem.url;

    // L2 — Hive (fast disk read, survives restarts)
    final hive = _readHive(videoId);
    if (hive != null && !hive.isExpired) {
      _mem[videoId] = hive; // promote to L1
      return hive.url;
    }

    // Already fetching — reuse the same Future
    if (_inflight.containsKey(videoId)) return _inflight[videoId]!;

    final future = _fetchAndCache(videoId);
    _inflight[videoId] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(videoId);
    }

  }

  /// Resolves an audio-only stream for downloads. Playback keeps using the
  /// cached muxed stream because it is supported consistently by just_audio.
  Future<String> getAudioOnlyStreamUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    var streams =
        manifest.audioOnly.where((s) => s.container.name == 'mp4').toList();
    if (streams.isEmpty) streams = manifest.audioOnly.toList();
    if (streams.isEmpty) {
      throw YoutubeServiceException('No audio-only stream found for $videoId');
    }
    streams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return streams.first.url.toString();
  }

  Future<String> _fetchAndCache(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      var streams = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (streams.isEmpty) streams = manifest.muxed.toList();
      if (streams.isEmpty) {
        throw YoutubeServiceException('No streams found for $videoId');
      }

      streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final url = streams.first.url.toString();

      // Write to both caches
      final cached = _CachedUrl(url, DateTime.now());
      _mem[videoId] = cached;
      _writeHive(videoId, url).catchError((_) {}); // non-blocking disk write

      return url;
    } on VideoRequiresPurchaseException {
      throw YoutubeServiceException('This video requires a purchase.');
    } on VideoUnplayableException catch (e) {
      throw YoutubeServiceException('Video unplayable: ${e.message}');
    } catch (e) {
      if (e is YoutubeServiceException) rethrow;
      throw YoutubeServiceException('Failed to get stream URL: $e');
    }
  }

  // ── Video stream URL ─────────────────────────────────────────────────────
  // Returns a muxed (video+audio) MP4 stream URL suitable for video_player.
  // Uses the highest quality muxed stream available (up to 720p typically).
  // Note: separate high-res video streams (>720p) are not muxed on YouTube.

  final Map<String, _CachedUrl> _videoMem = {};

  Future<String> getVideoStreamUrl(String videoId) async {
    final mem = _videoMem[videoId];
    if (mem != null && !mem.isExpired) return mem.url;

    if (_inflight.containsKey('v_$videoId')) return _inflight['v_$videoId']!;

    final future = _fetchVideoUrl(videoId);
    _inflight['v_$videoId'] = future;
    try {
      return await future;
    } finally {
      _inflight.remove('v_$videoId');
    }
  }

  Future<String> _fetchVideoUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Prefer highest bitrate muxed MP4 (these include both video and audio)
      var streams = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (streams.isEmpty) streams = manifest.muxed.toList();
      if (streams.isEmpty) {
        throw YoutubeServiceException('No video streams found for $videoId');
      }

      // Sort descending — best quality first
      streams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final url = streams.first.url.toString();

      _videoMem[videoId] = _CachedUrl(url, DateTime.now());
      return url;
    } on VideoRequiresPurchaseException {
      throw YoutubeServiceException('This video requires a purchase.');
    } on VideoUnplayableException catch (e) {
      throw YoutubeServiceException('Video unplayable: ${e.message}');
    } catch (e) {
      if (e is YoutubeServiceException) rethrow;
      throw YoutubeServiceException('Failed to get video stream URL: $e');
    }
  }

  // ── Prefetch ─────────────────────────────────────────────────────────────

  void prefetchUrl(String videoId) {
    final mem = _mem[videoId];
    if (mem != null && !mem.isExpired) return;
    final hive = _readHive(videoId);
    if (hive != null && !hive.isExpired) {
      _mem[videoId] = hive;
      return; // already cached — no network needed
    }
    if (_inflight.containsKey(videoId)) return;
    getAudioStreamUrl(videoId).catchError((_) => '');
  }

  /// Seed the memory cache directly from a [Song]'s stored [Song.streamUrl]
  /// field (written by AudioPlayerService after each play).
  /// This is zero-cost — no Hive read, no network.
  void seedFromSong(Song song) {
    if (song.streamUrl != null &&
        song.streamUrlFetchedAt != null &&
        !song.isStreamUrlExpired) {
      _mem[song.id] ??= _CachedUrl(song.streamUrl!, song.streamUrlFetchedAt!);
    }
  }

  void prefetchBatch(List<String> videoIds, {int maxConcurrent = 3}) {
    final needed = videoIds.where((id) {
      final mem = _mem[id];
      if (mem != null && !mem.isExpired) return false;
      final hive = _readHive(id);
      if (hive != null && !hive.isExpired) {
        _mem[id] = hive; // warm L1 from L2 for free
        return false;
      }
      return !_inflight.containsKey(id);
    }).take(maxConcurrent).toList();

    for (final id in needed) {
      prefetchUrl(id);
    }
  }

  // ── Video info ────────────────────────────────────────────────────────────

  Future<Song> getVideoInfo(String videoId) async {
    try {
      return _videoToSong(await _yt.videos.get(videoId));
    } catch (e) {
      throw YoutubeServiceException('Failed to fetch video info: $e');
    }
  }

  Song _videoToSong(Video video) {
    final thumb = video.thumbnails.maxResUrl.isNotEmpty
        ? video.thumbnails.maxResUrl
        : video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.mediumResUrl;
    return Song(
      id: video.id.value,
      title: video.title,
      channelName: video.author,
      thumbnailUrl: thumb,
      duration: video.duration ?? Duration.zero,
    );
  }

  // ── Captions / Lyrics ─────────────────────────────────────────────────────

  /// Returns all available caption tracks for a video, deduplicated by
  /// language code (one entry per language, preferring non-auto-generated).
  Future<List<CaptionTrackInfo>> getAvailableCaptionTracks(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);

      // Group by language code, prefer manual over auto-generated
      final Map<String, CaptionTrackInfo> seen = {};
      for (final t in manifest.tracks) {
        final code = t.language.code;
        final label = t.isAutoGenerated
            ? '${t.language.name} (auto-generated)'
            : t.language.name;
        final info = CaptionTrackInfo(
          code: code,
          label: label,
          isAutoGenerated: t.isAutoGenerated,
        );
        // Only add if not seen yet, OR replace an auto-generated with a manual one
        if (!seen.containsKey(code) ||
            (seen[code]!.isAutoGenerated && !t.isAutoGenerated)) {
          seen[code] = info;
        }
      }

      return seen.values.toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns a list of caption lines for the given video.
  /// Tries English first, then any available track.
  /// Returns an empty list if no captions are available.
  Future<List<LyricLine>> getLyrics(String videoId) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return [];

      // Prefer English, fall back to first available
      final trackInfo = manifest.tracks.firstWhere(
        (t) => t.language.code.startsWith('en'),
        orElse: () => manifest.tracks.first,
      );

      return _fetchTrack(trackInfo);
    } catch (_) {
      return [];
    }
  }

  /// Fetch lyrics for a specific track by language code.
  /// Prefers manual captions over auto-generated when both exist.
  Future<List<LyricLine>> getLyricsForTrack(
      String videoId, String languageCode) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return [];

      final matches = manifest.tracks
          .where((t) => t.language.code == languageCode)
          .toList();
      if (matches.isEmpty) return [];

      // Prefer manual over auto-generated
      final trackInfo = matches.firstWhere(
        (t) => !t.isAutoGenerated,
        orElse: () => matches.first,
      );

      return _fetchTrack(trackInfo);
    } catch (_) {
      return [];
    }
  }

  Future<List<LyricLine>> _fetchTrack(dynamic trackInfo) async {
    final track = await _yt.videos.closedCaptions.get(trackInfo);
    return track.captions.map((c) {
      // Build per-word list from caption parts when available
      final words = c.parts.map((p) => LyricWord(
        text: p.text.trim(),
        // part.offset is relative to the caption's own offset
        start: c.offset + p.offset,
      )).where((w) => w.text.isNotEmpty).toList();

      return LyricLine(
        text: c.text.trim(),
        start: c.offset,
        end: c.offset + c.duration,
        words: words,
      );
    }).where((l) => l.text.isNotEmpty).toList();
  }

  void dispose() => _yt.close();
}

class LyricLine {
  final String text;
  final Duration start;
  final Duration end;
  // Per-word timing (empty when not available — manual captions rarely have this)
  final List<LyricWord> words;

  const LyricLine({
    required this.text,
    required this.start,
    required this.end,
    this.words = const [],
  });

  bool get hasWordTiming => words.isNotEmpty;
}

class LyricWord {
  final String text;
  // Absolute start time (caption.offset + part.offset)
  final Duration start;

  const LyricWord({required this.text, required this.start});
}

class CaptionTrackInfo {
  final String code;
  final String label;
  final bool isAutoGenerated;
  const CaptionTrackInfo({
    required this.code,
    required this.label,
    required this.isAutoGenerated,
  });
}

class YoutubeServiceException implements Exception {
  final String message;
  const YoutubeServiceException(this.message);
  @override
  String toString() => 'YoutubeServiceException: $message';
}

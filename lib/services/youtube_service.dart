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

  void dispose() => _yt.close();
}

class YoutubeServiceException implements Exception {
  final String message;
  const YoutubeServiceException(this.message);
  @override
  String toString() => 'YoutubeServiceException: $message';
}

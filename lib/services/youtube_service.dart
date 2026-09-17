// ============================================================
// services/youtube_service.dart
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

/// Cached stream URL with a 5-hour TTL.
const _kUrlTtl = Duration(hours: 5);

class _CachedUrl {
  final String url;
  final DateTime fetchedAt;
  _CachedUrl(this.url) : fetchedAt = DateTime.now();
  bool get isExpired => DateTime.now().difference(fetchedAt) > _kUrlTtl;
}

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Resolved URL cache: videoId → url + timestamp.
  final Map<String, _CachedUrl> _urlCache = {};

  /// In-flight manifest requests: videoId → Future.
  /// Prevents launching duplicate fetches for the same video while one is
  /// already in progress (e.g. prefetch + user tap racing each other).
  final Map<String, Future<String>> _inflight = {};

  /// Exposes the underlying client so DownloadService can reuse it.
  YoutubeExplode get yt => _yt;

  // ── Search ──────────────────────────────────────────────────────────────

  Future<List<Song>> search(String query, {int maxResults = 20}) async {
    try {
      final results = await _yt.search.search(query);
      final songs = <Song>[];
      for (final video in results.take(maxResults)) {
        songs.add(_videoToSong(video));
      }
      return songs;
    } on VideoUnavailableException catch (e) {
      throw YoutubeServiceException('Video unavailable: ${e.message}');
    } catch (e) {
      throw YoutubeServiceException('Search failed: $e');
    }
  }

  // ── Stream URL resolution ────────────────────────────────────────────────

  /// Returns the stream URL for [videoId].
  ///
  /// - If already cached and fresh → returns instantly (no network).
  /// - If a fetch is already in-flight (e.g. triggered by prefetch) → awaits
  ///   that same Future instead of launching a second one.
  /// - Otherwise → launches a new manifest fetch.
  Future<String> getAudioStreamUrl(String videoId) async {
    final cached = _urlCache[videoId];
    if (cached != null && !cached.isExpired) return cached.url;

    // Reuse an existing in-flight fetch
    if (_inflight.containsKey(videoId)) {
      return _inflight[videoId]!;
    }

    final future = _fetchUrl(videoId);
    _inflight[videoId] = future;
    try {
      final url = await future;
      return url;
    } finally {
      _inflight.remove(videoId);
    }
  }

  Future<String> _fetchUrl(String videoId) async {
    try {
      final manifest =
          await _yt.videos.streamsClient.getManifest(videoId);

      // Prefer MP4 muxed (works without PO token); fall back to any muxed
      var streams = manifest.muxed
          .where((s) => s.container.name == 'mp4')
          .toList();
      if (streams.isEmpty) streams = manifest.muxed.toList();
      if (streams.isEmpty) {
        throw YoutubeServiceException(
            'No playable streams found for $videoId');
      }

      // Lowest bitrate = least bandwidth wasted on video data we don't need
      streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      final url = streams.first.url.toString();
      _urlCache[videoId] = _CachedUrl(url);
      return url;
    } on VideoRequiresPurchaseException {
      throw YoutubeServiceException(
          'This video requires a purchase and cannot be played.');
    } on VideoUnplayableException catch (e) {
      throw YoutubeServiceException(
          'Video unplayable (unavailable/age-restricted/region-blocked): ${e.message}');
    } catch (e) {
      if (e is YoutubeServiceException) rethrow;
      throw YoutubeServiceException('Failed to get stream URL: $e');
    }
  }

  // ── Prefetch ─────────────────────────────────────────────────────────────

  /// Fire-and-forget URL resolution — errors are silently ignored.
  /// Call this as soon as you know a song *might* be played soon
  /// (e.g. right after search results arrive, or after a song starts playing).
  void prefetchUrl(String videoId) {
    final cached = _urlCache[videoId];
    if (cached != null && !cached.isExpired) return; // already warm
    if (_inflight.containsKey(videoId)) return;      // already fetching
    getAudioStreamUrl(videoId).catchError((_) => '');
  }

  /// Prefetch URLs for a batch of video IDs concurrently.
  /// Use after search results load to warm the cache for visible songs.
  /// [maxConcurrent] limits parallel manifest requests to avoid hammering
  /// YouTube's servers (which can cause rate-limiting / 429s).
  void prefetchBatch(List<String> videoIds, {int maxConcurrent = 3}) {
    // Only prefetch IDs that aren't already cached or in-flight
    final needed = videoIds.where((id) {
      final cached = _urlCache[id];
      return (cached == null || cached.isExpired) && !_inflight.containsKey(id);
    }).take(maxConcurrent).toList();

    for (final id in needed) {
      prefetchUrl(id);
    }
  }

  // ── Video info ───────────────────────────────────────────────────────────

  Future<Song> getVideoInfo(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return _videoToSong(video);
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

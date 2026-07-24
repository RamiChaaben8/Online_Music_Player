// ============================================================
// services/youtube_service.dart
//
// Wraps youtube_explode_dart to:
//  - Search for videos by query
//  - Resolve an audio-only stream URL for a given video ID
//  - Handle errors gracefully (unavailable, region-blocked, network issues)
// ============================================================

import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Search YouTube for [query], returning up to [maxResults] songs.
  /// Throws [YoutubeServiceException] on failure.
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

  /// Resolve an audio-only stream URL for [videoId].
  /// Tries muxed streams as fallback if audio-only is unavailable.
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // YouTube recently started blocking audioOnly streams (403 Forbidden) 
      // due to new PO token restrictions. However, muxed (video+audio) streams 
      // are still fully accessible. just_audio will extract the audio track automatically.
      var streams = manifest.muxed.where((s) => s.container.name == 'mp4').toList();
      
      if (streams.isEmpty) {
        streams = manifest.muxed.toList();
      }

      // Sort by bitrate to get the lowest quality video (saves bandwidth since we only want audio)
      streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));

      if (streams.isNotEmpty) {
        return streams.first.url.toString();
      }

      throw YoutubeServiceException('No playable streams found for video $videoId');
    } on VideoRequiresPurchaseException {
      throw YoutubeServiceException('This video requires a purchase and cannot be played.');
    } on VideoUnplayableException catch (e) {
      // Also catches VideoUnavailableException (a subtype)
      throw YoutubeServiceException(
        'Video is unplayable (unavailable, age-restricted, or region-blocked): ${e.message}',
      );
    } catch (e) {
      throw YoutubeServiceException('Failed to get stream URL: $e');
    }
  }

  /// Fetch full video metadata (used when building a Song from an ID alone).
  Future<Song> getVideoInfo(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return _videoToSong(video);
    } catch (e) {
      throw YoutubeServiceException('Failed to fetch video info: $e');
    }
  }

  /// Convert a [Video] object from youtube_explode into a [Song].
  Song _videoToSong(Video video) {
    // Best-quality thumbnail available
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

  /// Close the underlying HTTP client.
  void dispose() => _yt.close();
}

/// A typed exception for this service so callers can show friendly messages.
class YoutubeServiceException implements Exception {
  final String message;
  const YoutubeServiceException(this.message);

  @override
  String toString() => 'YoutubeServiceException: $message';
}

import 'dart:convert';
import 'dart:io';

import '../models/song.dart';
import 'youtube_service.dart';

class PlaylistImportResult {
  final String name;
  final List<Song> songs;

  const PlaylistImportResult({required this.name, required this.songs});
}

class PlaylistImportProgress {
  final String source;
  final int current;
  final int? total;

  const PlaylistImportProgress({
    required this.source,
    required this.current,
    this.total,
  });
}

class _SpotifyTrack {
  final String title;
  final String query;

  const _SpotifyTrack({required this.title, required this.query});
}

class PlaylistImportService {
  final YoutubeService _youtube;

  PlaylistImportService(this._youtube);

  Future<PlaylistImportResult> importFromUrl(
    String url, {
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw YoutubeServiceException('Enter a valid Spotify or YouTube URL.');
    }

    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      return _importYoutube(url, onProgress: onProgress);
    }
    if (uri.host.contains('spotify.com')) {
      return _importSpotify(url, onProgress: onProgress);
    }
    throw YoutubeServiceException(
        'Only Spotify and YouTube playlist links are supported.');
  }

  Future<PlaylistImportResult> _importYoutube(
    String url, {
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    final inputUri = Uri.parse(url.trim());
    final playlistId = inputUri.queryParameters['list'];
    final playlistUrl = playlistId == null
        ? url
        : 'https://www.youtube.com/playlist?list=$playlistId';
    final playlistSource = playlistId ?? playlistUrl;
    late final String playlistName;
    int? playlistTotal;
    try {
      final playlist = await _youtube.yt.playlists.get(playlistUrl);
      playlistName = playlist.title;
      playlistTotal = playlist.videoCount;
    } catch (e) {
      throw YoutubeServiceException(
          'YouTube could not read this playlist. Make sure it is public.');
    }
    var songs = <Song>[];
    var current = 0;
    try {
      await for (final video
          in _youtube.yt.playlists.getVideos(playlistSource)) {
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          channelName: video.author,
          thumbnailUrl: video.thumbnails.highResUrl,
          duration: video.duration ?? Duration.zero,
        ));
        current++;
        onProgress?.call(PlaylistImportProgress(
          source: 'YouTube',
          current: current,
          total: playlistTotal,
        ));
      }
    } catch (_) {
      // YouTube occasionally returns a playlist page whose video entries
      // cannot be parsed by youtube_explode_dart. Try the public feed below.
    }
    if (songs.isEmpty && playlistId != null) {
      songs = await _importYoutubeRss(
        playlistId,
        total: playlistTotal,
        onProgress: onProgress,
      );
    }
    if (songs.isEmpty)
      throw YoutubeServiceException(
          'This YouTube playlist has no importable videos.');
    return PlaylistImportResult(name: playlistName, songs: songs);
  }

  Future<List<Song>> _importYoutubeRss(
    String playlistId, {
    int? total,
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
          'https://www.youtube.com/feeds/videos.xml?playlist_id=$playlistId'));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final response = await request.close();
      final xml = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final songs = <Song>[];
      final entries =
          RegExp(r'<entry>(.*?)</entry>', dotAll: true).allMatches(xml);
      for (final entry in entries) {
        final block = entry.group(1)!;
        final id = RegExp(r'<yt:videoId>(.*?)</yt:videoId>')
            .firstMatch(block)
            ?.group(1);
        final title = RegExp(r'<media:title>(.*?)</media:title>')
            .firstMatch(block)
            ?.group(1);
        final author =
            RegExp(r'<name>(.*?)</name>').firstMatch(block)?.group(1);
        if (id == null || title == null) continue;
        songs.add(Song(
          id: id,
          title: _decodeXml(title),
          channelName: author == null ? 'YouTube' : _decodeXml(author),
          thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          duration: Duration.zero,
        ));
        onProgress?.call(PlaylistImportProgress(
          source: 'YouTube',
          current: songs.length,
          total: total,
        ));
      }
      return songs;
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<PlaylistImportResult> _importSpotify(
    String url, {
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    final playlistId = _spotifyPlaylistId(Uri.parse(url));
    if (playlistId == null) {
      throw YoutubeServiceException('The Spotify link is not a playlist link.');
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://open.spotify.com/embed/playlist/$playlistId'),
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final response = await request.close();
      final html = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw YoutubeServiceException('Could not read the Spotify playlist.');
      }

      final data = _spotifyEmbedData(html);
      final entity = data?['props']?['pageProps']?['state']?['data']?['entity'];
      if (entity is! Map) {
        throw YoutubeServiceException(
            'Spotify did not expose this public playlist.');
      }

      final name = entity['name'] as String? ?? 'Imported Spotify playlist';
      final trackNames = _spotifyTrackNames(entity);
      if (trackNames.isEmpty) {
        throw YoutubeServiceException(
            'Spotify did not expose any public tracks for this playlist.');
      }

      final songs = <Song>[];
      final tracks = trackNames.take(200).toList();
      for (var index = 0; index < tracks.length; index++) {
        final track = tracks[index];
        try {
          var matches = await _youtube.search(track.query, maxResults: 3);
          if (matches.isEmpty && track.query != track.title) {
            matches = await _youtube.search(track.title, maxResults: 3);
          }
          if (matches.isNotEmpty) songs.add(matches.first);
        } catch (_) {
          // One unavailable or malformed search must not cancel the whole
          // playlist import. Continue importing the remaining tracks.
          if (track.query != track.title) {
            try {
              final matches = await _youtube.search(track.title, maxResults: 3);
              if (matches.isNotEmpty) songs.add(matches.first);
            } catch (_) {
              // Skip only this track when both searches fail.
            }
          }
        } finally {
          onProgress?.call(PlaylistImportProgress(
            source: 'Spotify',
            current: index + 1,
            total: tracks.length,
          ));
        }
      }
      if (songs.isEmpty)
        throw YoutubeServiceException(
            'No matching tracks were found on YouTube.');
      return PlaylistImportResult(name: name, songs: songs);
    } finally {
      client.close(force: true);
    }
  }

  String? _spotifyPlaylistId(Uri uri) {
    final match = RegExp(r'/playlist/([A-Za-z0-9]+)').firstMatch(uri.path);
    return match?.group(1) ?? uri.queryParameters['si'];
  }

  Map<String, dynamic>? _spotifyEmbedData(String html) {
    final match = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<_SpotifyTrack> _spotifyTrackNames(Map entity) {
    final names = <_SpotifyTrack>[];
    final tracks = entity['trackList'];
    if (tracks is! List) return names;

    for (final track in tracks) {
      if (track is! Map) continue;
      final title = track['title'] as String?;
      final artist = track['subtitle'] as String?;
      if (title == null || title.trim().isEmpty) continue;
      final query =
          artist == null || artist.trim().isEmpty ? title : '$title $artist';
      if (!names.any((item) => item.query == query)) {
        names.add(_SpotifyTrack(title: title, query: query));
      }
    }
    return names;
  }
}

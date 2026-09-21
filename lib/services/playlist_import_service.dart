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
  final String? artist;

  const _SpotifyTrack({
    required this.title,
    required this.query,
    this.artist,
  });
}

class _SpotifyPlaylistData {
  final String name;
  final List<_SpotifyTrack> tracks;

  const _SpotifyPlaylistData({required this.name, required this.tracks});
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
      final playlist = await _spotifyPathfinderPlaylist(client, playlistId);
      if (playlist == null) {
        final request = await client.getUrl(
          Uri.parse('https://open.spotify.com/playlist/$playlistId'),
        );
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
        final response = await request.close();
        final html = await utf8.decoder.bind(response).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw YoutubeServiceException('Could not read the Spotify playlist.');
        }
        final fallback = _spotifyPlaylistData(html);
        if (fallback == null) {
          throw YoutubeServiceException(
              'Spotify did not expose this public playlist.');
        }
        return _importSpotifyTracks(fallback, onProgress: onProgress);
      }

      return _importSpotifyTracks(playlist, onProgress: onProgress);
    } finally {
      client.close(force: true);
    }
  }

  Future<PlaylistImportResult> _importSpotifyTracks(
    _SpotifyPlaylistData playlist, {
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    if (playlist.tracks.isEmpty) {
      throw YoutubeServiceException(
          'Spotify did not expose any public tracks for this playlist.');
    }

    final songs = <Song>[];
    final tracks = playlist.tracks;
    for (var start = 0; start < tracks.length; start += 2) {
      final end = (start + 2).clamp(0, tracks.length);
      final batch = tracks.sublist(start, end);
      final matches = await Future.wait(batch.map(_findSpotifyTrack));
      for (var offset = 0; offset < matches.length; offset++) {
        final match = matches[offset];
        if (match != null) songs.add(match);
        onProgress?.call(PlaylistImportProgress(
          source: 'Spotify',
          current: start + offset + 1,
          total: tracks.length,
        ));
      }
    }
    if (songs.isEmpty) {
      throw YoutubeServiceException(
          'No matching tracks were found on YouTube.');
    }
    return PlaylistImportResult(name: playlist.name, songs: songs);
  }

  Future<_SpotifyPlaylistData?> _spotifyPathfinderPlaylist(
    HttpClient client,
    String playlistId,
  ) async {
    try {
      final embedRequest = await client.getUrl(
        Uri.parse('https://open.spotify.com/embed/playlist/$playlistId'),
      );
      embedRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final embedResponse = await embedRequest.close();
      final embedHtml = await utf8.decoder.bind(embedResponse).join();
      if (embedResponse.statusCode < 200 || embedResponse.statusCode >= 300) {
        return null;
      }

      final token = _spotifyAnonymousToken(embedHtml);
      if (token == null) return null;

      final extensions = jsonEncode({
        'persistedQuery': {
          'version': 1,
          'sha256Hash':
              'a65e12194ed5fc443a1cdebed5fabe33ca5b07b987185d63c72483867ad13cb4',
        },
      });

      final tracks = <_SpotifyTrack>[];
      String? name;
      var offset = 0;
      var totalCount = 0;
      while (true) {
        final variables = jsonEncode({
          'uri': 'spotify:playlist:$playlistId',
          'offset': offset,
          'limit': 100,
          'enableWatchFeedEntrypoint': false,
        });
        final pathfinderUri = Uri.parse(
          'https://api-partner.spotify.com/pathfinder/v1/query',
        ).replace(queryParameters: {
          'operationName': 'fetchPlaylist',
          'variables': variables,
          'extensions': extensions,
        });
        final request = await client.getUrl(pathfinderUri);
        request.headers
          ..set(HttpHeaders.userAgentHeader, 'Mozilla/5.0')
          ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
          ..set('app-platform', 'WebPlayer');
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final body = jsonDecode(await utf8.decoder.bind(response).join());
        final playlist = body['data']?['playlistV2'];
        final content = playlist is Map ? playlist['content'] : null;
        if (playlist is! Map || content is! Map) return null;

        name ??= playlist['name'] as String?;
        tracks.addAll(_spotifyPathfinderTrackNames(content['items']));
        totalCount = content['totalCount'] as int? ?? tracks.length;
        final pagingInfo = content['pagingInfo'];
        final nextOffset =
            pagingInfo is Map ? pagingInfo['nextOffset'] as int? : null;
        if (nextOffset == null ||
            nextOffset <= offset ||
            tracks.length >= totalCount) {
          break;
        }
        offset = nextOffset;
      }

      return _SpotifyPlaylistData(
        name: name ?? 'Imported Spotify playlist',
        tracks: tracks,
      );
    } catch (_) {
      return null;
    }
  }

  String? _spotifyAnonymousToken(String html) {
    final data = _spotifyEmbedData(html);
    final session =
        data?['props']?['pageProps']?['state']?['settings']?['session'];
    if (session is! Map) return null;
    final token = session['accessToken'];
    return token is String && token.isNotEmpty ? token : null;
  }

  List<_SpotifyTrack> _spotifyPathfinderTrackNames(dynamic items) {
    if (items is! List) return [];
    final tracks = <_SpotifyTrack>[];
    for (final item in items) {
      final itemV2 = item is Map ? item['itemV2'] : null;
      final data = itemV2 is Map ? itemV2['data'] : null;
      if (data is! Map) continue;
      final title = data['name'] as String?;
      final artistsData = data['artists'];
      final artists = artistsData is Map ? artistsData['items'] : null;
      final artist = artists is List && artists.isNotEmpty
          ? (artists.first is Map
              ? ((artists.first['profile'] is Map)
                  ? artists.first['profile']['name'] as String?
                  : null)
              : null)
          : null;
      if (title == null || title.trim().isEmpty) continue;
      tracks.add(_SpotifyTrack(
        title: title,
        query:
            artist == null || artist.trim().isEmpty ? title : '$title $artist',
        artist: artist,
      ));
    }
    return tracks;
  }

  Future<Song?> _findSpotifyTrack(_SpotifyTrack track) async {
    final cleanTitle = track.title
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final titleWords = cleanTitle
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((word) => word.length > 1)
        .join(' ');
    final queries = <String>[];
    for (final query in [
      track.query,
      track.title,
      if (cleanTitle != track.title) cleanTitle,
      if (track.artist != null && cleanTitle != track.title)
        '$cleanTitle ${track.artist}',
      if (track.artist != null) '${track.artist} $cleanTitle',
      if (titleWords != cleanTitle) titleWords,
    ]) {
      final normalized = query.trim();
      if (normalized.isNotEmpty && !queries.contains(normalized)) {
        queries.add(normalized);
      }
    }

    for (final query in queries) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final matches = await _youtube.search(query, maxResults: 10);
          if (matches.isNotEmpty) return matches.first;
        } catch (_) {
          // Retry transient YouTube failures before trying another query.
        }
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }
    }
    return null;
  }

  String? _spotifyPlaylistId(Uri uri) {
    final match = RegExp(r'/playlist/([A-Za-z0-9]+)').firstMatch(uri.path);
    return match?.group(1) ?? uri.queryParameters['si'];
  }

  _SpotifyPlaylistData? _spotifyPlaylistData(String html) {
    final stateMatch = RegExp(
      r'<script id="initialState" type="text/plain">(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (stateMatch != null) {
      try {
        final decoded = jsonDecode(
          utf8.decode(base64Decode(stateMatch.group(1)!)),
        );
        final items = decoded['entities']?['items'];
        if (items is Map && items.isNotEmpty) {
          final playlist = items.values.first;
          final content = playlist['content'];
          final tracks = _spotifyPageTrackNames(content?['items']);
          if (playlist is Map && content is Map) {
            return _SpotifyPlaylistData(
              name: playlist['name'] as String? ?? 'Imported Spotify playlist',
              tracks: tracks,
            );
          }
        }
      } catch (_) {
        // Fall back to the embed payload for older Spotify page responses.
      }
    }

    final data = _spotifyEmbedData(html);
    final entity = data?['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity is Map) {
      final tracks = _spotifyTrackNames(entity);
      return _SpotifyPlaylistData(
        name: entity['name'] as String? ?? 'Imported Spotify playlist',
        tracks: tracks,
      );
    }
    return null;
  }

  List<_SpotifyTrack> _spotifyPageTrackNames(dynamic items) {
    if (items is! List) return [];
    final tracks = <_SpotifyTrack>[];
    for (final item in items) {
      final itemV2 = item is Map ? item['itemV2'] : null;
      final data = itemV2 is Map ? itemV2['data'] : null;
      if (data is! Map) continue;
      final title = data['name'] as String?;
      final artistsData = data['artists'];
      final artists = artistsData is Map ? artistsData['items'] : null;
      final artist = artists is List && artists.isNotEmpty
          ? (artists.first is Map
              ? ((artists.first['profile'] is Map)
                  ? artists.first['profile']['name'] as String?
                  : null)
              : null)
          : null;
      if (title == null || title.trim().isEmpty) continue;
      tracks.add(_SpotifyTrack(
        title: title,
        query:
            artist == null || artist.trim().isEmpty ? title : '$title $artist',
        artist: artist,
      ));
    }
    return tracks;
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
      names.add(_SpotifyTrack(title: title, query: query, artist: artist));
    }
    return names;
  }
}

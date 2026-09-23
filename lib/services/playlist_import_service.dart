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

    // ── Strategy 1: YouTube Data API v3 (primary) ────────────────────────────
    // No per-session limit. Returns all songs paginated at 50 per page.
    if (playlistId != null) {
      try {
        final result = await _importYoutubeDataApi(
          playlistId,
          nameHint: playlistName,
          total: playlistTotal,
          onProgress: onProgress,
        );
        if (result.songs.isNotEmpty) {
          songs = result.songs;
        }
      } catch (_) {
        // Data API failed — fall through to InnerTube.
      }
    }

    // ── Strategy 2: InnerTube (fallback) ─────────────────────────────────────
    // Used when Data API fails. Limited to ~200 songs by bot-detection.
    if (songs.isEmpty && playlistId != null) {
      try {
        final innertube = await _importYoutubeInnerTube(
          playlistId,
          nameHint: playlistName,
          total: playlistTotal,
          onProgress: onProgress,
        );
        if (innertube.songs.isNotEmpty) {
          songs = innertube.songs;
        }
      } catch (_) {
        // InnerTube failed — fall through to youtube_explode_dart.
      }
    }

    // ── Strategy 3: youtube_explode_dart (fallback) ───────────────────────────
    // Only used when InnerTube returns nothing (e.g. bot-detection on InnerTube
    // side). Accepts whatever partial result it produces.
    if (songs.isEmpty) {
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
        // youtube_explode_dart occasionally cannot parse a playlist page.
        // The RSS last-resort below will handle it.
      }
    }

    // ── Strategy 3: RSS feed (last resort) ───────────────────────────────────
    // Capped at ~15 entries by YouTube, but handles edge cases where both
    // InnerTube and youtube_explode_dart fail (e.g. very new playlists).
    if (songs.isEmpty && playlistId != null) {
      songs = await _importYoutubeRss(
        playlistId,
        total: playlistTotal,
        onProgress: onProgress,
      );
    }

    if (songs.isEmpty) {
      throw YoutubeServiceException(
          'Could not import this YouTube playlist.\n'
          'Make sure the playlist is public and the link is correct.\n'
          'Tip: open the playlist on YouTube, tap Share → Copy link, and paste that link here.');
    }
    return PlaylistImportResult(name: playlistName, songs: songs);
  }

  /// Fetches a YouTube playlist via the YouTube Data API v3.
  /// No per-session limit — returns all songs paginated at 50 per page.
  Future<PlaylistImportResult> _importYoutubeDataApi(
    String playlistId, {
    required String nameHint,
    int? total,
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    const apiKey = 'AIzaSyCPvjYBWStqSLajx9jHjLCZMe7yIMaJ1D8';
    const baseUrl = 'https://www.googleapis.com/youtube/v3/playlistItems';
    final client = HttpClient();
    try {
      final songs = <Song>[];
      String? pageToken;

      do {
        final uri = Uri.parse(baseUrl).replace(queryParameters: {
          'part': 'snippet',
          'playlistId': playlistId,
          'maxResults': '50',
          'key': apiKey,
          if (pageToken != null) 'pageToken': pageToken,
        });

        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
        final response = await request.close()
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 403) {
          throw YoutubeServiceException(
              'YouTube Data API quota exceeded or key is invalid.');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw YoutubeServiceException(
              'YouTube Data API error: ${response.statusCode}');
        }

        final Map<String, dynamic> data =
            jsonDecode(await utf8.decoder.bind(response).join());

        // Check for API error in response body
        if (data.containsKey('error')) {
          final msg = data['error']?['message'] as String? ?? 'Unknown error';
          throw YoutubeServiceException('YouTube Data API: $msg');
        }

        final items = data['items'] as List? ?? [];
        for (final item in items) {
          final snippet = item['snippet'] as Map?;
          if (snippet == null) continue;

          // Skip deleted/private videos
          final title = snippet['title'] as String? ?? '';
          if (title == 'Deleted video' || title == 'Private video') continue;

          final videoId =
              snippet['resourceId']?['videoId'] as String?;
          if (videoId == null || videoId.isEmpty) continue;

          final channelName =
              snippet['videoOwnerChannelTitle'] as String? ??
              snippet['channelTitle'] as String? ??
              'YouTube';
          final thumbnails = snippet['thumbnails'] as Map?;
          final thumbnailUrl =
              (thumbnails?['high'] ?? thumbnails?['medium'] ??
                      thumbnails?['default'])
                  ?['url'] as String? ??
              'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

          songs.add(Song(
            id: videoId,
            title: title,
            channelName: channelName,
            thumbnailUrl: thumbnailUrl,
            duration: Duration.zero, // Data API v3 needs a separate call for duration
          ));
          onProgress?.call(PlaylistImportProgress(
            source: 'YouTube',
            current: songs.length,
            total: total,
          ));
        }

        pageToken = data['nextPageToken'] as String?;
        // ignore: avoid_print
        print('[DataAPI] fetched ${songs.length} songs, nextPage=${pageToken != null}');
      } while (pageToken != null);

      if (songs.isEmpty) {
        throw YoutubeServiceException('Data API returned no songs.');
      }
      return PlaylistImportResult(name: nameHint, songs: songs);
    } finally {
      client.close(force: true);
    }
  }

  /// Fetches a YouTube playlist via the InnerTube browse API (no key needed).
  /// This is the same endpoint used by youtube.com itself and handles playlists
  /// that [youtube_explode_dart] and the RSS feed cannot parse.
  Future<PlaylistImportResult> _importYoutubeInnerTube(
    String playlistId, {
    required String nameHint,
    int? total,
    void Function(PlaylistImportProgress progress)? onProgress,
  }) async {
    // WEB client gets bot-detected after ~200 songs, but works reliably up to that limit.
    const innerTubeUrl =
        'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false';
    const clientName = 'WEB';
    const clientId = '1';
    const clientVersion = '2.20240726.00.00';
    final client = HttpClient();
    try {
      final songs = <Song>[];
      String? continuationToken;
      String? playlistName;
      const maxPages = 50;
      var pageCount = 0;
      var consecutiveEmptyPages = 0;

      do {
        pageCount++;
        if (pageCount > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        final body = continuationToken == null
            ? jsonEncode({
                'context': {
                  'client': {
                    'clientName': clientName,
                    'clientVersion': clientVersion,
                  },
                },
                'browseId': 'VL$playlistId',
              })
            : jsonEncode({
                'context': {
                  'client': {
                    'clientName': clientName,
                    'clientVersion': clientVersion,
                  },
                },
                'continuation': continuationToken,
              });

        final request = await client.postUrl(Uri.parse(innerTubeUrl));
        request.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/json')
          ..set(HttpHeaders.userAgentHeader,
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
          ..set('X-YouTube-Client-Name', clientId)
          ..set('X-YouTube-Client-Version', clientVersion)
          ..set('Origin', 'https://www.youtube.com')
          ..set(HttpHeaders.refererHeader,
              'https://www.youtube.com/playlist?list=$playlistId');
        request.add(utf8.encode(body));
        final response = await request.close()
            .timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) break;

        final Map<String, dynamic> data =
            jsonDecode(await utf8.decoder.bind(response).join());

        // Parse name from initial response
        if (playlistName == null) {
          playlistName = _innerTubePlaylistName(data);
        }

        // Extract video items AND the next continuation token from the same
        // list — keeps them in sync regardless of response shape.
        final extracted = _innerTubeExtract(data);
        final List<dynamic> items = extracted.items;
        continuationToken = extracted.token;
        final int songsBefore = songs.length;

        for (final item in items) {
          if (item is! Map) continue;

          // ── New format: lockupViewModel (YouTube 2024+) ──────────────────
          final lockup = item['lockupViewModel'] as Map?;
          if (lockup != null) {
            final videoId = lockup['contentId'] as String?;
            if (videoId == null || videoId.isEmpty) continue;

            final meta =
                lockup['metadata']?['lockupMetadataViewModel'] as Map?;
            final title = (meta?['title'] as Map?)?['content'] as String? ??
                'Unknown';

            // Author is in metadataRows[0].metadataParts[0].text.content
            final metaRows = meta?['metadata']?['contentMetadataViewModel']
                ?['metadataRows'] as List?;
            String author = 'YouTube';
            if (metaRows != null && metaRows.isNotEmpty) {
              final parts =
                  (metaRows.first as Map?)?['metadataParts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final text = (parts.first as Map?)?['text'] as Map?;
                author = text?['content'] as String? ?? 'YouTube';
              }
            }

            // Duration from thumbnail badge text (e.g. "3:36")
            Duration duration = Duration.zero;
            try {
              final sources = lockup['contentImage']?['thumbnailViewModel']
                  ?['overlays'] as List?;
              if (sources != null) {
                for (final overlay in sources) {
                  final badges = (overlay as Map?)?[
                          'thumbnailBottomOverlayViewModel']?['badges']
                      as List?;
                  if (badges == null) continue;
                  for (final badge in badges) {
                    final text = (badge as Map?)?['thumbnailBadgeViewModel']
                        ?['text'] as String?;
                    if (text != null) {
                      duration = _parseDurationText(text);
                    }
                  }
                }
              }
            } catch (_) {}

            songs.add(Song(
              id: videoId,
              title: title,
              channelName: author,
              thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              duration: duration,
            ));
            onProgress?.call(PlaylistImportProgress(
              source: 'YouTube',
              current: songs.length,
              total: total,
            ));
            continue;
          }

          // ── Old format: playlistVideoRenderer ───────────────────────────
          final renderer = item['playlistVideoRenderer'] as Map?;
          if (renderer == null) continue;

          final videoId = renderer['videoId'] as String?;
          if (videoId == null || videoId.isEmpty) continue;

          // Skip unavailable / private / deleted videos
          final isPlayable = (renderer['isPlayable'] as bool?) ?? true;
          if (!isPlayable) continue;

          final title = _innerTubeText(renderer['title']) ?? 'Unknown';
          final author = _innerTubeText(renderer['shortBylineText']) ??
              _innerTubeText(renderer['longBylineText']) ??
              'YouTube';

          // Duration: prefer lengthSeconds, fallback to lengthText parse
          Duration duration = Duration.zero;
          final lengthSeconds = renderer['lengthSeconds'];
          if (lengthSeconds is String) {
            duration = Duration(seconds: int.tryParse(lengthSeconds) ?? 0);
          } else if (lengthSeconds is int) {
            duration = Duration(seconds: lengthSeconds);
          }

          songs.add(Song(
            id: videoId,
            title: title,
            channelName: author,
            thumbnailUrl:
                'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            duration: duration,
          ));
          onProgress?.call(PlaylistImportProgress(
            source: 'YouTube',
            current: songs.length,
            total: total,
          ));
        }

        final newSongs = songs.length - songsBefore;
        // ignore: avoid_print
        print('[InnerTube] page=$pageCount items=${items.length} '
            'newSongs=$newSongs '
            'total=${songs.length} '
            'nextToken=${continuationToken != null}');

        // Guard: if a page yields no new songs, we've likely hit a dead-end
        // token (e.g. TOKEN_B pointing to "related playlists"). Stop after
        // two consecutive empty pages to avoid an infinite loop.
        if (newSongs == 0) {
          consecutiveEmptyPages++;
          if (consecutiveEmptyPages >= 2) {
            // ignore: avoid_print
            print('[InnerTube] 2 consecutive empty pages — stopping early.');
            break;
          }
        } else {
          consecutiveEmptyPages = 0;
        }
      } while (continuationToken != null && pageCount < maxPages);


      return PlaylistImportResult(
        name: playlistName ?? nameHint,
        songs: songs,
      );
    } catch (e) {
      // Surface the error as a service exception so the UI can show it.
      // If the caller prefers a silent fallback it can catch this itself.
      throw YoutubeServiceException(
          'InnerTube playlist fetch failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  /// Parses a duration string like "3:36" or "1:02:45" into a [Duration].
  Duration _parseDurationText(String text) {
    try {
      final parts = text.trim().split(':').map(int.parse).toList();
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      } else if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return Duration.zero;
  }

  /// Extracts the playlist title from an InnerTube browse response.
  String? _innerTubePlaylistName(Map<String, dynamic> data) {
    try {
      // New format: pageHeaderRenderer
      final pageHeader = data['header']?['pageHeaderRenderer'] as Map?;
      if (pageHeader != null) {
        final content = pageHeader['content'] as Map?;
        // pageHeaderViewModel
        final pvm = content?['pageHeaderViewModel'] as Map?;
        if (pvm != null) {
          final title = pvm['title']?['dynamicTextViewModel']?['text']
                  ?['content'] as String? ??
              pvm['title']?['dynamicTextViewModel']?['text']
                  ?['runs']?[0]?['text'] as String?;
          if (title != null && title.isNotEmpty) return title;
        }
      }

      // Old format: playlistHeaderRenderer
      final header = data['header']?['playlistHeaderRenderer'] as Map?;
      if (header != null) return _innerTubeText(header['title']);

      // sidebar renderer (older response shape)
      final sidebar =
          data['sidebar']?['playlistSidebarRenderer']?['items'] as List?;
      if (sidebar != null && sidebar.isNotEmpty) {
        final primary =
            sidebar.first['playlistSidebarPrimaryInfoRenderer'] as Map?;
        if (primary != null) return _innerTubeText(primary['title']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Navigates the InnerTube response JSON to locate the list of video items
  /// AND the continuation token for the next page, returning both together.
  ///
  /// Keeping them together ensures the token is always extracted from the same
  /// list as the items — avoiding the mismatch where items come from an inner
  /// ISR list but the token was searched in the outer continuationItems list.
  ///
  /// Observed response shapes:
  ///
  /// Initial browse (page 1):
  ///   contents → twoColumnBrowseResultsRenderer → tabs[0] → tabRenderer
  ///   → content → sectionListRenderer → contents[n]
  ///   → itemSectionRenderer → contents[]   ← items + continuationItemRenderer
  ///   OR → playlistVideoListRenderer → contents[]  (old format)
  ///
  /// Continuation pages (page 2, 3, … — using TOKEN_A):
  ///   onResponseReceivedActions[n].appendContinuationItemsAction
  ///   → continuationItems[]
  ///     Direct lockupViewModel / playlistVideoRenderer items,
  ///     ending with a continuationItemRenderer for the next page.
  ///   OR continuationItems[n].itemSectionRenderer.contents[]  (some shapes)
  ({List<dynamic> items, String? token}) _innerTubeExtract(
      Map<String, dynamic> data) {
    String? tokenFromList(List list) {
      for (final item in list.reversed) {
        if (item is! Map) continue;
        final t = item['continuationItemRenderer']
            ?['continuationEndpoint']
            ?['continuationCommand']
            ?['token'] as String?;
        if (t != null && t.isNotEmpty) return t;
      }
      return null;
    }

    List<dynamic> stripContinuation(List list) =>
        list.where((x) => x is! Map || !x.containsKey('continuationItemRenderer')).toList();

    try {
      // ── Initial browse response ─────────────────────────────────────────
      // WEB: twoColumnBrowseResultsRenderer → tabs → tabRenderer
      // Android: singleColumnBrowseResultsRenderer → tabs → tabRenderer
      final twoCol = data['contents']
          ?['twoColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      final oneCol = data['contents']
          ?['singleColumnBrowseResultsRenderer']
          ?['tabs'] as List?;
      final tabs = twoCol ?? oneCol;
      if (tabs != null) {
        for (final tab in tabs) {
          if (tab is! Map) continue;
          final sectionContents = tab['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List?;
          if (sectionContents == null) continue;
          for (final section in sectionContents) {
            if (section is! Map) continue;
            // Old/Android format: playlistVideoListRenderer
            final pvlr =
                section['playlistVideoListRenderer']?['contents'] as List?;
            if (pvlr != null) {
              return (items: stripContinuation(pvlr), token: tokenFromList(pvlr));
            }
            // WEB new format: itemSectionRenderer
            final isr = section['itemSectionRenderer']?['contents'] as List?;
            if (isr != null && isr.isNotEmpty) {
              if (isr.any((x) => x is Map && x.containsKey('lockupViewModel'))) {
                return (items: stripContinuation(isr), token: tokenFromList(isr));
              }
              // Old format nested inside ISR
              for (final item in isr) {
                if (item is! Map) continue;
                final nested =
                    item['playlistVideoListRenderer']?['contents'] as List?;
                if (nested != null) {
                  return (items: stripContinuation(nested), token: tokenFromList(nested));
                }
              }
            }
          }
        }
      }

    // Scans contents → twoColumnBrowseResultsRenderer for any
    // continuationItemRenderer token (used on mixed page 2+ responses where
    // the videos come from onResponseReceivedActions but the next-page token
    // is stored in the contents tree).
    String? tokenFromContents(Map<String, dynamic> data) {
      try {
        final twoCol = data['contents']
            ?['twoColumnBrowseResultsRenderer']
            ?['tabs'] as List?;
        final oneCol = data['contents']
            ?['singleColumnBrowseResultsRenderer']
            ?['tabs'] as List?;
        final tabs = twoCol ?? oneCol;
        if (tabs == null) return null;
        for (final tab in tabs) {
          if (tab is! Map) continue;
          final sectionContents = tab['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List?;
          if (sectionContents == null) continue;
          for (final section in sectionContents) {
            if (section is! Map) continue;
            // Token directly on the section
            final t = section['continuationItemRenderer']
                ?['continuationEndpoint']
                ?['continuationCommand']
                ?['token'] as String?;
            if (t != null && t.isNotEmpty) return t;
            // Token inside an ISR
            final isr = section['itemSectionRenderer']?['contents'] as List?;
            if (isr != null) {
              final t2 = tokenFromList(isr);
              if (t2 != null) return t2;
            }
            // Token inside a playlistVideoListRenderer
            final pvlr =
                section['playlistVideoListRenderer']?['contents'] as List?;
            if (pvlr != null) {
              final t3 = tokenFromList(pvlr);
              if (t3 != null) return t3;
            }
          }
        }
      } catch (_) {}
      return null;
    }

      // ── Continuation response (page 2+) ────────────────────────────────
      final actions = data['onResponseReceivedActions'] as List?;
      if (actions != null) {
        for (final action in actions) {
          if (action is! Map) continue;
          final contItems = action['appendContinuationItemsAction']
              ?['continuationItems'] as List?;
          if (contItems == null) continue;

          // Direct lockupViewModel items
          if (contItems.any((x) => x is Map && x.containsKey('lockupViewModel'))) {
            final token = tokenFromList(contItems) ?? tokenFromContents(data);
            return (items: stripContinuation(contItems), token: token);
          }
          // Direct playlistVideoRenderer items (old format)
          if (contItems.any((x) => x is Map && x.containsKey('playlistVideoRenderer'))) {
            final token = tokenFromList(contItems) ?? tokenFromContents(data);
            return (items: stripContinuation(contItems), token: token);
          }
          // Items wrapped inside an itemSectionRenderer
          for (final ci in contItems) {
            if (ci is! Map) continue;
            final isr = ci['itemSectionRenderer']?['contents'] as List?;
            if (isr == null) continue;
            if (isr.any((x) => x is Map &&
                (x.containsKey('lockupViewModel') ||
                    x.containsKey('playlistVideoRenderer')))) {
              final token = tokenFromList(isr)
                  ?? tokenFromList(contItems)
                  ?? tokenFromContents(data);
              return (items: stripContinuation(isr), token: token);
            }
          }
        }
      }
      return (items: <dynamic>[], token: null);
    } catch (_) {
      return (items: <dynamic>[], token: null);
    }
  }

  /// Reads a YouTube text run object: `{"runs":[{"text":"..."}]}` or
  /// `{"simpleText":"..."}`.
  String? _innerTubeText(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map) {
      final simple = obj['simpleText'];
      if (simple is String && simple.isNotEmpty) return simple;
      final runs = obj['runs'];
      if (runs is List && runs.isNotEmpty) {
        return runs
            .whereType<Map>()
            .map((r) => r['text'] as String? ?? '')
            .join();
      }
    }
    return null;
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
    const batchSize = 5;
    for (var start = 0; start < tracks.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, tracks.length);
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
        final newTracks = _spotifyPathfinderTrackNames(content['items']);
        tracks.addAll(newTracks);
        totalCount = content['totalCount'] as int? ?? tracks.length;

        // Stop when we've fetched everything.
        if (tracks.length >= totalCount) break;

        // Advance offset: use the API-provided nextOffset when available,
        // otherwise step by 100 (Spotify's page size) so we keep paginating
        // even when the anonymous token omits the pagingInfo.nextOffset field.
        final pagingInfo = content['pagingInfo'];
        final nextOffset =
            pagingInfo is Map ? pagingInfo['nextOffset'] as int? : null;
        if (nextOffset != null && nextOffset > offset) {
          offset = nextOffset;
        } else if (newTracks.isNotEmpty) {
          // Manual pagination: advance by the number of items received so
          // we never loop infinitely on an empty page.
          offset += newTracks.length;
        } else {
          // Empty page with no nextOffset — cannot make progress, stop.
          break;
        }
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

    // Collect ALL candidates from every query variation (up to 2 queries to
    // avoid hammering YouTube), then pick the best-scoring result.
    final seen = <String>{};
    final candidates = <Song>[];
    var queriesTried = 0;
    for (final query in queries) {
      if (queriesTried >= 2) break;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final results = await _youtube.search(query, maxResults: 10);
          for (final r in results) {
            if (seen.add(r.id)) candidates.add(r);
          }
          queriesTried++;
          break; // success — move to next query
        } catch (_) {
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 250 * (attempt + 1)),
            );
          }
        }
      }
      // If we already have a great match after the first query, stop early.
      if (candidates.isNotEmpty &&
          _scoreCandidate(candidates.first, track.title, track.artist) >= 60) {
        break;
      }
    }

    if (candidates.isEmpty) return null;

    // Score every candidate and return the highest-scoring one.
    // If even the best score is too low, return null rather than a wrong song.
    Song? best;
    var bestScore = -1;
    for (final c in candidates) {
      final score = _scoreCandidate(c, track.title, track.artist);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    // Minimum acceptance threshold: at least 20 points means the title
    // shares some meaningful words with the Spotify track name.
    return bestScore >= 20 ? best : null;
  }

  /// Score a YouTube candidate [song] against the Spotify [title] and
  /// optional [artist].  Higher = better match (0–100 scale, can exceed 100
  /// on strong matches — that is fine for ranking purposes).
  int _scoreCandidate(Song song, String title, String? artist) {
    final ytTitle = song.title.toLowerCase();
    final spTitle = title.toLowerCase();
    final spArtist = artist?.toLowerCase() ?? '';

    int score = 0;

    // ── Exact substring hits ──────────────────────────────────────────────
    if (ytTitle.contains(spTitle)) score += 50;
    if (spTitle.contains(ytTitle)) score += 40;
    if (spArtist.isNotEmpty && ytTitle.contains(spArtist)) score += 30;

    // ── Channel name matches artist ───────────────────────────────────────
    final ytChannel = song.channelName.toLowerCase();
    if (spArtist.isNotEmpty) {
      if (ytChannel.contains(spArtist) || spArtist.contains(ytChannel)) {
        score += 25;
      }
    }

    // ── Word-level overlap ────────────────────────────────────────────────
    final spWords = _tokenize(spTitle);
    final artWords = _tokenize(spArtist);
    final ytWords = _tokenize(ytTitle);

    // Stop-words we don't want to inflate the score on
    const stopWords = {'the', 'a', 'an', 'in', 'on', 'at', 'of', 'and',
        'or', 'to', 'is', 'it', 'ft', 'feat', 'remix', 'official',
        'video', 'audio', 'lyrics', 'hd', 'mv'};

    int titleOverlap = 0;
    for (final w in spWords) {
      if (stopWords.contains(w)) continue;
      if (ytWords.contains(w)) titleOverlap++;
    }
    if (spWords.isNotEmpty) {
      score += ((titleOverlap / spWords.length) * 40).round();
    }

    int artistOverlap = 0;
    for (final w in artWords) {
      if (stopWords.contains(w)) continue;
      if (ytWords.contains(w) || _tokenize(ytChannel).contains(w)) {
        artistOverlap++;
      }
    }
    if (artWords.isNotEmpty) {
      score += ((artistOverlap / artWords.length) * 20).round();
    }

    // ── Penalise undesired content ────────────────────────────────────────
    // Covers / karaoke / instrumental versions shouldn't be ranked above
    // originals unless the Spotify title specifically asks for them.
    final spLower = '$spTitle $spArtist';
    for (final noise in ['cover', 'karaoke', 'instrumental', 'tribute']) {
      if (ytTitle.contains(noise) && !spLower.contains(noise)) {
        score -= 20;
      }
    }

    return score;
  }

  /// Split a string into lower-case word tokens (letters/digits only).
  Set<String> _tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 1)
      .toSet();

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

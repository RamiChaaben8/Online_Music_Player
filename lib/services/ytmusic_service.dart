// lib/services/ytmusic_service.dart
// Communicates with the YouTube Music Innertube API (no API key required).
// All public methods are async, never throw to the caller, and cache results
// in memory for 30 minutes.

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/ytmusic_models.dart';

// ---------------------------------------------------------------------------
// Internal cache entry
// ---------------------------------------------------------------------------

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;

  _CacheEntry(this.data)
      : expiresAt = DateTime.now().add(const Duration(minutes: 30));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ---------------------------------------------------------------------------
// YtMusicService
// ---------------------------------------------------------------------------

class YtMusicService {
  YtMusicService._();
  static final YtMusicService instance = YtMusicService._();

  // ── HTTP constants ─────────────────────────────────────────────────────────

  static const String _baseUrl = 'https://music.youtube.com/youtubei/v1/';

  // Client version must be current; YouTube rejects stale versions with empty
  // or degraded responses.  Update this value if you see HTTP 200 but empty
  // sectionListRenderer.contents.
  static const String _clientVersion = '1.20250101.01.00';

  static const Map<String, dynamic> _clientContext = {
    'context': {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': _clientVersion,
        'hl': 'en',
        'gl': 'US',
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    },
  };

  // Static headers (X-Goog-Visitor-Id is added dynamically after fetch).
  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'X-YouTube-Client-Name': '67',
      'X-YouTube-Client-Version': _clientVersion,
    };
    if (_visitorId != null) {
      h['X-Goog-Visitor-Id'] = _visitorId!;
    }
    return h;
  }

  // ── Visitor ID ─────────────────────────────────────────────────────────────
  // YouTube Music requires a valid visitor-id (obtained by hitting the home
  // page with a GET request) to return non-empty personalised feeds.

  String? _visitorId;
  bool _visitorIdFetchStarted = false;

  Future<void> _ensureVisitorId() async {
    if (_visitorId != null) return;
    if (_visitorIdFetchStarted) {
      // Another call is already fetching — wait briefly then return
      await Future.delayed(const Duration(milliseconds: 600));
      return;
    }
    _visitorIdFetchStarted = true;
    try {
      final response = await http
          .get(
            Uri.parse('https://music.youtube.com/'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      // The visitor ID appears in the Set-Cookie header or in the response body
      // as "visitorData":"..." or "X-Goog-Visitor-Id: ..."
      final body = response.body;

      // Try to find it in the page source (ytcfg.set({...VISITOR_DATA...}))
      final RegExp visitorRe = RegExp(r'"visitorData"\s*:\s*"([^"]+)"');
      final match = visitorRe.firstMatch(body);
      if (match != null) {
        _visitorId = match.group(1);
        debugPrint('[YtMusicService] visitorId fetched: $_visitorId');
        return;
      }

      // Fall back to Set-Cookie
      final setCookie = response.headers['set-cookie'] ?? '';
      final cookieRe = RegExp(r'VISITOR_INFO1_LIVE=([^;]+)');
      final cookieMatch = cookieRe.firstMatch(setCookie);
      if (cookieMatch != null) {
        _visitorId = cookieMatch.group(1);
        debugPrint(
            '[YtMusicService] visitorId from cookie: $_visitorId');
        return;
      }

      // Nothing found — proceed without it (feed will still load, just not
      // personalised).
      debugPrint('[YtMusicService] visitorId not found; proceeding without.');
    } catch (e) {
      debugPrint('[YtMusicService] _ensureVisitorId error: $e');
    }
  }

  // ── In-memory cache ────────────────────────────────────────────────────────

  final Map<String, _CacheEntry> _cache = {};

  T? _getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  void _putCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data);
  }

  // ── Low-level POST ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    await _ensureVisitorId();
    final uri = Uri.parse('$_baseUrl$endpoint?prettyPrint=false');
    final merged = <String, dynamic>{
      ..._clientContext,
      ...body,
    };
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(merged))
          .timeout(const Duration(seconds: 20));

      debugPrint(
          '[YtMusicService] POST $endpoint → HTTP ${response.statusCode} '
          '(${response.bodyBytes.length} bytes)');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        debugPrint('[YtMusicService] Unexpected JSON type for $endpoint');
      } else {
        debugPrint(
            '[YtMusicService] Error body (first 400): '
            '${response.body.substring(0, response.body.length.clamp(0, 400))}');
      }
    } catch (e) {
      debugPrint('[YtMusicService] POST error ($endpoint): $e');
    }
    return null;
  }

  // ── Navigation helper ──────────────────────────────────────────────────────

  /// Safely drill into nested maps by [path]. Returns null on any mismatch.
  T? _nav<T>(dynamic root, List<Object> path) {
    dynamic cur = root;
    for (final key in path) {
      if (key is int) {
        if (cur is! List || key >= cur.length) return null;
        cur = cur[key];
      } else if (key is String) {
        if (cur is! Map) return null;
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur is T ? cur : null;
  }

  // ── Text helpers ───────────────────────────────────────────────────────────

  /// Concatenates all run texts from a `runs` list, or returns empty string.
  String _runs(dynamic obj) {
    if (obj == null) return '';
    final runs = obj['runs'];
    if (runs is! List) return '';
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map) {
        final text = run['text'];
        if (text is String) buffer.write(text);
      }
    }
    return buffer.toString().trim();
  }

  // ── Thumbnail helper ───────────────────────────────────────────────────────

  /// Picks the best square thumbnail URL from a list of thumbnail objects.
  /// Prefers 226×226; falls back to the largest one found.
  /// Forces square crops on Google's image CDN URLs.
  String _thumb(dynamic thumbnails) {
    if (thumbnails is! List || thumbnails.isEmpty) return '';

    String? best;
    int bestSize = -1;

    for (final t in thumbnails) {
      if (t is! Map) continue;
      final url = t['url'];
      if (url is! String || url.isEmpty) continue;
      final w = t['width'] is int ? t['width'] as int : 0;
      final h = t['height'] is int ? t['height'] as int : 0;
      // Exact match for the preferred square size
      if (w == 226 && h == 226) return _squarify(url);
      // Otherwise keep the largest thumbnail we've seen
      final area = w * h;
      if (area > bestSize) {
        bestSize = area;
        best = url;
      }
    }
    return best != null ? _squarify(best) : '';
  }

  /// Forces a square crop on Google's CDN image URLs.
  /// lh3.googleusercontent.com URLs accept `=w512-h512-c` to crop to a
  /// 512×512 square. Other URLs are returned unchanged.
  String _squarify(String url) {
    if (url.contains('lh3.googleusercontent.com')) {
      // Remove any existing size/crop parameters (everything after '=')
      final base = url.contains('=') ? url.substring(0, url.indexOf('=')) : url;
      return '$base=w512-h512-c';
    }
    // yt3.ggpht.com (artist photos) and i.ytimg.com thumbnails do not need squaring
    // because we always render them with BoxFit.cover in a square container.
    return url;
  }

  /// Extracts the thumbnail list from a standard `thumbnail` wrapper.
  String _thumbFromWrapper(dynamic wrapper) {
    if (wrapper is Map) {
      final inner = wrapper['thumbnails'] ?? wrapper['thumbnail'];
      if (inner is Map) return _thumbFromWrapper(inner);
      if (inner is List) return _thumb(inner);
    }
    if (wrapper is List) return _thumb(wrapper);
    return '';
  }

  // ── Duration helper ────────────────────────────────────────────────────────

  Duration _parseDuration(String? text) {
    if (text == null || text.isEmpty) return Duration.zero;
    try {
      final parts = text.split(':').map(int.parse).toList();
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      } else if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return Duration.zero;
  }

  // ── Quality / junk filter ──────────────────────────────────────────────────

  static const List<String> _junkKeywords = [
    'jukebox',
    'mashup',
    'no copyright',
    '1 hour',
    'compilation',
    'slowed',
    'reverb',
    'nightcore',
  ];

  bool _isJunk(String title) {
    final lower = title.toLowerCase();
    for (final kw in _junkKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  bool _songPassesFilter(YtSong song) {
    if (_isJunk(song.title)) { return false; }
    if (song.duration != Duration.zero &&
        song.duration > const Duration(minutes: 10)) { return false; }
    return true;
  }

  // ── Renderer parsers ───────────────────────────────────────────────────────

  /// Parse a `musicResponsiveListItemRenderer` into a [YtSong].
  YtSong? _parseSongFromResponsive(Map<String, dynamic> r) {
    try {
      String? videoId = _nav<String>(r, [
        'overlay',
        'musicItemThumbnailOverlayRenderer',
        'content',
        'musicPlayButtonRenderer',
        'playNavigationEndpoint',
        'watchEndpoint',
        'videoId'
      ]);
      videoId ??= _nav<String>(r, [
        'flexColumns',
        0,
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
        'runs',
        0,
        'navigationEndpoint',
        'watchEndpoint',
        'videoId'
      ]);
      videoId ??= _nav<String>(r, ['playlistItemData', 'videoId']);
      videoId ??=
          _nav<String>(r, ['navigationEndpoint', 'watchEndpoint', 'videoId']);

      if (videoId == null || videoId.isEmpty) return null;

      final titleObj = _nav<Map>(r, [
        'flexColumns',
        0,
        'musicResponsiveListItemFlexColumnRenderer',
        'text'
      ]);
      final title = _runs(titleObj);
      if (title.isEmpty) return null;

      final subtitleObj = _nav<Map>(r, [
        'flexColumns',
        1,
        'musicResponsiveListItemFlexColumnRenderer',
        'text'
      ]);
      final subtitleRuns = subtitleObj?['runs'];
      String artist = '';
      String? album;
      String durationText = '';

      if (subtitleRuns is List) {
        final texts = <String>[];
        for (final run in subtitleRuns) {
          if (run is Map) {
            final text = run['text'];
            if (text is String &&
                text.trim().isNotEmpty &&
                text.trim() != '•') {
              texts.add(text.trim());
            }
          }
        }
        if (texts.isNotEmpty) artist = texts[0];
        final thirdCol = _nav<Map>(r, [
          'flexColumns',
          2,
          'musicResponsiveListItemFlexColumnRenderer',
          'text'
        ]);
        durationText = _runs(thirdCol);
        if (texts.length >= 2 &&
            !RegExp(r'^\d+:\d+').hasMatch(texts[1])) {
          album = texts[1];
        }
      }

      final thumbWrapper = r['thumbnail'];
      final coverUrl = _thumbFromWrapper(thumbWrapper);
      final duration =
          _parseDuration(durationText.isNotEmpty ? durationText : null);

      return YtSong(
        videoId: videoId,
        title: title,
        artist: artist,
        album: album,
        coverUrl: coverUrl,
        duration: duration,
      );
    } catch (e) {
      debugPrint('[YtMusicService] _parseSongFromResponsive error: $e');
      return null;
    }
  }

  /// Parse a `musicTwoRowItemRenderer` into a [YtSong] (used in carousels).
  YtSong? _parseSongFromTwoRow(Map<String, dynamic> r) {
    try {
      String? videoId =
          _nav<String>(r, ['navigationEndpoint', 'watchEndpoint', 'videoId']);
      videoId ??= _nav<String>(r, [
        'overlay',
        'musicItemThumbnailOverlayRenderer',
        'content',
        'musicPlayButtonRenderer',
        'playNavigationEndpoint',
        'watchEndpoint',
        'videoId'
      ]);

      if (videoId == null || videoId.isEmpty) return null;

      final titleObj = r['title'];
      final title = _runs(titleObj);
      if (title.isEmpty) return null;

      final subtitleObj = r['subtitle'];
      final subtitleText = _runs(subtitleObj);
      String artist = subtitleText;
      if (subtitleText.contains(' • ')) {
        artist = subtitleText.split(' • ').last.trim();
      }

      final thumbWrapper = r['thumbnailRenderer'] ?? r['thumbnail'];
      final coverUrl = _thumbFromWrapper(thumbWrapper);

      return YtSong(
        videoId: videoId,
        title: title,
        artist: artist,
        album: null,
        coverUrl: coverUrl,
        duration: Duration.zero,
      );
    } catch (e) {
      debugPrint('[YtMusicService] _parseSongFromTwoRow error: $e');
      return null;
    }
  }

  /// Parse a `musicTwoRowItemRenderer` into a [YtAlbum].
  YtAlbum? _parseAlbumFromTwoRow(Map<String, dynamic> r) {
    try {
      final browseId =
          _nav<String>(r, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
      if (browseId == null || browseId.isEmpty) return null;

      final titleObj = r['title'];
      final title = _runs(titleObj);
      if (title.isEmpty) return null;

      final subtitleObj = r['subtitle'];
      final subtitleText = _runs(subtitleObj);
      String artist = '';
      int? year;
      YtAlbumType albumType = YtAlbumType.unknown;

      final parts = subtitleText.split(' • ');
      for (final part in parts) {
        final trimmed = part.trim();
        final parsed = int.tryParse(trimmed);
        if (parsed != null && parsed > 1900 && parsed < 2200) {
          year = parsed;
        } else if (trimmed.toLowerCase() == 'album') {
          albumType = YtAlbumType.album;
        } else if (trimmed.toLowerCase() == 'single') {
          albumType = YtAlbumType.single;
        } else if (trimmed.toLowerCase() == 'ep') {
          albumType = YtAlbumType.ep;
        } else if (trimmed.isNotEmpty) {
          if (artist.isEmpty) artist = trimmed;
        }
      }

      // Check for explicit badge in subtitleBadges
      bool isExplicit = false;
      final subtitleBadges = r['subtitleBadges'];
      if (subtitleBadges is List) {
        for (final badge in subtitleBadges) {
          if (badge is! Map) continue;
          final badgeRenderer = badge['musicInlineBadgeRenderer'];
          if (badgeRenderer is Map) {
            final iconType = _nav<String>(
                badgeRenderer, ['icon', 'iconType']);
            if (iconType == 'MUSIC_EXPLICIT_BADGE') {
              isExplicit = true;
              break;
            }
          }
        }
      }

      final thumbWrapper = r['thumbnailRenderer'] ?? r['thumbnail'];
      final coverUrl = _thumbFromWrapper(thumbWrapper);

      return YtAlbum(
        browseId: browseId,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        year: year,
        type: albumType,
        isExplicit: isExplicit,
      );
    } catch (e) {
      debugPrint('[YtMusicService] _parseAlbumFromTwoRow error: $e');
      return null;
    }
  }

  /// Parse a `musicTwoRowItemRenderer` into a [YtArtist].
  YtArtist? _parseArtistFromTwoRow(Map<String, dynamic> r) {
    try {
      final browseId =
          _nav<String>(r, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
      if (browseId == null || browseId.isEmpty) return null;

      final titleObj = r['title'];
      final name = _runs(titleObj);
      if (name.isEmpty) return null;

      final thumbWrapper = r['thumbnailRenderer'] ?? r['thumbnail'];
      final pictureUrl = _thumbFromWrapper(thumbWrapper);

      return YtArtist(browseId: browseId, name: name, pictureUrl: pictureUrl);
    } catch (e) {
      debugPrint('[YtMusicService] _parseArtistFromTwoRow error: $e');
      return null;
    }
  }

  /// Parse a `musicTwoRowItemRenderer` into a [YtPlaylist].
  YtPlaylist? _parsePlaylistFromTwoRow(Map<String, dynamic> r) {
    try {
      String? browseId =
          _nav<String>(r, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
      browseId ??= _nav<String>(r, [
        'navigationEndpoint',
        'watchPlaylistEndpoint',
        'playlistId'
      ]);

      if (browseId == null || browseId.isEmpty) return null;

      final titleObj = r['title'];
      final title = _runs(titleObj);
      if (title.isEmpty) return null;

      final subtitleObj = r['subtitle'];
      final subtitle = _runs(subtitleObj);

      final thumbWrapper = r['thumbnailRenderer'] ?? r['thumbnail'];
      final coverUrl = _thumbFromWrapper(thumbWrapper);

      return YtPlaylist(
        browseId: browseId,
        title: title,
        subtitle: subtitle,
        coverUrl: coverUrl,
      );
    } catch (e) {
      debugPrint('[YtMusicService] _parsePlaylistFromTwoRow error: $e');
      return null;
    }
  }

  // ── Shelf / section parsing ────────────────────────────────────────────────

  _ShelfType _detectShelfType(List<dynamic> items) {
    for (final item in items) {
      if (item is! Map) continue;
      final twoRow = item['musicTwoRowItemRenderer'];
      if (twoRow is Map) {
        final endpoint =
            _nav<Map>(twoRow, ['navigationEndpoint', 'browseEndpoint']);
        if (endpoint != null) {
          final pageType = _nav<String>(endpoint, [
            'browseEndpointContextSupportedConfigs',
            'browseEndpointContextMusicConfig',
            'pageType'
          ]);
          if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') { return _ShelfType.artist; }
          if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' ||
              pageType == 'MUSIC_PAGE_TYPE_SINGLE') { return _ShelfType.album; }
          if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST') {
            return _ShelfType.playlist;
          }
        }
        final watchId = _nav<String>(
            twoRow, ['navigationEndpoint', 'watchEndpoint', 'videoId']);
        if (watchId != null) { return _ShelfType.song; }
      }
      if (item['musicResponsiveListItemRenderer'] != null) {
        return _ShelfType.song;
      }
    }
    return _ShelfType.song;
  }

  YtSection _parseShelf(Map<String, dynamic> shelf) {
    final headerTitle = _nav<Map>(shelf, [
          'header',
          'musicCarouselShelfBasicHeaderRenderer',
          'title'
        ]) ??
        _nav<Map>(shelf, [
          'header',
          'musicImmersiveCarouselShelfRenderer',
          'title'
        ]);
    final title = _runs(headerTitle);

    final rawContents = shelf['contents'];
    if (rawContents is! List || rawContents.isEmpty) {
      return YtSection(
          title: title, songs: [], albums: [], artists: [], playlists: []);
    }

    final type = _detectShelfType(rawContents);
    final songs = <YtSong>[];
    final albums = <YtAlbum>[];
    final artists = <YtArtist>[];
    final playlists = <YtPlaylist>[];

    for (final item in rawContents) {
      if (item is! Map) continue;
      final twoRow = item['musicTwoRowItemRenderer'];
      final responsive = item['musicResponsiveListItemRenderer'];

      switch (type) {
        case _ShelfType.song:
          if (twoRow is Map) {
            final song =
                _parseSongFromTwoRow(Map<String, dynamic>.from(twoRow));
            if (song != null && song.isValid && _songPassesFilter(song)) {
              songs.add(song);
            }
          } else if (responsive is Map) {
            final song = _parseSongFromResponsive(
                Map<String, dynamic>.from(responsive));
            if (song != null && song.isValid && _songPassesFilter(song)) {
              songs.add(song);
            }
          }
          break;
        case _ShelfType.album:
          if (twoRow is Map) {
            final album =
                _parseAlbumFromTwoRow(Map<String, dynamic>.from(twoRow));
            if (album != null && album.isValid) albums.add(album);
          }
          break;
        case _ShelfType.artist:
          if (twoRow is Map) {
            final artist =
                _parseArtistFromTwoRow(Map<String, dynamic>.from(twoRow));
            if (artist != null && artist.isValid) artists.add(artist);
          }
          break;
        case _ShelfType.playlist:
          if (twoRow is Map) {
            final playlist =
                _parsePlaylistFromTwoRow(Map<String, dynamic>.from(twoRow));
            if (playlist != null && playlist.isValid) playlists.add(playlist);
          }
          break;
      }
    }

    return YtSection(
        title: title,
        songs: songs,
        albums: albums,
        artists: artists,
        playlists: playlists);
  }

  /// Parses the `sectionListRenderer.contents` array into sections + mood chips.
  (List<YtSection>, List<YtMoodChip>) _parseSectionList(
      List<dynamic> contents) {
    final sections = <YtSection>[];
    final chips = <YtMoodChip>[];

    for (final item in contents) {
      if (item is! Map) continue;

      // ── Mood chips from chipCloudRenderer ─────────────────────────────────
      final chipCloud =
          item['chipCloudRenderer'] as Map?;
      if (chipCloud != null) {
        final chipItems = chipCloud['chips'];
        if (chipItems is List) {
          for (final chip in chipItems) {
            if (chip is! Map) continue;
            final chipRenderer = chip['chipCloudChipRenderer'];
            if (chipRenderer is! Map) continue;
            final label = _runs(chipRenderer['text']);
            // chips use browseEndpoint with a params field
            final params = _nav<String>(chipRenderer, [
                  'navigationEndpoint',
                  'browseEndpoint',
                  'params'
                ]) ??
                _nav<String>(chipRenderer,
                    ['navigationEndpoint', 'browseEndpoint', 'browseId']);
            if (label.isNotEmpty && params != null && params.isNotEmpty) {
              chips.add(YtMoodChip(label: label, params: params));
            }
          }
        }
      }

      // ── Carousel shelves ──────────────────────────────────────────────────
      final carousel = item['musicCarouselShelfRenderer'] as Map? ??
          item['musicImmersiveCarouselShelfRenderer'] as Map?;
      if (carousel != null) {
        final section = _parseShelf(Map<String, dynamic>.from(carousel));
        if (section.isNotEmpty) {
          debugPrint(
              '[YtMusicService] section "${section.title}": '
              '${section.songs.length} songs, ${section.albums.length} albums, '
              '${section.artists.length} artists, '
              '${section.playlists.length} playlists');
          sections.add(section);
        }
        continue;
      }

      // ── musicCardShelfRenderer (sometimes used for "Quick picks") ─────────
      final cardShelf = item['musicCardShelfRenderer'] as Map?;
      if (cardShelf != null) {
        final titleObj = _nav<Map>(cardShelf, ['title']);
        final shelfTitle = _runs(titleObj);
        final songs = <YtSong>[];

        // The header itself may be a song
        final headerVideoId = _nav<String>(
            cardShelf, ['title', 'runs', 0, 'navigationEndpoint',
            'watchEndpoint', 'videoId']);
        if (headerVideoId != null && headerVideoId.isNotEmpty) {
          final headerTitle = _runs(cardShelf['title']);
          final subtitleObj = cardShelf['subtitle'];
          final subtitleText = _runs(subtitleObj);
          String artist = subtitleText;
          if (subtitleText.contains(' • ')) {
            artist = subtitleText.split(' • ').last.trim();
          }
          final thumbWrapper =
              cardShelf['thumbnail'] ?? cardShelf['thumbnailRenderer'];
          final coverUrl = _thumbFromWrapper(thumbWrapper);
          final song = YtSong(
            videoId: headerVideoId,
            title: headerTitle,
            artist: artist,
            coverUrl: coverUrl,
            duration: Duration.zero,
          );
          if (song.isValid && _songPassesFilter(song)) songs.add(song);
        }

        // Additional items (usually musicResponsiveListItemRenderer)
        final contents = cardShelf['contents'];
        if (contents is List) {
          for (final r in contents) {
            if (r is! Map) continue;
            final responsive = r['musicResponsiveListItemRenderer'];
            if (responsive is Map) {
              final song = _parseSongFromResponsive(
                  Map<String, dynamic>.from(responsive));
              if (song != null && song.isValid && _songPassesFilter(song)) {
                songs.add(song);
              }
            }
            final twoRow = r['musicTwoRowItemRenderer'];
            if (twoRow is Map) {
              final song =
                  _parseSongFromTwoRow(Map<String, dynamic>.from(twoRow));
              if (song != null && song.isValid && _songPassesFilter(song)) {
                songs.add(song);
              }
            }
          }
        }

        if (songs.isNotEmpty) {
          debugPrint(
              '[YtMusicService] cardShelf "$shelfTitle": ${songs.length} songs');
          sections.add(YtSection(
              title: shelfTitle,
              songs: songs,
              albums: [],
              artists: [],
              playlists: []));
        }
        continue;
      }

      // ── gridRenderer (used on moods & genres page) ────────────────────────
      final grid = item['gridRenderer'] as Map?;
      if (grid != null) {
        final gridItems = grid['items'];
        if (gridItems is List) {
          final localChips = <YtMoodChip>[];
          for (final gridItem in gridItems) {
            if (gridItem is! Map) continue;
            final btn = gridItem['musicNavigationButtonRenderer'];
            if (btn is! Map) continue;
            final label = _runs(btn['buttonText']);
            final params = _nav<String>(
                btn, ['clickCommand', 'browseEndpoint', 'params']);
            if (label.isNotEmpty && params != null && params.isNotEmpty) {
              localChips.add(YtMoodChip(label: label, params: params));
            }
          }
          chips.addAll(localChips);
        }
        continue;
      }

      // ── musicShelfRenderer (artist pages, explore) ────────────────────────
      final shelf = item['musicShelfRenderer'] as Map?;
      if (shelf != null) {
        final shelfContents = shelf['contents'];
        if (shelfContents is List) {
          final titleObj = _nav<Map>(shelf, ['title']);
          final shelfTitle = _runs(titleObj);
          final songs = <YtSong>[];
          for (final r in shelfContents) {
            if (r is! Map) continue;
            final responsive = r['musicResponsiveListItemRenderer'];
            if (responsive is Map) {
              final song = _parseSongFromResponsive(
                  Map<String, dynamic>.from(responsive));
              if (song != null && song.isValid && _songPassesFilter(song)) {
                songs.add(song);
              }
            }
          }
          if (songs.isNotEmpty) {
            debugPrint(
                '[YtMusicService] musicShelf "$shelfTitle": '
                '${songs.length} songs');
            sections.add(YtSection(
                title: shelfTitle,
                songs: songs,
                albums: [],
                artists: [],
                playlists: []));
          }
        }
      }
    }

    debugPrint(
        '[YtMusicService] _parseSectionList: ${sections.length} sections, '
        '${chips.length} chips');
    return (sections, chips);
  }

  // ── Helper: extract sectionList contents from a browse response ────────────

  List<dynamic>? _sectionContentsFromBrowse(Map<String, dynamic> body) {
    // Path 1: singleColumnBrowseResultsRenderer → tabs[0]
    // tabs is a List<dynamic> so we must index with int, not string.
    final tabs = _nav<List>(
        body, ['contents', 'singleColumnBrowseResultsRenderer', 'tabs']);
    if (tabs != null && tabs.isNotEmpty) {
      final tab = tabs[0]; // List, so int index
      if (tab is Map) {
        final contents = _nav<List>(tab, [
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents'
        ]);
        if (contents != null) {
          debugPrint(
              '[YtMusicService] sectionContents via tabs[0]: '
              '${contents.length} items');
          return contents;
        }
      }
    }

    // Path 2: twoColumnBrowseResultsRenderer secondary tab
    final tabs2 = _nav<List>(
        body, ['contents', 'twoColumnBrowseResultsRenderer', 'tabs']);
    if (tabs2 != null && tabs2.isNotEmpty) {
      final tab = tabs2[0];
      if (tab is Map) {
        final contents = _nav<List>(tab, [
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents'
        ]);
        if (contents != null) {
          debugPrint(
              '[YtMusicService] sectionContents via twoColumn tabs[0]: '
              '${contents.length} items');
          return contents;
        }
      }
    }

    // Path 3: direct sectionListRenderer (some browse pages)
    final direct = _nav<List>(body, ['contents', 'sectionListRenderer', 'contents']);
    if (direct != null) {
      debugPrint(
          '[YtMusicService] sectionContents via direct sectionListRenderer: '
          '${direct.length} items');
      return direct;
    }

    debugPrint(
        '[YtMusicService] _sectionContentsFromBrowse: no known path matched. '
        'Top-level keys: ${body.keys.toList()}');
    return null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches the YouTube Music home feed.
  Future<(List<YtSection>, List<YtMoodChip>)> getHomeFeed() async {
    const cacheKey = 'home_feed';
    final cached =
        _getCached<(List<YtSection>, List<YtMoodChip>)>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint('[YtMusicService] getHomeFeed: fetching FEmusic_home');
      final body = await _post('browse', {'browseId': 'FEmusic_home'});
      if (body == null) {
        debugPrint('[YtMusicService] getHomeFeed: body is null');
        return (<YtSection>[], <YtMoodChip>[]);
      }

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) {
        debugPrint('[YtMusicService] getHomeFeed: no section contents');
        return (<YtSection>[], <YtMoodChip>[]);
      }

      final result = _parseSectionList(contents);
      debugPrint(
          '[YtMusicService] getHomeFeed: ${result.$1.length} sections, '
          '${result.$2.length} chips');
      _putCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[YtMusicService] getHomeFeed error: $e');
      return (<YtSection>[], <YtMoodChip>[]);
    }
  }

  /// Fetches the home feed filtered by a mood / genre params string.
  Future<List<YtSection>> getHomeFeedForMood(String params) async {
    final cacheKey = 'home_mood_$params';
    final cached = _getCached<List<YtSection>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint(
          '[YtMusicService] getHomeFeedForMood: params=${params.substring(0, params.length.clamp(0, 30))}...');
      final body = await _post(
          'browse', {'browseId': 'FEmusic_home', 'params': params});
      if (body == null) return [];

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) return [];

      final (sections, _) = _parseSectionList(contents);
      debugPrint(
          '[YtMusicService] getHomeFeedForMood: ${sections.length} sections');
      _putCache(cacheKey, sections);
      return sections;
    } catch (e) {
      debugPrint('[YtMusicService] getHomeFeedForMood error: $e');
      return [];
    }
  }

  /// Fetches the Explore page (new releases, charts).
  Future<List<YtSection>> getExplore() async {
    const cacheKey = 'explore';
    final cached = _getCached<List<YtSection>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint('[YtMusicService] getExplore: fetching FEmusic_explore');
      final body = await _post('browse', {'browseId': 'FEmusic_explore'});
      if (body == null) return [];

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) return [];

      final (sections, _) = _parseSectionList(contents);
      debugPrint('[YtMusicService] getExplore: ${sections.length} sections');
      _putCache(cacheKey, sections);
      return sections;
    } catch (e) {
      debugPrint('[YtMusicService] getExplore error: $e');
      return [];
    }
  }

  /// Fetches mood and genre navigation chips from FEmusic_moods_and_genres.
  Future<List<YtMoodChip>> getMoodsAndGenres() async {
    const cacheKey = 'moods_genres';
    final cached = _getCached<List<YtMoodChip>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint(
          '[YtMusicService] getMoodsAndGenres: fetching FEmusic_moods_and_genres');
      final body =
          await _post('browse', {'browseId': 'FEmusic_moods_and_genres'});
      if (body == null) return [];

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) return [];

      final (_, chips) = _parseSectionList(contents);
      debugPrint('[YtMusicService] getMoodsAndGenres: ${chips.length} chips');
      _putCache(cacheKey, chips);
      return chips;
    } catch (e) {
      debugPrint('[YtMusicService] getMoodsAndGenres error: $e');
      return [];
    }
  }

  /// Searches YouTube Music for songs matching [query].
  Future<List<YtSong>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = 'search_${query.toLowerCase().trim()}';
    final cached = _getCached<List<YtSong>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint('[YtMusicService] searchSongs: "$query"');
      final body = await _post('search', {
        'query': query,
        'params': 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D',
      });
      if (body == null) return [];

      final tabs = _nav<List>(
          body, ['contents', 'tabbedSearchResultsRenderer', 'tabs']);
      if (tabs == null || tabs.isEmpty) return [];

      final tab = tabs[0];
      if (tab is! Map) return [];
      final sectionContents = _nav<List>(
          tab, ['tabRenderer', 'content', 'sectionListRenderer', 'contents']);
      if (sectionContents == null) return [];

      final songs = <YtSong>[];
      for (final item in sectionContents) {
        if (item is! Map) continue;
        final shelf = item['musicShelfRenderer'];
        if (shelf is! Map) continue;
        final shelfContents = shelf['contents'];
        if (shelfContents is! List) continue;
        for (final r in shelfContents) {
          if (r is! Map) continue;
          final responsive = r['musicResponsiveListItemRenderer'];
          if (responsive is Map) {
            final song = _parseSongFromResponsive(
                Map<String, dynamic>.from(responsive));
            if (song != null && song.isValid && _songPassesFilter(song)) {
              songs.add(song);
            }
          }
        }
      }

      debugPrint('[YtMusicService] searchSongs "$query": ${songs.length} songs');
      _putCache(cacheKey, songs);
      return songs;
    } catch (e) {
      debugPrint('[YtMusicService] searchSongs error: $e');
      return [];
    }
  }

  /// Returns the top songs for an artist identified by [artistBrowseId].
  Future<List<YtSong>> getArtistTopSongs(String artistBrowseId) async {
    if (artistBrowseId.isEmpty) return [];

    final cacheKey = 'artist_songs_$artistBrowseId';
    final cached = _getCached<List<YtSong>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint(
          '[YtMusicService] getArtistTopSongs: browseId=$artistBrowseId');
      final body = await _post('browse', {'browseId': artistBrowseId});
      if (body == null) return [];

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) return [];

      final songs = <YtSong>[];

      for (final item in contents) {
        if (item is! Map) continue;
        final shelf = item['musicShelfRenderer'];
        if (shelf is! Map) continue;

        final titleObj = _nav<Map>(shelf, ['title']);
        final titleText = _runs(titleObj).toLowerCase();
        final hasSongsTitle =
            titleText.contains('song') || titleText.isEmpty;
        final hasBottomEndpoint = shelf['bottomEndpoint'] != null;
        if (!hasSongsTitle && !hasBottomEndpoint) continue;

        final shelfContents = shelf['contents'];
        if (shelfContents is! List) continue;

        for (final r in shelfContents) {
          if (r is! Map) continue;
          final responsive = r['musicResponsiveListItemRenderer'];
          if (responsive is Map) {
            final song = _parseSongFromResponsive(
                Map<String, dynamic>.from(responsive));
            if (song != null && song.isValid && _songPassesFilter(song)) {
              songs.add(song);
            }
          }
        }
        if (songs.isNotEmpty) break;
      }

      debugPrint(
          '[YtMusicService] getArtistTopSongs $artistBrowseId: '
          '${songs.length} songs');
      _putCache(cacheKey, songs);
      return songs;
    } catch (e) {
      debugPrint('[YtMusicService] getArtistTopSongs error: $e');
      return [];
    }
  }

  /// Returns artists related to [artistBrowseId].
  Future<List<YtArtist>> getRelatedArtists(String artistBrowseId) async {
    if (artistBrowseId.isEmpty) return [];

    final cacheKey = 'related_artists_$artistBrowseId';
    final cached = _getCached<List<YtArtist>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint(
          '[YtMusicService] getRelatedArtists: browseId=$artistBrowseId');
      final body = await _post('browse', {'browseId': artistBrowseId});
      if (body == null) return [];

      final contents = _sectionContentsFromBrowse(body);
      if (contents == null) return [];

      const relatedKeywords = [
        'fans might also like',
        'related artists',
        'similar'
      ];

      for (final item in contents) {
        if (item is! Map) continue;
        final carousel = item['musicCarouselShelfRenderer'];
        if (carousel is! Map) continue;

        final headerTitle = _nav<Map>(carousel,
            ['header', 'musicCarouselShelfBasicHeaderRenderer', 'title']);
        final title = _runs(headerTitle).toLowerCase();
        final isRelated = relatedKeywords.any((kw) => title.contains(kw));
        if (!isRelated) continue;

        final shelfContents = carousel['contents'];
        if (shelfContents is! List) continue;

        final artists = <YtArtist>[];
        for (final r in shelfContents) {
          if (r is! Map) continue;
          final twoRow = r['musicTwoRowItemRenderer'];
          if (twoRow is Map) {
            final artist =
                _parseArtistFromTwoRow(Map<String, dynamic>.from(twoRow));
            if (artist != null && artist.isValid) artists.add(artist);
          }
        }
        if (artists.isNotEmpty) {
          debugPrint(
              '[YtMusicService] getRelatedArtists: ${artists.length} artists');
          _putCache(cacheKey, artists);
          return artists;
        }
      }

      _putCache(cacheKey, <YtArtist>[]);
      return [];
    } catch (e) {
      debugPrint('[YtMusicService] getRelatedArtists error: $e');
      return [];
    }
  }

  /// Returns the "Up Next" queue for a given [videoId].
  Future<List<YtSong>> getUpNext(String videoId) async {
    if (videoId.isEmpty) return [];

    final cacheKey = 'upnext_$videoId';
    final cached = _getCached<List<YtSong>>(cacheKey);
    if (cached != null) return cached;

    try {
      debugPrint('[YtMusicService] getUpNext: videoId=$videoId');
      final body = await _post('next', {
        'videoId': videoId,
        'isAudioOnly': true,
      });
      if (body == null) return [];

      final tabs = _nav<List>(body, [
        'contents',
        'singleColumnMusicWatchNextResultsRenderer',
        'tabbedRenderer',
        'watchNextTabbedResultsRenderer',
        'tabs',
      ]);
      if (tabs == null) return [];

      List<dynamic>? queueContents;
      for (final tab in tabs) {
        if (tab is! Map) continue;
        final tabRenderer = tab['tabRenderer'];
        if (tabRenderer is! Map) continue;
        final tabTitle = _nav<String>(tabRenderer, ['title']) ?? '';
        if (tabTitle.toLowerCase().contains('up next') ||
            tabTitle.toLowerCase().contains('queue')) {
          queueContents = _nav<List>(tabRenderer, [
            'content',
            'musicQueueRenderer',
            'content',
            'playlistPanelRenderer',
            'contents',
          ]);
          break;
        }
      }

      if (queueContents == null && tabs.isNotEmpty) {
        final firstTab = tabs[0];
        if (firstTab is Map) {
          final tabRenderer = firstTab['tabRenderer'];
          if (tabRenderer is Map) {
            queueContents = _nav<List>(tabRenderer, [
              'content',
              'musicQueueRenderer',
              'content',
              'playlistPanelRenderer',
              'contents',
            ]);
          }
        }
      }

      if (queueContents == null) return [];

      final songs = <YtSong>[];
      for (final item in queueContents) {
        if (item is! Map) continue;
        final panelVideo = item['playlistPanelVideoRenderer'];
        if (panelVideo is! Map) continue;

        final vid = _nav<String>(panelVideo, ['videoId']);
        if (vid == null || vid.isEmpty || vid == videoId) continue;

        final titleObj = panelVideo['title'];
        final title = _runs(titleObj);
        if (title.isEmpty) continue;

        final shortByline = panelVideo['shortBylineText'];
        final artist = _runs(shortByline);

        final thumbWrapper = panelVideo['thumbnail'];
        final coverUrl = _thumbFromWrapper(thumbWrapper);

        final durationText =
            _nav<String>(panelVideo, ['lengthText', 'runs', 0, 'text']) ??
                _runs(panelVideo['lengthText']);
        final duration = _parseDuration(durationText);

        final song = YtSong(
          videoId: vid,
          title: title,
          artist: artist,
          coverUrl: coverUrl,
          duration: duration,
        );

        if (song.isValid && _songPassesFilter(song)) {
          songs.add(song);
        }
      }

      debugPrint('[YtMusicService] getUpNext $videoId: ${songs.length} songs');
      _putCache(cacheKey, songs);
      return songs;
    } catch (e) {
      debugPrint('[YtMusicService] getUpNext error: $e');
      return [];
    }
  }

  /// Returns a personalised "Albums for you" list by merging three sources:
  /// 1. [homeAlbums] — album shelves already parsed from the home feed (free).
  /// 2. Albums/Singles from top artist pages ([topArtistBrowseIds]).
  /// 3. Album shelves from getExplore() (cached — usually instant).
  /// Results are deduped and capped at 20. Cached 30 min.
  Future<List<YtAlbum>> getAlbumsForYou({
    List<String> topArtistBrowseIds = const [],
    List<YtAlbum> homeAlbums = const [],
  }) async {
    const cacheKey = 'albums_for_you';
    final cached = _getCached<List<YtAlbum>>(cacheKey);
    if (cached != null) return cached;

    final seen = <String>{}; // browseId dedup
    final seenTitleArtist = <String>{}; // title+artist dedup
    final albums = <YtAlbum>[];

    void addAlbum(YtAlbum a) {
      if (!a.isValid) return;
      if (!seen.add(a.browseId)) return;
      final key =
          '${a.title.toLowerCase().trim()}|${a.artist.toLowerCase().trim()}';
      if (!seenTitleArtist.add(key)) return;
      albums.add(a);
    }

    // ── 1. Home feed albums (passed in — already fetched, no extra HTTP) ──────
    debugPrint('[YtMusicService] getAlbumsForYou: '
        '${homeAlbums.length} home albums seeded');
    for (final a in homeAlbums) { addAlbum(a); }

    // ── 2. Top artist pages ───────────────────────────────────────────────────
    if (topArtistBrowseIds.isNotEmpty && albums.length < 20) {
      debugPrint('[YtMusicService] getAlbumsForYou: '
          '${topArtistBrowseIds.length} artist pages');
      for (var i = 0;
          i < topArtistBrowseIds.length && albums.length < 20;
          i += 4) {
        final batch = topArtistBrowseIds
            .sublist(i, (i + 4).clamp(0, topArtistBrowseIds.length));
        final futures = batch.map((artistId) async {
          try {
            final body = await _post('browse', {'browseId': artistId});
            if (body == null) return <YtAlbum>[];
            final contents = _sectionContentsFromBrowse(body);
            if (contents == null) return <YtAlbum>[];
            final result = <YtAlbum>[];
            for (final item in contents) {
              if (item is! Map) continue;
              final carousel = item['musicCarouselShelfRenderer'] as Map?;
              if (carousel == null) continue;
              final headerTitle = _nav<Map>(carousel, [
                'header',
                'musicCarouselShelfBasicHeaderRenderer',
                'title'
              ]);
              final shelfTitle = _runs(headerTitle).toLowerCase();
              if (!shelfTitle.contains('album') &&
                  !shelfTitle.contains('single') &&
                  !shelfTitle.contains('release')) { continue; }
              final shelfContents = carousel['contents'];
              if (shelfContents is! List) continue;
              for (final r in shelfContents) {
                if (r is! Map) continue;
                final twoRow = r['musicTwoRowItemRenderer'];
                if (twoRow is! Map) continue;
                final album = _parseAlbumFromTwoRow(
                    Map<String, dynamic>.from(twoRow));
                if (album != null) result.add(album);
              }
            }
            return result;
          } catch (e) {
            debugPrint('[YtMusicService] artist $artistId albums error: $e');
            return <YtAlbum>[];
          }
        });
        for (final list in await Future.wait(futures)) {
          for (final a in list) { addAlbum(a); }
        }
      }
      debugPrint(
          '[YtMusicService] getAlbumsForYou after artists: ${albums.length}');
    }

    // ── 3. Explore (cached after getExplore() already ran) ───────────────────
    if (albums.length < 20) {
      try {
        final exploreSections = await getExplore();
        debugPrint('[YtMusicService] getAlbumsForYou explore: '
            '${exploreSections.length} sections');
        for (final section in exploreSections) {
          for (final a in section.albums) { addAlbum(a); }
          for (final p in section.playlists) {
            addAlbum(YtAlbum(
              browseId: p.browseId,
              title: p.title,
              artist: p.subtitle,
              coverUrl: p.coverUrl,
            ));
          }
        }
        debugPrint(
            '[YtMusicService] getAlbumsForYou after explore: ${albums.length}');
      } catch (e) {
        debugPrint('[YtMusicService] getAlbumsForYou explore error: $e');
      }
    }

    final result = albums.take(20).toList();
    debugPrint('[YtMusicService] getAlbumsForYou FINAL: ${result.length}');
    if (result.isNotEmpty) _putCache(cacheKey, result);
    return result;
  }

  /// Fetches an album's metadata and track list by [browseId].
  Future<AlbumTracksData> getAlbumTracks(String browseId) async {
    final cacheKey = 'album_tracks_$browseId';
    final cached = _getCached<AlbumTracksData>(cacheKey);
    if (cached != null) return cached;

    final body = await _post('browse', {'browseId': browseId});
    if (body == null) throw Exception('No response for $browseId');

    // ── Header metadata ────────────────────────────────────────────────────
    String title = '';
    String artist = '';
    String coverUrl = '';
    String year = '';

    final header = _nav<Map>(body, ['header', 'musicImmersiveHeaderRenderer']) ??
        _nav<Map>(body, ['header', 'musicDetailHeaderRenderer']);
    if (header != null) {
      title = _runs(header['title']);
      artist = _runs(header['subtitle']);
      final subParts = artist.split(' • ');
      for (final part in subParts) {
        final y = int.tryParse(part.trim());
        if (y != null && y > 1900 && y < 2200) {
          year = part.trim();
          break;
        }
      }
      final thumbList = _nav<List>(header, [
            'thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails'
          ]) ??
          _nav<List>(header, ['thumbnail', 'thumbnails']) ??
          _nav<List>(header, [
            'thumbnailRenderer', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails'
          ]);
      if (thumbList != null) {
        coverUrl = _thumb(thumbList);
      }
    }

    // ── Track list ─────────────────────────────────────────────────────────
    final contents = _sectionContentsFromBrowse(body);
    final tracks = <YtSong>[];

    if (contents != null) {
      for (final item in contents) {
        if (item is! Map) continue;
        final shelf = item['musicShelfRenderer'] as Map?;
        if (shelf == null) continue;
        final shelfContents = shelf['contents'];
        if (shelfContents is! List) continue;
        for (final r in shelfContents) {
          if (r is! Map) continue;
          final responsive = r['musicResponsiveListItemRenderer'];
          if (responsive is! Map) continue;
          final song = _parseSongFromResponsive(
              Map<String, dynamic>.from(responsive));
          if (song != null && song.isValid) {
            final cover = song.coverUrl.isNotEmpty ? song.coverUrl : coverUrl;
            tracks.add(YtSong(
              videoId: song.videoId,
              title: song.title,
              artist: song.artist.isNotEmpty ? song.artist : artist,
              album: title,
              coverUrl: cover,
              duration: song.duration,
            ));
          }
        }
        if (tracks.isNotEmpty) break;
      }
    }

    final result = AlbumTracksData(
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      year: year,
      tracks: tracks,
    );

    debugPrint('[YtMusicService] getAlbumTracks $browseId: '
        '"$title" by "$artist" — ${tracks.length} tracks');
    _putCache(cacheKey, result);
    return result;
  }

  /// Clears the entire in-memory cache.
  void clearCache() {
    _cache.clear();
    _visitorId = null;
    _visitorIdFetchStarted = false;
  }
}

// ---------------------------------------------------------------------------
// Internal enum — shelf content type
// ---------------------------------------------------------------------------

enum _ShelfType { song, album, artist, playlist }

// ---------------------------------------------------------------------------
// Album data holder — returned by getAlbumTracks
// ---------------------------------------------------------------------------

class AlbumTracksData {
  final String title;
  final String artist;
  final String coverUrl;
  final String year;
  final List<YtSong> tracks;

  const AlbumTracksData({
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.year,
    required this.tracks,
  });
}

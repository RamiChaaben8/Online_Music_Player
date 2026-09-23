// ============================================================
// services/lrclib_service.dart
// ============================================================

import 'dart:convert';
import 'dart:io';

import '../models/song.dart';
import '../services/youtube_service.dart' show LyricLine;

const String _kBase = 'https://lrclib.net/api';

// ── Strip common YouTube title noise ─────────────────────────────────────────

String _cleanYouTubeTitle(String title) {
  return title
      .replaceAllMapped(
        RegExp(
          r'\(.*?(official|video|audio|lyric|hd|hq|mv|4k|visualizer).*?\)',
          caseSensitive: false,
        ),
        (_) => '',
      )
      .replaceAllMapped(
        RegExp(
          r'\[.*?(official|video|audio|lyric|hd|hq|mv|4k|visualizer).*?\]',
          caseSensitive: false,
        ),
        (_) => '',
      )
      .replaceAllMapped(
        RegExp(
          r'[-|\u2014\u2013]\s*(official|lyrics?|audio|video|hd|mv).*',
          caseSensitive: false,
        ),
        (_) => '',
      )
      .replaceAll(
        RegExp(
          r'\b(MV|Music Video|Official Video|Official Audio)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

// ── Strip YouTube channel name noise (e.g. "Artist - Topic", "ArtistVEVO") ──

String _cleanArtistName(String name) {
  return name
      .replaceAll(RegExp(r'\s*-\s*Topic\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*VEVO\s*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*Official\s*$', caseSensitive: false), '')
      .trim();
}

// ── LRC parser ────────────────────────────────────────────────────────────────

List<LyricLine> _parseLrc(String lrc) {
  if (lrc.isEmpty) return [];

  final timestampRe = RegExp(r'\[(\d{1,3}):(\d{2})\.(\d{2,3})\]');
  final results = <LyricLine>[];

  for (final rawLine in lrc.split('\n')) {
    final matches = timestampRe.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;

    final text = rawLine.replaceAll(timestampRe, '').trim();
    if (text.isEmpty) continue;

    for (final m in matches) {
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      final fracStr = m.group(3)!;
      final frac = fracStr.length == 3
          ? int.parse(fracStr) / 1000.0
          : int.parse(fracStr) / 100.0;

      final totalMs = ((minutes * 60 + seconds + frac) * 1000).round();

      results.add(LyricLine(
        text: text,
        start: Duration(milliseconds: totalMs),
        end: Duration(milliseconds: totalMs + 4000),
        words: const [],
      ));
    }
  }

  results.sort((a, b) => a.start.compareTo(b.start));
  return results;
}

// ── Plain lyrics fallback ─────────────────────────────────────────────────────

List<LyricLine> _parsePlain(String plain) {
  return plain
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => LyricLine(
            text: l,
            start: Duration.zero,
            end: Duration.zero,
          ))
      .toList();
}

// ── HTTP GET helper ───────────────────────────────────────────────────────────

Future<Map<String, dynamic>?> _get(String url) async {
  HttpClient? client;
  try {
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Utify/1.0');
    request.headers.set('Accept', 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;
    return jsonDecode(body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  } finally {
    client?.close();
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

class LrclibService {
  /// Fetch synced/plain lyrics for a song.
  ///
  /// Attempts (in order):
  ///   1. /get with title + cleaned artist + duration
  ///   2. /get with title + cleaned artist (no duration — mismatch is common)
  ///   3. /search fallback with "title artist" query
  Future<List<LyricLine>> fetchForSong(Song song) async {
    final cleanTitle = _cleanYouTubeTitle(song.title);
    final artist     = _cleanArtistName(song.channelName);

    // ── Attempt 1: title + artist + duration ─────────────────────────────
    final params = <String, String>{
      'track_name':  cleanTitle,
      'artist_name': artist,
    };
    if (song.duration.inSeconds > 0) {
      params['duration'] = song.duration.inSeconds.toString();
    }

    final data = await _get('$_kBase/get?${_buildQuery(params)}');
    if (data != null) {
      final result = _extractFromMap(data);
      if (result.isNotEmpty) return result;
    }

    // ── Attempt 2: title + artist WITHOUT duration ────────────────────────
    // LRCLIB uses duration for strict matching; omitting it is more lenient.
    if (song.duration.inSeconds > 0) {
      final paramsNoDur = <String, String>{
        'track_name':  cleanTitle,
        'artist_name': artist,
      };
      final data2 = await _get('$_kBase/get?${_buildQuery(paramsNoDur)}');
      if (data2 != null) {
        final result = _extractFromMap(data2);
        if (result.isNotEmpty) return result;
      }
    }

    // ── Attempt 3: /search fallback ───────────────────────────────────────
    return _searchFallback(cleanTitle, artist);
  }

  List<LyricLine> _extractFromMap(Map<String, dynamic> data) {
    final syncedLrc   = data['syncedLyrics'] as String?;
    final plainLyrics = data['plainLyrics']  as String?;

    if (syncedLrc != null && syncedLrc.isNotEmpty) {
      final parsed = _parseLrc(syncedLrc);
      if (parsed.isNotEmpty) return parsed;
    }

    if (plainLyrics != null && plainLyrics.isNotEmpty) {
      return _parsePlain(plainLyrics);
    }

    return [];
  }

  static bool hasSyncedLyrics(List<LyricLine> lines) {
    if (lines.isEmpty) return false;
    return lines.any((l) => l.start != Duration.zero);
  }

  String _buildQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<List<LyricLine>> _searchFallback(String title, String artist) async {
    final query = '$title $artist';
    final url   = '$_kBase/search?q=${Uri.encodeComponent(query)}';

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Utify/1.0');
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return [];

      final list = jsonDecode(body);
      if (list is! List || list.isEmpty) return [];

      // Prefer synced lyrics first
      for (final item in list) {
        final map    = item as Map<String, dynamic>;
        final synced = map['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          final parsed = _parseLrc(synced);
          if (parsed.isNotEmpty) return parsed;
        }
      }
      // Fallback to plain lyrics
      for (final item in list) {
        final map   = item as Map<String, dynamic>;
        final plain = map['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) {
          return _parsePlain(plain);
        }
      }
    } catch (_) {
      return [];
    } finally {
      client?.close();
    }
    return [];
  }
}

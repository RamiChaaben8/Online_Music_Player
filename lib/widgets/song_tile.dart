// ============================================================
// widgets/song_tile.dart
//
// Reusable list tile for a Song.
// - Currently playing: green title + equaliser overlay
// - Downloaded: green ✓ badge on the thumbnail corner
// - Downloading: mini circular progress indicator on thumbnail corner
//
// Right-click anywhere on the tile to open the context menu.
// A ··· button is always shown as the trailing widget.
// Pass [currentPlaylist] to enable "Remove from this playlist".
// Pass [trailing] to override the ··· button with a custom widget.
// Pass [noTrailing] to suppress the trailing area entirely.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/download_provider.dart';
import '../providers/youtube_provider.dart';
import 'song_context_menu.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isSelected;

  /// The playlist this tile lives in, if any.
  final Playlist? currentPlaylist;

  /// Pass a custom trailing widget to override the default ··· button.
  final Widget? trailing;

  /// Pass true to suppress the trailing widget entirely.
  final bool noTrailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.isSelected = false,
    this.currentPlaylist,
    this.trailing,
    this.noTrailing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the stream while this song is visible so tapping it does not
    // need to wait for YouTube's manifest request.
    ref.read(youtubeServiceProvider).prefetchUrl(song.id);
    final dlState = ref.watch(downloadProvider);
    final isDownloaded = dlState.isDownloaded(song.id);
    final isDownloading = dlState.isDownloading(song.id);
    final progress = dlState.progressFor(song.id);

    final titleColor = isSelected
        ? const Color(0xFF1DB954)
        : isPlaying
            ? const Color(0xFF1DB954)
            : Colors.white;

    Widget? trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing;
    } else if (!noTrailing) {
      trailingWidget = SongMenuButton(
        song: song,
        currentPlaylist: currentPlaylist,
      );
    }

    return SongContextMenu(
      song: song,
      currentPlaylist: currentPlaylist,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _thumbnail(),
            ),
            // Playing overlay
            if (isPlaying)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.graphic_eq,
                      color: Color(0xFF1DB954), size: 22),
                ),
              ),
            // Downloaded tick badge (bottom-right corner)
            if (isDownloaded && !isPlaying)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0A0A0A), width: 1.5),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 11),
                ),
              ),
            // Downloading spinner badge (bottom-right corner)
            if (isDownloading && !isDownloaded)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1DB954), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      value: progress > 0 ? progress : null,
                      color: const Color(0xFF1DB954),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${song.channelName} • ${_formatDuration(song.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
        ),
        trailing: trailingWidget,
      ),
    );
  }

  Widget _thumbnail() {
    if (song.isLocal || song.thumbnailUrl.isEmpty) {
      return SizedBox(
        width: 52,
        height: 52,
        child: Container(
          color: const Color(0xFF1A2A1A),
          child: const Center(
            child: Icon(Icons.audio_file, color: Color(0xFF1DB954), size: 32),
          ),
        ),
      );
    }
    return SizedBox(
      width: 52,
      height: 52,
      child: CachedNetworkImage(
        imageUrl: song.thumbnailUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Container(
        color: const Color(0xFF282828),
        child: const Center(
          child: Icon(Icons.music_note, color: Color(0xFF555555), size: 28),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

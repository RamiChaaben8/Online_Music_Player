// ============================================================
// widgets/song_tile.dart
//
// Reusable list tile for a Song.
// - Local songs: white title, folder icon thumbnail placeholder
// - Online songs: blue title (Color 0xFF3D79F3)
// - Currently playing: green title + equaliser overlay
//
// Right-click anywhere on the tile to open the context menu.
// A ··· button is always shown as the trailing widget (replaces
// the old download-only button). Pass [currentPlaylist] to enable
// the "Remove from this playlist" menu option.
// Pass [trailing] to override the ··· button with a custom widget.
// Pass [noTrailing] to suppress the trailing area entirely.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import 'song_context_menu.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isSelected;

  /// The playlist this tile lives in, if any.
  /// When set, the "Remove from this playlist" option appears in the menu.
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
    final titleColor = isSelected
        ? const Color(0xFF1DB954)
        : song.isLocal
            ? Colors.white
            : const Color(0xFF3D79F3);

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
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _thumbnail(),
            ),
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
        subtitle: Row(
          children: [
            if (!song.isLocal) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D79F3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF3D79F3).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF3D79F3),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Local',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                '${song.channelName} • ${_formatDuration(song.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFB3B3B3), fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: trailingWidget,
      ),
    );
  }

  Widget _thumbnail() {
    if (song.isLocal || song.thumbnailUrl.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        color: const Color(0xFF1A2A1A),
        child:
            const Icon(Icons.audio_file, color: Color(0xFF1DB954), size: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: song.thumbnailUrl,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF282828),
      child:
          const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 24),
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

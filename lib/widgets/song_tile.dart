// ============================================================
// widgets/song_tile.dart
//
// Reusable list tile for a Song.
// Shows thumbnail, title, channel, duration.
// Highlights the currently playing song in green.
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/song.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isSelected;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.isSelected = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: song.thumbnailUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            ),
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
                child: Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 22),
              ),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1DB954) : Colors.white,
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
      trailing: trailing,
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 24),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

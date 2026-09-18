// ============================================================
// widgets/song_tile.dart
//
// Reusable list tile for a Song.
// - Local songs: white title, folder icon thumbnail placeholder
// - Online songs: blue title (Color 0xFF3D79F3)
// - Currently playing: green title + equaliser overlay
//
// When [trailing] is null and the song is an online song (not local),
// a download button is shown automatically that reflects the current
// download state: spinner → downloaded checkmark → download icon.
// Pass an explicit [trailing] widget to override this behaviour
// (e.g. a "remove from playlist" button).
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../providers/download_provider.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool isSelected;

  /// Pass a custom trailing widget to override the default download button.
  /// Pass [noTrailing] = true to suppress the download button entirely.
  final Widget? trailing;
  final bool noTrailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.isSelected = false,
    this.trailing,
    this.noTrailing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Colour logic:
    //  - Currently selected/playing → green (takes priority)
    //  - Online (isLocal=false)     → blue
    //  - Local                      → white
    final titleColor = isSelected
        ? const Color(0xFF1DB954)
        : song.isLocal
            ? Colors.white
            : const Color(0xFF3D79F3);

    // Determine trailing widget:
    //   1. Explicit trailing → use it
    //   2. noTrailing=true   → null
    //   3. Online song       → built-in download button
    //   4. Local song        → null
    Widget? trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing;
    } else if (!noTrailing && !song.isLocal) {
      trailingWidget = _DownloadButton(song: song);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          color: titleColor,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Row(
        children: [
          // Source badge
          if (!song.isLocal) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF3D79F3).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF3D79F3).withOpacity(0.4)),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.4)),
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
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: trailingWidget,
    );
  }

  Widget _thumbnail() {
    if (song.isLocal || song.thumbnailUrl.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        color: const Color(0xFF1A2A1A),
        child: const Icon(Icons.audio_file, color: Color(0xFF1DB954), size: 28),
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
      child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 24),
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

// ─── Built-in download button ─────────────────────────────────────────────

class _DownloadButton extends ConsumerWidget {
  final Song song;
  const _DownloadButton({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlState = ref.watch(downloadProvider);
    final isDownloading = dlState.isDownloading(song.id);
    final isDownloaded = dlState.isDownloaded(song.id);
    final progress = dlState.progressFor(song.id);

    if (isDownloading) {
      // Circular progress with % label
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2,
                color: const Color(0xFF1DB954),
                backgroundColor: Colors.white12,
              ),
            ),
            Text(
              progress > 0 ? '${(progress * 100).round()}%' : '…',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return const Padding(
        padding: EdgeInsets.all(11),
        child: Icon(Icons.download_done, color: Color(0xFF1DB954), size: 22),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_outlined,
          color: Color(0xFFB3B3B3), size: 22),
      onPressed: () {
        ref.read(downloadProvider.notifier).downloadSong(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading "${song.title}"…'),
            backgroundColor: const Color(0xFF1DB954),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      tooltip: 'Download',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

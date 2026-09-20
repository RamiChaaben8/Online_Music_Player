// ============================================================
// desktop/playlist/desktop_playlist_view.dart
//
// Full-center playlist view for the desktop shell.
// Shows playlist header (art, name, song count), a Play All
// button, and a scrollable list of songs. Each song can be
// played individually; right-click or ··· opens the context menu.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_context_menu.dart';
import '../theme/desktop_theme.dart';

class DesktopPlaylistView extends ConsumerWidget {
  final Playlist playlist;

  const DesktopPlaylistView({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always read the live version from the provider so edits reflect instantly
    final library = ref.watch(libraryProvider);
    final live = library.playlists.firstWhere(
      (p) => p.key == playlist.key,
      orElse: () => playlist,
    );
    final songs = live.songs;

    return Container(
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _PlaylistHeader(playlist: live, songs: songs),
          ),

          // ── Song count row ────────────────────────────────────────────
          if (songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Text(
                      '${songs.length} song${songs.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    // Column headers
                    const SizedBox(
                      width: 56,
                      child: Text(
                        'Duration',
                        style: TextStyle(color: kTextSecondary, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: Divider(color: kBorderColor, height: 1, thickness: 0.5,
                indent: 24, endIndent: 24),
          ),

          // ── Song list ─────────────────────────────────────────────────
          if (songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music, color: kTextSecondary, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'No songs yet.\nAdd songs using the ··· menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _SongRow(
                  song: songs[i],
                  index: i,
                  playlist: live,
                  allSongs: songs,
                ),
                childCount: songs.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _PlaylistHeader extends ConsumerWidget {
  final Playlist playlist;
  final List<Song> songs;

  const _PlaylistHeader({required this.playlist, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb =
        songs.isNotEmpty ? songs.first.thumbnailUrl : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Art
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.isEmpty
                ? Container(
                    width: 160,
                    height: 160,
                    color: const Color(0xFF2A1A4A),
                    child: const Icon(Icons.queue_music,
                        color: Colors.white38, size: 60),
                  )
                : CachedNetworkImage(
                    imageUrl: thumb,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 160,
                        height: 160,
                        color: const Color(0xFF2A1A4A)),
                    errorWidget: (_, __, ___) => Container(
                      width: 160,
                      height: 160,
                      color: const Color(0xFF2A1A4A),
                      child: const Icon(Icons.queue_music,
                          color: Colors.white38, size: 60),
                    ),
                  ),
          ),

          const SizedBox(width: 24),

          // Info + Play All
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PLAYLIST',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${songs.length} song${songs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Buttons row
                Row(
                  children: [
                    // Play All
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: songs.isEmpty
                          ? null
                          : () => ref
                              .read(playerProvider.notifier)
                              .playSong(songs.first, queue: songs),
                      icon: const Icon(Icons.play_arrow, size: 22),
                      label: const Text(
                        'Play All',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Shuffle
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextPrimary,
                        side: const BorderSide(color: kBorderColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: songs.isEmpty
                          ? null
                          : () {
                              ref
                                  .read(playerProvider.notifier)
                                  .toggleShuffle();
                              ref
                                  .read(playerProvider.notifier)
                                  .playSong(songs.first, queue: songs);
                            },
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Shuffle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Song row ─────────────────────────────────────────────────────────────────

class _SongRow extends ConsumerStatefulWidget {
  final Song song;
  final int index;
  final Playlist playlist;
  final List<Song> allSongs;

  const _SongRow({
    required this.song,
    required this.index,
    required this.playlist,
    required this.allSongs,
  });

  @override
  ConsumerState<_SongRow> createState() => _SongRowState();
}

class _SongRowState extends ConsumerState<_SongRow> {
  bool _hovered = false;

  String _fmt(Duration d) {
    if (d == Duration.zero) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final isPlaying = ps.currentSong?.id == widget.song.id;

    return SongContextMenu(
      song: widget.song,
      currentPlaylist: widget.playlist,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered
              ? const Color(0xFF2A2A2A)
              : isPlaying
                  ? const Color(0xFF1A2A1A)
                  : Colors.transparent,
          child: InkWell(
            onTap: () => ref
                .read(playerProvider.notifier)
                .playSong(widget.song, queue: widget.allSongs),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  // Index / equaliser
                  SizedBox(
                    width: 28,
                    child: isPlaying
                        ? const Icon(Icons.graphic_eq,
                            color: kAccent, size: 18)
                        : Text(
                            '${widget.index + 1}',
                            style: const TextStyle(
                                color: kTextSecondary, fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: widget.song.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.song.thumbnailUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 44,
                                height: 44,
                                color: kCardColor),
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: kCardColor,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white54, size: 18),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: kCardColor,
                            child: const Icon(Icons.music_note,
                                color: Colors.white54, size: 18),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Title + artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPlaying ? kAccent : kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.song.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Duration
                  SizedBox(
                    width: 56,
                    child: Text(
                      _fmt(widget.song.duration),
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),

                  // ··· button (visible on hover)
                  AnimatedOpacity(
                    opacity: _hovered || isPlaying ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: SongMenuButton(
                      song: widget.song,
                      currentPlaylist: widget.playlist,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
import '../../services/firestore_service.dart';
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
      (p) {
        // Prefer Firestore ID match, fall back to Hive key
        final fsId = playlist.firestoreId;
        if (fsId != null && p.firestoreId == fsId) return true;
        final hiveKey = playlist.key;
        if (hiveKey != null && p.key == hiveKey) return true;
        return false;
      },
      orElse: () => playlist,
    );
    final songs = live.songs;

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.main,
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
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Text(
                      '${songs.length} song${songs.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: context.appTheme.subtext, fontSize: 13),
                    ),
                    const Spacer(),
                    // Column headers
                    SizedBox(
                      width: 56,
                      child: Text(
                        'Duration',
                        style: TextStyle(
                            color: context.appTheme.subtext, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Divider(
                color: context.appTheme.shadow,
                height: 1,
                thickness: 0.5,
                indent: 24,
                endIndent: 24),
          ),

          // ── Song list ─────────────────────────────────────────────────
          if (songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music,
                        color: context.appTheme.subtext, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'No songs yet.\nAdd songs using the ··· menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.appTheme.subtext, fontSize: 14),
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
    final thumb = songs.isNotEmpty ? songs.first.thumbnailUrl : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
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
                    color: context.appTheme.misc.withValues(alpha: 0.35),
                    child: Icon(Icons.queue_music,
                        color: context.appTheme.subtext.withValues(alpha: 0.38),
                        size: 60),
                  )
                : CachedNetworkImage(
                    imageUrl: thumb,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 160,
                        height: 160,
                        color: context.appTheme.misc.withValues(alpha: 0.35)),
                    errorWidget: (_, __, ___) => Container(
                      width: 160,
                      height: 160,
                      color: context.appTheme.misc.withValues(alpha: 0.35),
                      child: Icon(Icons.queue_music,
                          color:
                              context.appTheme.subtext.withValues(alpha: 0.38),
                          size: 60),
                    ),
                  ),
          ),

          SizedBox(width: 24),

          // Info + Play All
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAYLIST',
                  style: TextStyle(
                    color: context.appTheme.subtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTheme.text,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${songs.length} song${songs.length == 1 ? '' : 's'}',
                  style:
                      TextStyle(color: context.appTheme.subtext, fontSize: 13),
                ),
                SizedBox(height: 20),

                // Buttons row
                Row(
                  children: [
                    // Play All
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appTheme.button,
                        foregroundColor: context.appTheme.text,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: songs.isEmpty
                          ? null
                          : () => ref
                              .read(playerProvider.notifier)
                              .playSong(songs.first, queue: songs),
                      icon: Icon(Icons.play_arrow, size: 22),
                      label: Text(
                        'Play All',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Shuffle
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.appTheme.text,
                        side: BorderSide(color: context.appTheme.shadow),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: songs.isEmpty
                          ? null
                          : () {
                              ref.read(playerProvider.notifier).toggleShuffle();
                              ref
                                  .read(playerProvider.notifier)
                                  .playSong(songs.first, queue: songs);
                            },
                      icon: Icon(Icons.shuffle, size: 18),
                      label: Text('Shuffle'),
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
              ? context.appTheme.highlight
              : isPlaying
                  ? context.appTheme.selectedRow
                  : context.appTheme.main.withValues(alpha: 0),
          child: InkWell(
            onTap: () => ref
                .read(playerProvider.notifier)
                .playSong(widget.song, queue: widget.allSongs),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  // Index / equaliser
                  SizedBox(
                    width: 28,
                    child: isPlaying
                        ? Icon(Icons.graphic_eq,
                            color: context.appTheme.button, size: 18)
                        : Text(
                            '${widget.index + 1}',
                            style: TextStyle(
                                color: context.appTheme.subtext, fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                  ),
                  SizedBox(width: 16),

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
                                color: context.appTheme.card),
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: context.appTheme.card,
                              child: Icon(Icons.music_note,
                                  color: context.appTheme.subtext
                                      .withValues(alpha: 0.54),
                                  size: 18),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: context.appTheme.card,
                            child: Icon(Icons.music_note,
                                color: context.appTheme.subtext
                                    .withValues(alpha: 0.54),
                                size: 18),
                          ),
                  ),
                  SizedBox(width: 14),

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
                            color: isPlaying
                                ? context.appTheme.button
                                : context.appTheme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.song.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.appTheme.subtext, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Duration
                  SizedBox(
                    width: 56,
                    child: Text(
                      _fmt(widget.song.duration),
                      style: TextStyle(
                          color: context.appTheme.subtext, fontSize: 13),
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

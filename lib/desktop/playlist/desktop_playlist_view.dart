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
import '../../providers/download_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/song_context_menu.dart';
import '../theme/desktop_theme.dart';
import '../widgets/invite_collaborator_dialog.dart';

class DesktopPlaylistView extends ConsumerStatefulWidget {
  final Playlist playlist;

  const DesktopPlaylistView({super.key, required this.playlist});

  @override
  ConsumerState<DesktopPlaylistView> createState() =>
      _DesktopPlaylistViewState();
}

class _DesktopPlaylistViewState extends ConsumerState<DesktopPlaylistView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Always read the live version from the provider so edits reflect instantly
    final library = ref.watch(libraryProvider);
    final live = library.playlists.firstWhere(
      (p) {
        // Prefer Firestore ID match, fall back to Hive key
        final fsId = widget.playlist.firestoreId;
        if (fsId != null && p.firestoreId == fsId) return true;
        if (widget.playlist.sharedId != null &&
            p.sharedId == widget.playlist.sharedId) return true;
        final hiveKey = widget.playlist.key;
        if (hiveKey != null && p.key == hiveKey) return true;
        return false;
      },
      orElse: () => widget.playlist,
    );
    final songs = live.songs
        .where((song) =>
            _query.trim().isEmpty ||
            song.title.toLowerCase().contains(_query.toLowerCase()) ||
            song.channelName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.main,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _PlaylistHeader(
              playlist: live,
              songs: songs,
              onSearchChanged: (value) => setState(() => _query = value),
            ),
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
  final ValueChanged<String> onSearchChanged;

  const _PlaylistHeader({
    required this.playlist,
    required this.songs,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = songs.isNotEmpty ? songs.first.thumbnailUrl : '';
    final accountName =
        ref.watch(authServiceProvider).currentUser?.displayName?.trim();
    final creatorName = playlist.ownerName?.trim().isNotEmpty == true
        ? playlist.ownerName!.trim()
        : accountName?.isNotEmpty == true
            ? accountName!
            : (ref.watch(authServiceProvider).currentUser?.email ?? 'You');
    final totalDuration = songs.fold<Duration>(
        Duration.zero, (total, song) => total + song.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 28, 38, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Art
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumb.isEmpty
                    ? Container(
                        width: 232,
                        height: 232,
                        color: context.appTheme.misc.withValues(alpha: 0.35),
                        child: Icon(Icons.queue_music,
                            color: context.appTheme.subtext
                                .withValues(alpha: 0.38),
                            size: 72),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumb,
                        width: 232,
                        height: 232,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 232,
                            height: 232,
                            color:
                                context.appTheme.misc.withValues(alpha: 0.35)),
                        errorWidget: (_, __, ___) => Container(
                          width: 232,
                          height: 232,
                          color: context.appTheme.misc.withValues(alpha: 0.35),
                          child: Icon(Icons.queue_music,
                              color: context.appTheme.subtext
                                  .withValues(alpha: 0.38),
                              size: 72),
                        ),
                      ),
              ),

              const SizedBox(width: 28),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: context.appTheme.button, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${playlist.visibility[0].toUpperCase()}${playlist.visibility.substring(1)} Playlist',
                        style: TextStyle(
                          color: context.appTheme.button,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appTheme.button,
                        fontSize: 56,
                        height: 0.98,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Invite to playlist',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => _invite(context, ref),
                          icon: Icon(Icons.add_circle_outline,
                              size: 18, color: context.appTheme.subtext),
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: context.appTheme.card,
                          child: Icon(Icons.person,
                              size: 15, color: context.appTheme.subtext),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          creatorName,
                          style: TextStyle(
                              color: context.appTheme.subtext, fontSize: 13),
                        ),
                        Text(
                          '  •  ${songs.length} songs  •  ${_formatDuration(totalDuration)}',
                          style: TextStyle(
                              color: context.appTheme.subtext, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appTheme.button,
                  foregroundColor: context.appTheme.text,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: songs.isEmpty
                    ? null
                    : () => ref
                        .read(playerProvider.notifier)
                        .playSong(songs.first, queue: songs),
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text('Play All',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appTheme.text,
                  side: BorderSide(color: context.appTheme.shadow),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Shuffle'),
              ),
              const SizedBox(width: 8),
              _DownloadButton(songs: songs),
              IconButton(
                tooltip: 'Invite collaborator',
                onPressed: () => _invite(context, ref),
                icon: const Icon(Icons.person_add_alt_1),
              ),
              IconButton(
                tooltip: 'Name & details',
                onPressed: () => _rename(context, ref),
                icon: const Icon(Icons.more_horiz),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 360,
                child: TextField(
                  onChanged: onSearchChanged,
                  style: TextStyle(color: context.appTheme.text),
                  decoration: InputDecoration(
                    hintText: 'Search in this playlist',
                    hintStyle: TextStyle(color: context.appTheme.subtext),
                    prefixIcon:
                        Icon(Icons.search, color: context.appTheme.subtext),
                    filled: true,
                    fillColor: context.appTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    }
    return '${duration.inMinutes}min';
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name & details'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref
          .read(libraryProvider.notifier)
          .renamePlaylistObj(playlist, name);
    }
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final selected = await showCollaboratorInviteDialog(context, ref, playlist);
    if (selected != null) {
      try {
        await ref
            .read(libraryProvider.notifier)
            .inviteCollaborator(playlist, selected);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist invitation sent.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }
}

// ─── Download button (playlist-level) ────────────────────────────────────────

class _DownloadButton extends ConsumerWidget {
  final List<Song> songs;
  const _DownloadButton({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(downloadProvider);
    if (songs.isEmpty) {
      return IconButton(
        tooltip: 'Download playlist',
        onPressed: null,
        icon: const Icon(Icons.download_outlined),
      );
    }

    final onlineSongs = songs.where((s) => !s.isLocal).toList();
    final totalOnline = onlineSongs.length;
    final downloadedCount =
        onlineSongs.where((s) => ds.isDownloaded(s.id)).length;
    final downloadingCount =
        onlineSongs.where((s) => ds.isDownloading(s.id)).length;
    final allDone = totalOnline > 0 && downloadedCount == totalOnline;
    final anyDownloading = downloadingCount > 0;

    // Aggregate progress across all actively downloading songs
    double avgProgress = 0;
    if (anyDownloading) {
      final total = onlineSongs
          .where((s) => ds.isDownloading(s.id))
          .fold<double>(0, (sum, s) => sum + ds.progressFor(s.id));
      avgProgress = total / downloadingCount;
    }

    return Tooltip(
      message: allDone
          ? 'Playlist downloaded'
          : anyDownloading
              ? 'Downloading… ${downloadedCount + downloadingCount}/$totalOnline'
              : 'Download playlist',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (anyDownloading)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: avgProgress,
                  strokeWidth: 2.5,
                  color: context.appTheme.button,
                  backgroundColor:
                      context.appTheme.subtext.withValues(alpha: 0.2),
                ),
              ),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: allDone || anyDownloading
                  ? null
                  : () {
                      for (final song in onlineSongs) {
                        if (!ds.isDownloaded(song.id)) {
                          ref
                              .read(downloadProvider.notifier)
                              .downloadSong(song);
                        }
                      }
                    },
              icon: Icon(
                allDone
                    ? Icons.download_done
                    : anyDownloading
                        ? Icons.downloading
                        : Icons.download_outlined,
                color: allDone
                    ? context.appTheme.button
                    : anyDownloading
                        ? context.appTheme.button.withValues(alpha: 0.7)
                        : context.appTheme.subtext,
                size: 22,
              ),
            ),
          ],
        ),
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

                  // Download indicator (progress circle or tick)
                  if (!widget.song.isLocal)
                    _SongDownloadIndicator(song: widget.song),

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


// ─── Per-song download indicator ─────────────────────────────────────────────

class _SongDownloadIndicator extends ConsumerWidget {
  final Song song;
  const _SongDownloadIndicator({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(downloadProvider);
    final downloaded = ds.isDownloaded(song.id);
    final downloading = ds.isDownloading(song.id);
    final progress = ds.progressFor(song.id);

    if (!downloaded && !downloading) return const SizedBox(width: 32);

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (downloading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2,
                color: context.appTheme.button,
                backgroundColor:
                    context.appTheme.subtext.withValues(alpha: 0.2),
              ),
            )
          else
            Icon(
              Icons.check_circle,
              size: 18,
              color: context.appTheme.button,
            ),
        ],
      ),
    );
  }
}

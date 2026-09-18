// ============================================================
// screens/playlist_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../providers/library_provider.dart';
import '../screens/library_screen.dart';
import '../screens/now_playing_screen.dart';
import '../widgets/song_tile.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Song> songs;
  final int? playlistKey;
  final IconData? icon;
  /// If set, locks the filter to this value (e.g. Local Music entry).
  final SongFilter? forcedFilter;

  const PlaylistScreen({
    super.key,
    required this.title,
    required this.songs,
    this.playlistKey,
    this.icon,
    this.forcedFilter,
  });

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  late SongFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.forcedFilter ?? SongFilter.all;
  }

  List<Song> get _filtered => applyFilter(widget.songs, _filter);

  void _playSong(Song song, List<Song> queue) {
    ref.read(playerProvider.notifier).playSong(song, queue: queue);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final filtered = _filtered;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _PlaylistHeader(
                title: widget.title,
                songs: widget.songs,
                icon: widget.icon,
              ),
            ),
          ),

          // ── Filter chips (hidden when filter is forced) ────────────────
          if (widget.forcedFilter == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _filter == SongFilter.all,
                      onTap: () => setState(() => _filter = SongFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Local',
                      icon: Icons.folder_outlined,
                      selected: _filter == SongFilter.local,
                      onTap: () => setState(() => _filter = SongFilter.local),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Online',
                      icon: Icons.cloud_outlined,
                      selected: _filter == SongFilter.online,
                      onTap: () => setState(() => _filter = SongFilter.online),
                    ),
                  ],
                ),
              ),
            ),

          // ── Play all + Download bar ────────────────────────────────────
          if (filtered.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Consumer(
                  builder: (context, ref, _) {
                    final dlState = ref.watch(downloadProvider);
                    final onlineSongs =
                        filtered.where((s) => !s.isLocal).toList();
                    final hasOnline = onlineSongs.isNotEmpty;

                    // Count how many are done / in-progress
                    final doneCount = hasOnline
                        ? onlineSongs
                            .where((s) => dlState.isDownloaded(s.id))
                            .length
                        : 0;
                    final anyDownloading = hasOnline &&
                        onlineSongs.any((s) => dlState.isDownloading(s.id));
                    final allDownloaded =
                        hasOnline && doneCount == onlineSongs.length;
                    final overallProgress =
                        hasOnline ? doneCount / onlineSongs.length : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            // ── Play all ──────────────────────────────
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _playSong(
                                    filtered.first, filtered),
                                icon: const Icon(Icons.play_arrow,
                                    color: Colors.black),
                                label: const Text('Play all',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DB954),
                                  minimumSize:
                                      const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(24)),
                                ),
                              ),
                            ),

                            // ── Download button (only for online songs) ──
                            if (hasOnline) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: anyDownloading || allDownloaded
                                    ? null
                                    : () {
                                        for (final s in onlineSongs) {
                                          ref
                                              .read(
                                                  downloadProvider.notifier)
                                              .downloadSong(s);
                                        }
                                      },
                                icon: anyDownloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Icon(
                                        allDownloaded
                                            ? Icons.download_done
                                            : Icons.download,
                                        color: allDownloaded
                                            ? const Color(0xFF1DB954)
                                            : Colors.white,
                                      ),
                                label: Text(
                                  allDownloaded
                                      ? 'Done'
                                      : anyDownloading
                                          ? '$doneCount / ${onlineSongs.length}'
                                          : 'Download',
                                  style: TextStyle(
                                      color: allDownloaded
                                          ? const Color(0xFF1DB954)
                                          : Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF282828),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(24)),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // ── Progress bar (visible while downloading) ──
                        if (hasOnline && anyDownloading) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: overallProgress,
                                    minHeight: 6,
                                    backgroundColor:
                                        const Color(0xFF2A2A2A),
                                    color: const Color(0xFF1DB954),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$doneCount / ${onlineSongs.length} songs',
                                style: const TextStyle(
                                  color: Color(0xFFB3B3B3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

          // ── Song list ─────────────────────────────────────────────────
          filtered.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text('No songs',
                        style: TextStyle(color: Color(0xFFB3B3B3))),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final song = filtered[i];
                      final isCurrent =
                          playerState.currentSong?.id == song.id;
                      return SongTile(
                        song: song,
                        isPlaying: isCurrent && playerState.isPlaying,
                        isSelected: isCurrent,
                        onTap: () => _playSong(song, filtered),
                        // Custom playlist: show remove button.
                        // For all other views, SongTile auto-shows
                        // the download button for online songs.
                        trailing: widget.playlistKey != null
                            ? IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Color(0xFFB3B3B3)),
                                onPressed: () => ref
                                    .read(libraryProvider.notifier)
                                    .removeSongFromPlaylist(
                                        widget.playlistKey!, song.id),
                              )
                            : null,
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1DB954).withOpacity(0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1DB954)
                : const Color(0xFF3A3A3A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? const Color(0xFF1DB954)
                      : const Color(0xFFB3B3B3)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF1DB954)
                    : const Color(0xFFB3B3B3),
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final IconData? icon;

  const _PlaylistHeader(
      {required this.title, required this.songs, this.icon});

  @override
  Widget build(BuildContext context) {
    // Find first song with a real thumbnail
    final coverSong = songs.firstWhere(
      (s) => s.thumbnailUrl.isNotEmpty,
      orElse: () => songs.isEmpty ? _emptySong() : songs.first,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            if (coverSong.thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  coverSong.thumbnailUrl,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _iconBox(),
                ),
              )
            else
              _iconBox(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            Text('${songs.length} songs',
                style: const TextStyle(
                    color: Color(0xFFB3B3B3), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon ?? Icons.queue_music,
            color: const Color(0xFF3A3A3A), size: 52),
      );

  Song _emptySong() => Song(
      id: '',
      title: '',
      channelName: '',
      thumbnailUrl: '',
      duration: Duration.zero);
}

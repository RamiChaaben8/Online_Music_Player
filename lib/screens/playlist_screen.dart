// ============================================================
// screens/playlist_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../providers/library_provider.dart';
import '../screens/library_screen.dart';
import '../screens/now_playing_screen.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Song> songs;

  /// Pass the full Playlist object for custom playlists (enables remove-song button).
  final Playlist? playlist;

  /// Legacy: accepted for backward-compat — prefer [playlist] instead.
  final int? playlistKey;
  final IconData? icon;

  /// If set, locks the filter to this value (e.g. Local Music entry).
  final SongFilter? forcedFilter;

  const PlaylistScreen({
    super.key,
    required this.title,
    required this.songs,
    this.playlist,
    this.playlistKey,
    this.icon,
    this.forcedFilter,
  });

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  late SongFilter _filter;
  late List<Song> _songs;
  bool _editingOrder = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.forcedFilter ?? SongFilter.all;
    _songs = List<Song>.from(widget.songs);
  }

  List<Song> get _filtered => applyFilter(_songs, _filter);

  void _playSong(Song song, List<Song> queue) {
    final currentId = ref.read(playerProvider).currentSong?.id;
    if (currentId == song.id) {
      // Song is already playing — just open the player without restarting
      _openPlayer();
      return;
    }

    ref
        .read(playerProvider.notifier)
        .playSong(song, queue: queue, sourcePlaylist: widget.playlist);
    _openPlayer();
  }

  void _playPlaylist({required bool shuffle}) {
    if (_songs.isEmpty) return;
    final player = ref.read(playerProvider.notifier);
    final currentShuffle = ref.read(playerProvider).shuffle;
    if (currentShuffle != shuffle) player.toggleShuffle();
    player.playSong(
      _songs.first,
      queue: _songs,
      sourcePlaylist: widget.playlist,
    );
    _openPlayer();
  }

  void _downloadPlaylist() {
    final download = ref.read(downloadProvider.notifier);
    for (final song in _songs.where((song) => !song.isLocal)) {
      download.downloadSong(song);
    }
  }

  void _openPlayer() {
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

  Widget _buildPlaylistActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _ActionChip(
            icon: _editingOrder ? Icons.check : Icons.sort,
            label: _editingOrder ? 'Done' : 'Edit order',
            onTap: () => setState(() => _editingOrder = !_editingOrder),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.edit_outlined,
            label: 'Name & details',
            onTap: _showPlaylistDetails,
          ),
        ],
      ),
    );
  }

  void _showPlaylistDetails() {
    final playlist = widget.playlist;
    if (playlist == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF282828),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit name'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.white),
              title: const Text('Privacy'),
              subtitle: Text(playlist.visibility),
              onTap: () {
                Navigator.pop(sheetContext);
                _showVisibilityMenu(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete playlist',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteDialog(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Edit playlist name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(libraryProvider.notifier)
                  .renamePlaylistObj(playlist, name);
              Navigator.pop(dialogContext);
            },
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  void _showVisibilityMenu(Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in ['private', 'friends', 'public'])
            RadioListTile<String>(
              value: value,
              groupValue: playlist.visibility,
              title: Text(value[0].toUpperCase() + value.substring(1)),
              onChanged: (next) {
                if (next == null) return;
                ref
                    .read(libraryProvider.notifier)
                    .setPlaylistVisibility(playlist, next);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Playlist playlist) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete playlist?',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).deletePlaylistObj(playlist);
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final downloadState = ref.watch(downloadProvider);
    final filtered = _filtered;
    final onlineSongs = _songs.where((song) => !song.isLocal).toList();
    final downloadedCount =
        onlineSongs.where((song) => downloadState.isDownloaded(song.id)).length;
    final allDownloaded =
        onlineSongs.isNotEmpty && downloadedCount == onlineSongs.length;
    final isDownloading =
        onlineSongs.any((song) => downloadState.isDownloading(song.id));

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: true,
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PlaylistHeader(
                title: widget.title,
                songs: _songs,
                icon: widget.icon,
                creatorName:
                    ref.watch(authServiceProvider).currentUser?.displayName ??
                        'You',
                shuffle: playerState.shuffle,
                onPlay: () => _playPlaylist(shuffle: false),
                onShuffle: () => _playPlaylist(shuffle: true),
                allDownloaded: allDownloaded,
                isDownloading: isDownloading,
                onDownload: _downloadPlaylist,
              ),
            ),

            if (widget.playlist != null)
              SliverToBoxAdapter(child: _buildPlaylistActions()),

            // ── Song list ─────────────────────────────────────────────────
            _editingOrder && widget.playlist != null
                ? SliverReorderableList(
                    itemCount: _songs.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex--;
                        final song = _songs.removeAt(oldIndex);
                        _songs.insert(newIndex, song);
                      });
                    },
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(song.id),
                        index: index,
                        child: SongTile(
                          song: song,
                          onTap: () => _playSong(song, _songs),
                          currentPlaylist: widget.playlist,
                          trailing: const Icon(Icons.drag_handle,
                              color: Color(0xFFB3B3B3)),
                        ),
                      );
                    },
                  )
                : filtered.isEmpty
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
                              currentPlaylist: widget.playlist,
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      bottomNavigationBar: playerState.currentSong == null
          ? null
          : const SafeArea(
              top: false,
              child: MiniPlayer(),
            ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final IconData? icon;
  final String creatorName;
  final bool shuffle;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final bool allDownloaded;
  final bool isDownloading;
  final VoidCallback onDownload;

  const _PlaylistHeader({
    required this.title,
    required this.songs,
    required this.creatorName,
    required this.shuffle,
    required this.onPlay,
    required this.onShuffle,
    required this.allDownloaded,
    required this.isDownloading,
    required this.onDownload,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Find first song with a real thumbnail
    final coverSong = songs.firstWhere(
      (s) => s.thumbnailUrl.isNotEmpty,
      orElse: () => songs.isEmpty ? _emptySong() : songs.first,
    );

    final totalDuration = songs.fold<Duration>(
      Duration.zero,
      (total, song) => total + song.duration,
    );

    return Container(
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Center(
                child: coverSong.thumbnailUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: coverSong.thumbnailUrl,
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _iconBox(),
                        ),
                      )
                    : _iconBox(),
              ),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF535353),
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(creatorName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.public, color: Color(0xFFB3B3B3), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(totalDuration)} • ${songs.length} songs',
                    style:
                        const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isDownloading
                          ? Icons.downloading
                          : allDownloaded
                              ? Icons.download_done
                              : Icons.download_outlined,
                      color: allDownloaded
                          ? const Color(0xFF1DB954)
                          : const Color(0xFFB3B3B3),
                      size: 28,
                    ),
                    tooltip: allDownloaded
                        ? 'Playlist downloaded'
                        : 'Download playlist',
                    onPressed:
                        isDownloading || allDownloaded ? null : onDownload,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFFB3B3B3), size: 28),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.shuffle,
                        color: shuffle
                            ? const Color(0xFF1DB954)
                            : const Color(0xFF777777),
                        size: 30),
                    onPressed: onShuffle,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow,
                          color: Colors.black, size: 32),
                      onPressed: onPlay,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
  }
  return '${duration.inMinutes}min';
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(label),
      labelStyle:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      backgroundColor: const Color(0xFF282828),
      onPressed: onTap,
    );
  }
}

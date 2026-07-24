// ============================================================
// screens/search_screen.dart
//
// YouTube-style search:
//  1. User types a query in the search bar
//  2. Presses Enter / taps the search icon to fire the search
//  3. Results shown as large video cards (16:9 thumbnail, duration badge,
//     title, channel name, view count)
//  4. Tapping a card starts playback and opens Now Playing
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/song.dart';
import '../providers/youtube_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/error_banner.dart';
import '../screens/now_playing_screen.dart';
import '../providers/search_history_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Fires search — called on Enter key or search icon tap.
  void _doSearch([String? overrideQuery]) {
    final query = overrideQuery ?? _controller.text.trim();
    if (query.isEmpty) return;
    if (overrideQuery != null) {
      _controller.text = overrideQuery;
    }
    _focusNode.unfocus(); // dismiss keyboard
    ref.read(searchHistoryProvider.notifier).addQuery(query);
    ref.read(searchProvider.notifier).search(query);
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _doSearch(),
                      decoration: InputDecoration(
                        hintText: 'Search for a song, artist, video…',
                        hintStyle: const TextStyle(color: Color(0xFF6A6A6A)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFB3B3B3)),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Color(0xFFB3B3B3), size: 20),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF212121),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 1.5),
                        ),
                      ),
                      // Rebuild to show/hide clear button as user types
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search button
                  GestureDetector(
                    onTap: _doSearch,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search, color: Colors.black, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // ── Error banner ──────────────────────────────────────────────
            if (searchState.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ErrorBanner(message: searchState.error!),
              ),

            // ── Loading bar ───────────────────────────────────────────────
            if (searchState.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF1DB954),
                backgroundColor: Color(0xFF212121),
              ),

            // ── Results header ────────────────────────────────────────────
            if (searchState.results.isNotEmpty && !searchState.isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${searchState.results.length} results for',
                      style: const TextStyle(color: Color(0xFF6A6A6A), fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '"${searchState.query}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Video result cards ────────────────────────────────────────
            Expanded(
              child: searchState.results.isEmpty && !searchState.isLoading
                  ? _SearchHistoryOrEmpty(query: searchState.query, onSearch: _doSearch)
                  : ListView.builder(
                      itemCount: searchState.results.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (ctx, i) {
                        final song = searchState.results[i];
                        final isCurrent = playerState.currentSong?.id == song.id;
                        return _VideoCard(
                          song: song,
                          isCurrentlyPlaying: isCurrent && playerState.isPlaying,
                          isSelected: isCurrent,
                          onTap: () => _playSong(song, searchState.results),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSong(Song song, List<Song> queue) {
    ref.read(playerProvider.notifier).playSong(song, queue: queue);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ─── YouTube-style video card ─────────────────────────────────────────────────

class _VideoCard extends ConsumerWidget {
  final Song song;
  final bool isCurrentlyPlaying;
  final bool isSelected;
  final VoidCallback onTap;

  const _VideoCard({
    required this.song,
    required this.isCurrentlyPlaying,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A2A1A) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF1DB954).withAlpha(100), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 16:9 Thumbnail ─────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF212121),
                        child: const Center(
                          child: Icon(Icons.music_video, color: Color(0xFF3A3A3A), size: 40),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF212121),
                        child: const Center(
                          child: Icon(Icons.music_video, color: Color(0xFF3A3A3A), size: 40),
                        ),
                      ),
                    ),
                  ),
                ),

                // Duration badge (bottom-right corner)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(210),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(song.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                // "Now playing" overlay
                if (isCurrentlyPlaying)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        color: Colors.black.withAlpha(100),
                        child: const Center(
                          child: Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 48),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Info row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF1DB954) : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Channel name
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 13, color: Color(0xFF6A6A6A)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                song.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF9A9A9A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ⋮ Options menu
                  _VideoOptionsMenu(song: song),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Options menu (⋮ button) ──────────────────────────────────────────────────

class _VideoOptionsMenu extends ConsumerWidget {
  final Song song;
  const _VideoOptionsMenu({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF6A6A6A), size: 20),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.zero,
      onSelected: (action) async {
        switch (action) {
          case 'next':
            ref.read(playerProvider.notifier).playNext(song);
            _snack(context, '▶  Will play next');
            break;
          case 'queue':
            ref.read(playerProvider.notifier).addToQueue(song);
            _snack(context, '+ Added to queue');
            break;
          case 'like':
            try {
              await ref.read(libraryProvider.notifier).toggleLike(song);
              if (context.mounted) {
                final isLiked = ref.read(libraryProvider).isLiked(song.id);
                _snack(context, isLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs');
              }
            } catch (e) {
              if (context.mounted) {
                _snack(context, 'Failed to like song: $e');
              }
            }
            break;
          case 'playlist':
            _showAddToPlaylist(context, ref);
            break;
        }
      },
      itemBuilder: (_) {
        final isLiked = ref.read(libraryProvider).isLiked(song.id);
        return [
          _menuItem(Icons.skip_next_outlined, 'Play next', 'next'),
          _menuItem(Icons.queue_music_outlined, 'Add to queue', 'queue'),
          _menuItem(
            isLiked ? Icons.favorite : Icons.favorite_border,
            isLiked ? 'Unlike' : 'Like',
            'like',
            iconColor: isLiked ? const Color(0xFF1DB954) : null,
          ),
          _menuItem(Icons.playlist_add, 'Add to playlist', 'playlist'),
        ];
      },
    );
  }

  PopupMenuItem<String> _menuItem(IconData icon, String label, String value,
      {Color? iconColor}) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? const Color(0xFFB3B3B3), size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1DB954),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showAddToPlaylist(BuildContext context, WidgetRef ref) {
    final playlists = ref.read(libraryProvider).playlists;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add to playlist',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Color(0xFF282828), height: 20),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No playlists yet.\nCreate one in the Library tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB3B3B3)),
              ),
            )
          else
            ...playlists.map((pl) => ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.queue_music, color: Color(0xFF1DB954), size: 22),
                  ),
                  title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${pl.songs.length} songs',
                    style: const TextStyle(color: Color(0xFF6A6A6A), fontSize: 12),
                  ),
                  onTap: () {
                    ref.read(libraryProvider.notifier).addSongToPlaylist(pl.key as int, song);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Added to "${pl.name}"'),
                      backgroundColor: const Color(0xFF1DB954),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Empty / prompt state ─────────────────────────────────────────────────────

class _SearchHistoryOrEmpty extends ConsumerWidget {
  final String query;
  final Function(String) onSearch;

  const _SearchHistoryOrEmpty({required this.query, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isNotEmpty) {
      // Has query but no results
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: Color(0xFF3A3A3A)),
            const SizedBox(height: 16),
            Text(
              'No results for\n"$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => onSearch(query),
              icon: const Icon(Icons.refresh, color: Color(0xFF1DB954)),
              label: const Text('Try again', style: TextStyle(color: Color(0xFF1DB954))),
            ),
          ],
        ),
      );
    }

    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.youtube_searched_for,
                  size: 44, color: Color(0xFF1DB954)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Search YouTube',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Type a song name, artist, or video title\nthen tap search to find it',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6A6A6A), fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
                child: const Text('Clear', style: TextStyle(color: Color(0xFF1DB954))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (ctx, i) {
              return ListTile(
                leading: const Icon(Icons.history, color: Color(0xFFB3B3B3)),
                title: Text(history[i], style: const TextStyle(color: Colors.white)),
                onTap: () => onSearch(history[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

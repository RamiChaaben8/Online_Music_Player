// ============================================================
// desktop/desktop_search_view.dart
// Full-page search for desktop layout.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/youtube_provider.dart';
import '../widgets/song_context_menu.dart';
import 'theme/desktop_theme.dart';

class DesktopSearchView extends ConsumerStatefulWidget {
  const DesktopSearchView({super.key});

  @override
  ConsumerState<DesktopSearchView> createState() => _DesktopSearchViewState();
}

class _DesktopSearchViewState extends ConsumerState<DesktopSearchView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (query.trim().isEmpty) return;
    ref.read(searchProvider.notifier).search(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.main,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: _buildBody(searchState),
    );
  }

  Widget _buildBody(SearchState searchState) {
    if (searchState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.appTheme.button),
      );
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: context.appTheme.notificationError, size: 40),
            SizedBox(height: 12),
            Text(
              searchState.error!,
              style: TextStyle(color: context.appTheme.subtext),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty && searchState.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, color: context.appTheme.subtext, size: 56),
            SizedBox(height: 12),
            Text(
              'Search for songs, artists, or albums',
              style: TextStyle(color: context.appTheme.subtext, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Text(
          'No results for "${searchState.query}"',
          style: TextStyle(color: context.appTheme.subtext, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 8),
      itemCount: searchState.results.length,
      itemBuilder: (ctx, i) {
        final song = searchState.results[i];
        final durationStr = song.duration != Duration.zero
            ? '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}'
            : '';

        return SongContextMenu(
          song: song,
          child: _SearchResultRow(
            song: song,
            index: i,
            durationStr: durationStr,
            allResults: searchState.results,
          ),
        );
      },
    );
  }
}

// ─── Search result row ────────────────────────────────────────────────────────

class _SearchResultRow extends ConsumerStatefulWidget {
  final Song song;
  final int index;
  final String durationStr;
  final List<Song> allResults;

  const _SearchResultRow({
    required this.song,
    required this.index,
    required this.durationStr,
    required this.allResults,
  });

  @override
  ConsumerState<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends ConsumerState<_SearchResultRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(playerProvider);
    final isPlaying = ps.currentSong?.id == widget.song.id && ps.isPlaying;
    final isCurrent = ps.currentSong?.id == widget.song.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: isCurrent
            ? context.appTheme.selectedRow // green tint when current
            : _hovered
                ? context.appTheme.highlight
                : context.appTheme.main.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref.read(playerProvider.notifier).playSong(
                widget.song,
                queue: widget.allResults,
              ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Index — green speaker icon when this song is current
                SizedBox(
                  width: 28,
                  child: isCurrent
                      ? Icon(
                          isPlaying ? Icons.volume_up : Icons.volume_mute,
                          color: context.appTheme.button,
                          size: 16,
                        )
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
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              width: 48,
                              height: 48,
                              color: context.appTheme.card),
                          errorWidget: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: context.appTheme.card,
                            child: Icon(Icons.music_note,
                                color: context.appTheme.subtext
                                    .withValues(alpha: 0.54),
                                size: 20),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: context.appTheme.card,
                          child: Icon(Icons.music_note,
                              color: context.appTheme.subtext
                                  .withValues(alpha: 0.54),
                              size: 20),
                        ),
                ),
                SizedBox(width: 16),

                // Title + artist — green when current
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
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
                          color: isCurrent
                              ? context.appTheme.button.withValues(alpha: 0.7)
                              : context.appTheme.subtext,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration
                if (widget.durationStr.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.durationStr,
                      style: TextStyle(
                        color: isCurrent
                            ? context.appTheme.button.withValues(alpha: 0.7)
                            : context.appTheme.subtext,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // ··· menu button
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: SongMenuButton(song: widget.song),
                ),
                SizedBox(width: 4),

                // Play button — pause icon when this song is playing
                IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: context.appTheme.button,
                    size: 32,
                  ),
                  onPressed: () {
                    if (isCurrent) {
                      ref.read(playerProvider.notifier).togglePlayPause();
                    } else {
                      ref.read(playerProvider.notifier).playSong(
                            widget.song,
                            queue: widget.allResults,
                          );
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

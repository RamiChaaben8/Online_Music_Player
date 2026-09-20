// ============================================================
// desktop/desktop_search_view.dart
// Full-page search for desktop layout.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../providers/youtube_provider.dart';
import 'theme/desktop_theme.dart';

class DesktopSearchView extends ConsumerStatefulWidget {
  const DesktopSearchView({super.key});

  @override
  ConsumerState<DesktopSearchView> createState() =>
      _DesktopSearchViewState();
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
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: kTextSecondary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(
                          color: kTextPrimary, fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'What do you want to play?',
                        hintStyle: TextStyle(
                            color: kTextSecondary, fontSize: 16),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _search,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: kTextSecondary, size: 20),
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchProvider.notifier).clear();
                        setState(() {});
                      },
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // ── Results ───────────────────────────────────────────────────
          Expanded(
            child: _buildBody(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState searchState) {
    if (searchState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              searchState.error!,
              style: const TextStyle(color: kTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty && searchState.query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, color: kTextSecondary, size: 56),
            SizedBox(height: 12),
            Text(
              'Search for songs, artists, or albums',
              style: TextStyle(color: kTextSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Text(
          'No results for "${searchState.query}"',
          style:
              const TextStyle(color: kTextSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: searchState.results.length,
      itemBuilder: (ctx, i) {
        final song = searchState.results[i];
        final durationStr = song.duration != Duration.zero
            ? '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}'
            : '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                ref.read(playerProvider.notifier).playSong(
                      song,
                      queue: searchState.results,
                    ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Index
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: song.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.thumbnailUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 48,
                                height: 48,
                                color: kCardColor),
                            errorWidget: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: kCardColor,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white54, size: 20),
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: kCardColor,
                            child: const Icon(Icons.music_note,
                                color: Colors.white54, size: 20),
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Title + artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Duration
                  if (durationStr.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        durationStr,
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 13),
                      ),
                    ),

                  // Play button
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill,
                        color: kAccent, size: 32),
                    onPressed: () =>
                        ref.read(playerProvider.notifier).playSong(
                              song,
                              queue: searchState.results,
                            ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

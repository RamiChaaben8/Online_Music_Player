// ============================================================
// desktop/home/desktop_home_view.dart
// Center scrollable home panel.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../models/playlist.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_context_menu.dart';
import '../theme/desktop_theme.dart';

class DesktopHomeView extends ConsumerStatefulWidget {
  const DesktopHomeView({super.key});

  @override
  ConsumerState<DesktopHomeView> createState() => _DesktopHomeViewState();
}

class _DesktopHomeViewState extends ConsumerState<DesktopHomeView> {
  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: CustomScrollView(
        slivers: [
          // ── Home sections from homeProvider ───────────────────────────
          if (homeState.initialLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: kAccent),
                ),
              ),
            )
          else
            ...homeState.sections.asMap().entries.map((entry) {
              final i = entry.key;
              final section = entry.value;
              return SliverToBoxAdapter(
                child: _buildSection(
                  title: section.title,
                  subtitle: section.subtitle,
                  isLoading: section.isLoading,
                  child: SizedBox(
                    height: 260,
                    child: section.isLoading
                        ? _buildSkeletonRow()
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                          primary: false,
                          physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: section.songs.length,
                            itemBuilder: (ctx, j) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: DesktopMusicCard(
                                song: section.songs[j],
                                showBadge: i == 0,
                                badgeText: 'Daily Mix',
                              ),
                            ),
                          ),
                  ),
                ),
              );
            }),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
    bool isLoading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }


  Widget _buildSkeletonRow() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
                width: 130,
                height: 12,
                color: kCardColor,
                margin: const EdgeInsets.only(bottom: 4)),
            Container(width: 90, height: 10, color: kCardColor),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(color: kTextSecondary, fontSize: 12),
            ),
            Text(
              title,
              style: const TextStyle(
                color: kAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Desktop music card ───────────────────────────────────────────────────────

class DesktopMusicCard extends ConsumerStatefulWidget {
  final Song song;
  final bool showBadge;
  final String badgeText;
  /// If non-null the "Remove from playlist" option is shown.
  final Playlist? playlist;

  const DesktopMusicCard({
    super.key,
    required this.song,
    this.showBadge = false,
    this.badgeText = '',
    this.playlist,
  });

  @override
  ConsumerState<DesktopMusicCard> createState() => _DesktopMusicCardState();
}

class _DesktopMusicCardState extends ConsumerState<DesktopMusicCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return SongContextMenu(
      song: widget.song,
      currentPlaylist: widget.playlist,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () =>
              ref.read(playerProvider.notifier).playSong(widget.song),
          child: SizedBox(
            width: 172,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image with overlays
                Stack(
                  children: [
                    // Album art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.song.thumbnailUrl.isEmpty
                          ? Container(
                              width: 172,
                              height: 172,
                              color: kCardColor,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white54, size: 40),
                            )
                          : CachedNetworkImage(
                              imageUrl: widget.song.thumbnailUrl,
                              width: 172,
                              height: 172,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 172,
                                  height: 172,
                                  color: kCardColor),
                              errorWidget: (_, __, ___) => Container(
                                width: 172,
                                height: 172,
                                color: kCardColor,
                                child: const Icon(Icons.music_note,
                                    color: Colors.white54, size: 40),
                              ),
                            ),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xAA000000),
                              ],
                              stops: [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Badge
                    if (widget.showBadge && widget.badgeText.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.badgeText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Hover: play button + ··· button
                    if (_isHovered) ...[
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: kAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.black, size: 26),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: SongMenuButton(
                            song: widget.song,
                            currentPlaylist: widget.playlist,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Title row with ··· button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
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
                            widget.song.channelName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

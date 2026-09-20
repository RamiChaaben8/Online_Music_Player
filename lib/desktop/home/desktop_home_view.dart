// ============================================================
// desktop/home/desktop_home_view.dart
// Center scrollable home panel.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/home_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../theme/desktop_theme.dart';

class DesktopHomeView extends ConsumerStatefulWidget {
  const DesktopHomeView({super.key});

  @override
  ConsumerState<DesktopHomeView> createState() => _DesktopHomeViewState();
}

class _DesktopHomeViewState extends ConsumerState<DesktopHomeView> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final library = ref.watch(libraryProvider);
    final recentlyPlayed = library.recentlyPlayed;

    return Container(
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: CustomScrollView(
        slivers: [
          // ── Filter chips ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: ['All', 'Music', 'Podcasts'].map((label) {
                  final isActive = _activeFilter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeFilter = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive
                              ? kAccent
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isActive
                                ? Colors.black
                                : kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Quick access grid (recently played 2x4) ───────────────────
          if (recentlyPlayed.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildQuickAccessGrid(recentlyPlayed),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

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

          // ── Recents section ───────────────────────────────────────────
          if (recentlyPlayed.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Recents',
                subtitle: 'What you played lately',
                child: SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recentlyPlayed.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: DesktopMusicCard(song: recentlyPlayed[i]),
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Quick-access 2-row × 4-col grid ─────────────────────────────────────

  Widget _buildQuickAccessGrid(List<Song> songs) {
    final items = songs.take(8).toList();
    // Pad to 8 if fewer
    while (items.length < 8 && items.isNotEmpty) {
      items.add(items.last);
    }

    final rows = <Widget>[];
    for (var r = 0; r < 2; r++) {
      final rowItems = items.skip(r * 4).take(4).toList();
      rows.add(
        Row(
          children: rowItems.asMap().entries.map((e) {
            final col = e.key;
            final song = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: col < 3 ? 8.0 : 0.0,
                  bottom: r == 0 ? 8.0 : 0.0,
                ),
                child: _QuickTile(song: song),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  // ── Generic section layout ───────────────────────────────────────────────

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
          _SectionHeader(title: title, subtitle: subtitle),
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
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Show all',
            style: TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ─── Quick access tile ───────────────────────────────────────────────────────

class _QuickTile extends ConsumerWidget {
  final Song song;
  const _QuickTile({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: kCardColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ref.read(playerProvider.notifier).playSong(song),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: song.thumbnailUrl.isEmpty
                    ? Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFF3A3A3A),
                        child: const Icon(Icons.music_note,
                            color: Colors.white54, size: 20),
                      )
                    : CachedNetworkImage(
                        imageUrl: song.thumbnailUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFF3A3A3A)),
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFF3A3A3A),
                          child: const Icon(Icons.music_note,
                              color: Colors.white54, size: 20),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Desktop music card ───────────────────────────────────────────────────────

class DesktopMusicCard extends ConsumerStatefulWidget {
  final Song song;
  final bool showBadge;
  final String badgeText;

  const DesktopMusicCard({
    super.key,
    required this.song,
    this.showBadge = false,
    this.badgeText = '',
  });

  @override
  ConsumerState<DesktopMusicCard> createState() => _DesktopMusicCardState();
}

class _DesktopMusicCardState extends ConsumerState<DesktopMusicCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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

                  // Badge (Daily Mix etc.)
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

                  // Hover play button
                  if (_isHovered)
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
                ],
              ),

              const SizedBox(height: 8),

              // Title
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

              // Artist
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
      ),
    );
  }
}

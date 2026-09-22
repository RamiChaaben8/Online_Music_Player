// ============================================================
// screens/home_screen.dart
//
// Spotify / YT-Music style home feed:
//   • Time-of-day greeting header
//   • Quick-play chips (recently played, 2-column grid)
//   • Dynamic feed sections: Recommended, Trending, Your Taste,
//     New Releases, Chill Mix, Hip-Hop, Pop Hits
//
// Sections arrive one-by-one as their YouTube searches complete.
// Each section shows a shimmer skeleton while loading.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../models/song.dart';
import '../providers/home_provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import 'now_playing_screen.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/listen_party_controls.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final library = ref.watch(libraryProvider);
    final recent = library.recentlyPlayed;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1DB954),
          backgroundColor: const Color(0xFF1A1A1A),
          onRefresh: () => ref.read(homeProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Greeting header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
                  child: Row(
                    children: [
                      const ProfileAvatar(),
                      const Spacer(),
                      const PartyInviteButton(),
                    ],
                  ),
                ),
              ),

              // ── Quick-play grid (recently played) ────────────────────────
              if (recent.isNotEmpty)
                SliverToBoxAdapter(
                  child: _QuickPlayGrid(
                    songs: recent.take(6).toList(),
                    onTap: (song) {
                      if (ref.read(playerProvider).currentSong?.id == song.id) {
                        _openPlayer(context);
                      } else {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(song, queue: recent);
                        _openPlayer(context);
                      }
                    },
                  ),
                ),

              // ── Dynamic feed sections ────────────────────────────────────
              if (homeState.initialLoading)
                SliverToBoxAdapter(child: _buildFullSkeleton())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final section = homeState.sections[i];
                      return _SectionRow(
                        section: section,
                        onSongTap: (song) {
                          if (ref.read(playerProvider).currentSong?.id ==
                              song.id) {
                            _openPlayer(context);
                          } else {
                            ref
                                .read(playerProvider.notifier)
                                .playSong(song, queue: section.songs);
                            _openPlayer(context);
                          }
                        },
                      );
                    },
                    childCount: homeState.sections.length,
                  ),
                ),

              // Bottom padding for mini-player + nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFullSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: _SectionSkeleton(),
        ),
      ),
    );
  }
}

// ─── Quick-play 2-column grid ─────────────────────────────────────────────────

class _QuickPlayGrid extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song) onTap;

  const _QuickPlayGrid({required this.songs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recently Played',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 4.5,
            ),
            itemCount: songs.length,
            itemBuilder: (_, i) => _QuickPlayChip(
              song: songs[i],
              onTap: () => onTap(songs[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPlayChip extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _QuickPlayChip({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(6)),
              child: CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    width: 48, height: 48, color: const Color(0xFF282828)),
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFF282828),
                  child: const Icon(Icons.music_note,
                      color: Color(0xFF3A3A3A), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Section row ─────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final HomeSection section;
  final void Function(Song) onSongTap;

  const _SectionRow({
    required this.section,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (section.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          section.subtitle,
                          style: const TextStyle(
                            color: Color(0xFFB3B3B3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cards or skeleton
          if (section.isLoading)
            _SectionSkeleton()
          else if (section.songs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Nothing found right now',
                style: TextStyle(color: Color(0xFF555555), fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: section.songs.length,
                itemBuilder: (_, i) {
                  final song = section.songs[i];
                  return _SongCard(
                    song: song,
                    onTap: () => onSongTap(song),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Song card ────────────────────────────────────────────────────────────────

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 140,
                  height: 140,
                  color: const Color(0xFF1A1A1A),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 140,
                  height: 140,
                  color: const Color(0xFF1A1A1A),
                  child: const Icon(Icons.music_note,
                      color: Color(0xFF3A3A3A), size: 40),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              song.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer skeleton ─────────────────────────────────────────────────────────

class _SectionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1A1A1A),
        highlightColor: const Color(0xFF2A2A2A),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 100, height: 10, color: Colors.white),
                const SizedBox(height: 4),
                Container(width: 70, height: 8, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

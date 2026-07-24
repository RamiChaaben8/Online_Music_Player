// ============================================================
// screens/home_screen.dart — "Home / For You" tab
// Shows recently played and liked songs.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/horizontal_song_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final recent = library.recentlyPlayed;
    final liked = library.likedSongs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                _greeting(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Recently Played'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.take(10).length,
                  itemBuilder: (ctx, i) {
                    return HorizontalSongCard(
                      song: recent[i],
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .playSong(recent[i], queue: recent),
                    );
                  },
                ),
              ),
            ),
          ],
          if (liked.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Liked Songs'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => SongTile(
                  song: liked[i],
                  onTap: () => ref
                      .read(playerProvider.notifier)
                      .playSong(liked[i], queue: liked),
                ),
                childCount: liked.take(10).length,
              ),
            ),
          ],
          if (recent.isEmpty && liked.isEmpty)
            SliverFillRemaining(
              child: _emptyState(context),
            ),
          // Bottom padding for mini-player
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 72, color: Color(0xFF3A3A3A)),
          const SizedBox(height: 16),
          Text(
            'Your music awaits',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Search for songs to start listening',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

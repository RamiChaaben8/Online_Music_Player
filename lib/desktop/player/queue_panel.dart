// ============================================================
// desktop/player/queue_panel.dart
//
// Spotify-style queue side-panel for Windows desktop.
// Matches the mobile QueueScreen layout exactly:
//   • "NOW PLAYING" section with green-bordered tile
//   • "NEXT UP" section with count, drag-to-reorder, hover menu
//   • Same green accent colour (#1DB954)
//   • Clear queue button in header
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';

const _kGreen = Color(0xFF1DB954);
const _kCard = Color(0xFF1A1A1A);
const _kSurface = Color(0xFF121212);
const _kBorder = Color(0xFF2A2A2A);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFFB3B3B3);
const _kTextDim = Color(0xFF555555);

class QueuePanel extends ConsumerWidget {
  final VoidCallback onClose;
  const QueuePanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = ref.watch(playerProvider);
    final queue = ps.queue;
    final currentIndex = ps.currentIndex;

    final hasCurrent = currentIndex >= 0 && currentIndex < queue.length;
    final currentSong = hasCurrent ? queue[currentIndex] : null;
    final upNext = hasCurrent ? queue.sublist(currentIndex + 1) : <Song>[];

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(left: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          _Header(
            queueLength: queue.length,
            hasUpNext: upNext.isNotEmpty,
            currentIndex: currentIndex,
            onClose: onClose,
            onClear: () {
              final n = ref.read(playerProvider.notifier);
              for (int i = queue.length - 1; i > currentIndex; i--) {
                n.removeFromQueue(i);
              }
            },
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: queue.isEmpty
                ? const _Empty()
                : _Body(
                    queue: queue,
                    currentIndex: currentIndex,
                    currentSong: currentSong,
                    upNext: upNext,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int queueLength;
  final bool hasUpNext;
  final int currentIndex;
  final VoidCallback onClose;
  final VoidCallback onClear;

  const _Header({
    required this.queueLength,
    required this.hasUpNext,
    required this.currentIndex,
    required this.onClose,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music, color: _kGreen, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Queue',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$queueLength',
              style: const TextStyle(
                color: _kGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          if (hasUpNext)
            Tooltip(
              message: 'Clear queue',
              child: IconButton(
                icon: const Icon(Icons.clear_all, color: _kTextSecondary, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
          Tooltip(
            message: 'Close queue',
            child: IconButton(
              icon: const Icon(Icons.close, color: _kTextSecondary, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music, color: _kTextDim, size: 48),
          SizedBox(height: 12),
          Text('Queue is empty',
              style: TextStyle(
                  color: _kTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Add songs to start playing',
              style: TextStyle(color: _kTextDim, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final List<Song> queue;
  final int currentIndex;
  final Song? currentSong;
  final List<Song> upNext;

  const _Body({
    required this.queue,
    required this.currentIndex,
    required this.currentSong,
    required this.upNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        // ── NOW PLAYING ────────────────────────────────────────────────
        if (currentSong != null) ...[
          _SectionHeader(label: 'NOW PLAYING'),
          SliverToBoxAdapter(child: _NowPlayingTile(song: currentSong!)),
        ],

        // ── NEXT UP ────────────────────────────────────────────────────
        if (upNext.isNotEmpty) ...[
          _SectionHeader(label: 'NEXT UP  •  ${upNext.length} songs'),
          SliverReorderableList(
            itemCount: upNext.length,
            onReorder: (oldIndex, newIndex) {
              final qOld = currentIndex + 1 + oldIndex;
              final qNew = currentIndex + 1 + newIndex;
              ref.read(playerProvider.notifier).reorderQueue(qOld, qNew);
            },
            proxyDecorator: (child, index, animation) => Material(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              elevation: 6,
              child: child,
            ),
            itemBuilder: (ctx, i) {
              final song = upNext[i];
              final queueIndex = currentIndex + 1 + i;
              return _UpNextTile(
                key: ValueKey('${song.id}_$queueIndex'),
                song: song,
                queueIndex: queueIndex,
                slotIndex: i,
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ] else if (currentSong != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Nothing queued after this',
                  style: const TextStyle(color: _kTextDim, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(label: label),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  const _SectionHeaderDelegate({required this.label});

  @override double get minExtent => 34;
  @override double get maxExtent => 34;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: _kGreen,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) => old.label != label;
}

// ─── NOW PLAYING tile ─────────────────────────────────────────────────────────

class _NowPlayingTile extends StatelessWidget {
  final Song song;
  const _NowPlayingTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: _Thumb(url: song.thumbnailUrl, playing: true, size: 40),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _kGreen,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          song.channelName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _kTextSecondary, fontSize: 10),
        ),
        trailing: const Icon(Icons.graphic_eq, color: _kGreen, size: 18),
      ),
    );
  }
}

// ─── UP NEXT tile ─────────────────────────────────────────────────────────────

class _UpNextTile extends ConsumerStatefulWidget {
  final Song song;
  final int queueIndex;
  final int slotIndex;

  const _UpNextTile({
    super.key,
    required this.song,
    required this.queueIndex,
    required this.slotIndex,
  });

  @override
  ConsumerState<_UpNextTile> createState() => _UpNextTileState();
}

class _UpNextTileState extends ConsumerState<_UpNextTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            leading:
                _Thumb(url: widget.song.thumbnailUrl, playing: false, size: 38),
            title: Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextPrimary, fontSize: 12),
            ),
            subtitle: Text(
              widget.song.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _kTextSecondary, fontSize: 10),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Remove button (visible on hover)
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: _kTextSecondary, size: 15),
                    onPressed: () => ref
                        .read(playerProvider.notifier)
                        .removeFromQueue(widget.queueIndex),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ),
                // Context menu (visible on hover)
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz,
                        color: _kTextSecondary, size: 15),
                    onPressed: () {
                      final box =
                          context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final pos = box.localToGlobal(Offset.zero);
                      _showContextMenu(
                          context,
                          Offset(pos.dx + box.size.width,
                              pos.dy + box.size.height / 2));
                    },
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ),
                // Drag handle
                ReorderableDragStartListener(
                  index: widget.slotIndex,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.drag_handle,
                        color: Color(0xFF3A3A3A), size: 16),
                  ),
                ),
              ],
            ),
            onTap: () {
              final queue = ref.read(playerProvider).queue;
              ref.read(playerProvider.notifier).playSong(
                    widget.song,
                    queue: queue,
                  );
            },
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: _kCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _menuItem('play', Icons.play_arrow_outlined, 'Play now'),
        _menuItem('playNext', Icons.queue_play_next, 'Play next'),
        _menuItem('addToEnd', Icons.add_to_queue, 'Move to end'),
        const PopupMenuDivider(),
        _menuItem('remove', Icons.remove_circle_outline, 'Remove',
            color: Colors.redAccent),
      ],
    );

    if (!mounted) return;
    final n = ref.read(playerProvider.notifier);

    switch (selected) {
      case 'play':
        n.playSong(widget.song, queue: ref.read(playerProvider).queue);
      case 'playNext':
        n.removeFromQueue(widget.queueIndex);
        n.playNext(widget.song);
      case 'addToEnd':
        n.removeFromQueue(widget.queueIndex);
        n.addToQueue(widget.song);
      case 'remove':
        n.removeFromQueue(widget.queueIndex);
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? _kTextPrimary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: c, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Thumbnail ────────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final String url;
  final bool playing;
  final double size;

  const _Thumb({required this.url, required this.playing, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: size, height: size, color: _kCard),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        if (playing)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.graphic_eq, color: _kGreen, size: 18),
          ),
      ],
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: _kCard,
        child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A), size: 16),
      );
}

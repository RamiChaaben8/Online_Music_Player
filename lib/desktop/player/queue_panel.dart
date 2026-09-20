// ============================================================
// desktop/player/queue_panel.dart
//
// Spotify-style queue side-panel for Windows desktop.
//
// Features
// ─────────────────────────────────────────────────────────────
// • "NOW PLAYING" and "NEXT UP" section headers
// • Tap any song to play it immediately
// • Right-click / hover menu: Play Next, Add to Queue, Remove
// • Drag-handle reorder for up-next items
// • Swipe-to-remove (mouse drag) via Dismissible
// • "Clear queue" button in the header
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../theme/desktop_theme.dart';

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
    final upNext =
        hasCurrent ? queue.sublist(currentIndex + 1) : <Song>[];

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(left: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          _PanelHeader(
            count: queue.length,
            hasUpNext: upNext.isNotEmpty,
            currentIndex: currentIndex,
            onClose: onClose,
            onClearQueue: () {
              final notifier = ref.read(playerProvider.notifier);
              for (int i = queue.length - 1; i > currentIndex; i--) {
                notifier.removeFromQueue(i);
              }
            },
          ),

          // ── Queue list ────────────────────────────────────────────────
          Expanded(
            child: queue.isEmpty
                ? const _EmptyState()
                : _QueueBody(
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

// ─── Panel header ─────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final int count;
  final bool hasUpNext;
  final int currentIndex;
  final VoidCallback onClose;
  final VoidCallback onClearQueue;

  const _PanelHeader({
    required this.count,
    required this.hasUpNext,
    required this.currentIndex,
    required this.onClose,
    required this.onClearQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music, color: kAccent, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Queue',
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // Clear queue
          if (hasUpNext)
            Tooltip(
              message: 'Clear queue',
              child: IconButton(
                icon: const Icon(Icons.clear_all,
                    color: kTextSecondary, size: 18),
                onPressed: onClearQueue,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
          Tooltip(
            message: 'Close queue',
            child: IconButton(
              icon: const Icon(Icons.close,
                  color: kTextSecondary, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music, color: kTextSecondary, size: 40),
          SizedBox(height: 10),
          Text(
            'Queue is empty',
            style: TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Queue body ───────────────────────────────────────────────────────────────

class _QueueBody extends ConsumerWidget {
  final List<Song> queue;
  final int currentIndex;
  final Song? currentSong;
  final List<Song> upNext;

  const _QueueBody({
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
          SliverToBoxAdapter(
            child: _NowPlayingTile(song: currentSong!),
          ),
        ],

        // ── NEXT UP ────────────────────────────────────────────────────
        if (upNext.isNotEmpty) ...[
          _SectionHeader(label: 'NEXT UP  •  ${upNext.length}'),
          SliverReorderableList(
            itemCount: upNext.length,
            onReorder: (oldIndex, newIndex) {
              final qOld = currentIndex + 1 + oldIndex;
              final qNew = currentIndex + 1 + newIndex;
              ref
                  .read(playerProvider.notifier)
                  .reorderQueue(qOld, qNew);
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
                elevation: 6,
                child: child,
              );
            },
            itemBuilder: (ctx, i) {
              final song = upNext[i];
              final queueIndex = currentIndex + 1 + i;
              return _UpNextTile(
                key: ValueKey('${song.id}_$queueIndex'),
                song: song,
                index: queueIndex,
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
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 12),
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

  @override double get minExtent => 30;
  @override double get maxExtent => 30;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    return Container(
      color: const Color(0xFF121212),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: kAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: kAccent, width: 2)),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: _Thumb(url: song.thumbnailUrl, playing: true, size: 38),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: kAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          song.channelName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTextSecondary, fontSize: 10),
        ),
        trailing: const Icon(Icons.graphic_eq, color: kAccent, size: 16),
      ),
    );
  }
}

// ─── UP NEXT tile ─────────────────────────────────────────────────────────────

class _UpNextTile extends ConsumerStatefulWidget {
  final Song song;
  final int index;
  final int slotIndex;

  const _UpNextTile({
    super.key,
    required this.song,
    required this.index,
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
        child: Container(
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            leading:
                _Thumb(url: widget.song.thumbnailUrl, playing: false, size: 36),
            title: Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextPrimary, fontSize: 12),
            ),
            subtitle: Text(
              widget.song.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kTextSecondary, fontSize: 10),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Context menu button (visible on hover)
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz,
                        color: kTextSecondary, size: 16),
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
                    constraints: const BoxConstraints(
                        minWidth: 24, minHeight: 24),
                  ),
                ),
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
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          value: 'play',
          child: _MenuRow(
            icon: Icons.play_arrow_outlined,
            label: 'Play now',
          ),
        ),
        PopupMenuItem(
          value: 'playNext',
          child: _MenuRow(
            icon: Icons.queue_play_next,
            label: 'Play next',
          ),
        ),
        PopupMenuItem(
          value: 'addToQueue',
          child: _MenuRow(
            icon: Icons.add_to_queue,
            label: 'Move to end',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'remove',
          child: _MenuRow(
            icon: Icons.remove_circle_outline,
            label: 'Remove',
            color: Colors.redAccent,
          ),
        ),
      ],
    );

    if (!mounted) return;
    final notifier = ref.read(playerProvider.notifier);

    switch (selected) {
      case 'play':
        final queue = ref.read(playerProvider).queue;
        notifier.playSong(widget.song, queue: queue);
        break;
      case 'playNext':
        notifier.removeFromQueue(widget.index);
        notifier.playNext(widget.song);
        break;
      case 'addToQueue':
        notifier.removeFromQueue(widget.index);
        notifier.addToQueue(widget.song);
        break;
      case 'remove':
        notifier.removeFromQueue(widget.index);
        break;
    }
  }
}

// ─── Menu row helper ──────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kTextPrimary;
    return Row(
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c, fontSize: 13)),
      ],
    );
  }
}

// ─── Thumbnail helper ─────────────────────────────────────────────────────────

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
          borderRadius: BorderRadius.circular(4),
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: size, height: size, color: kCardColor),
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
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.graphic_eq, color: kAccent, size: 16),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: kCardColor,
      child: const Icon(Icons.music_note, color: Colors.white38, size: 14),
    );
  }
}

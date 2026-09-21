// ============================================================
// desktop/sidebar/desktop_sidebar.dart
// Left panel — playlists + library navigation.
//
// • Right-click a playlist → context menu (Add to Queue, Rename, Remove)
// • ··· button on each playlist tile → same menu
// • Liked Songs tile → opens like a playlist (read-only, no edit/remove)
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../providers/library_provider.dart';
import '../../services/firestore_service.dart';
import '../../providers/player_provider.dart';
import '../theme/desktop_theme.dart';
import '../../widgets/import_playlist_dialog.dart';

class DesktopSidebar extends ConsumerStatefulWidget {
  final Playlist? selectedPlaylist;
  final void Function(Playlist?) onPlaylistSelected;

  const DesktopSidebar({
    super.key,
    required this.selectedPlaylist,
    required this.onPlaylistSelected,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  bool _collapsed = false;

  static const double _kCollapsedWidth = 64.0;

  /// Returns true if [a] and [b] refer to the same playlist.
  /// Prefers Firestore ID comparison, falls back to Hive key, then name+createdAt.
  bool _isSamePlaylist(Playlist a, Playlist b) {
    final aFsId = a.firestoreId;
    final bFsId = b.firestoreId;
    if (aFsId != null && bFsId != null) return aFsId == bFsId;
    final aKey = a.key;
    final bKey = b.key;
    if (aKey != null && bKey != null) return aKey == bKey;
    return a.name == b.name && a.createdAt == b.createdAt;
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    final likedPlaylist = library.likedSongs.isNotEmpty
        ? Playlist(name: 'Liked Songs', songs: library.likedSongs)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _collapsed ? _kCollapsedWidth : kSidebarWidth,
      decoration: BoxDecoration(
        color: context.appTheme.sidebar,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _collapsed
          ? _buildCollapsed(likedPlaylist, library)
          : _buildExpanded(likedPlaylist, library),
    );
  }

  // ── Collapsed: icon-only column ──────────────────────────────────────────

  Widget _buildCollapsed(Playlist? likedPlaylist, LibraryState library) {
    return Column(
      children: [
        SizedBox(height: 16),

        // Library icon — tap to expand
        Tooltip(
          message: 'Expand library',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _collapsed = false),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.library_music,
                  color: context.appTheme.button, size: 24),
            ),
          ),
        ),

        SizedBox(height: 8),
        Divider(color: context.appTheme.shadow, height: 1, thickness: 0.5),
        SizedBox(height: 8),

        // Liked Songs icon
        if (likedPlaylist != null)
          Tooltip(
            message: 'Liked Songs',
            child: _IconOnlyTile(
              icon: Icons.favorite,
              color: context.appTheme.misc,
              bgColor: context.appTheme.misc.withValues(alpha: 0.35),
              isActive: widget.selectedPlaylist?.name == 'Liked Songs',
              onTap: () {
                final active = widget.selectedPlaylist?.name == 'Liked Songs';
                widget.onPlaylistSelected(active ? null : likedPlaylist);
              },
            ),
          ),

        if (likedPlaylist != null) SizedBox(height: 4),

        // Playlist icons
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: 4),
            children: library.playlists.map((pl) {
              final thumbUrl =
                  pl.songs.isNotEmpty ? pl.songs.first.thumbnailUrl : '';
              final isActive = widget.selectedPlaylist != null &&
                  _isSamePlaylist(widget.selectedPlaylist!, pl);
              return Tooltip(
                message: pl.name,
                child: _IconOnlyTile(
                  thumbUrl: thumbUrl,
                  isActive: isActive,
                  onTap: () => widget.onPlaylistSelected(isActive ? null : pl),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Expanded: full sidebar ───────────────────────────────────────────────

  Widget _buildExpanded(Playlist? likedPlaylist, LibraryState library) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              // Library icon — tap to collapse
              Tooltip(
                message: 'Collapse library',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _collapsed = true),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.library_music,
                        color: context.appTheme.button, size: 22),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Your Library',
                style: TextStyle(
                  color: context.appTheme.button,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Create playlist',
                child: IconButton(
                  onPressed: () => _showCreatePlaylistDialog(context),
                  icon:
                      Icon(Icons.add, size: 18, color: context.appTheme.button),
                  padding: EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  splashRadius: 16,
                ),
              ),
              Tooltip(
                message: 'Import playlist',
                child: IconButton(
                  onPressed: () => showImportPlaylistDialog(context, ref),
                  icon: Icon(Icons.playlist_add,
                      size: 18, color: context.appTheme.button),
                  padding: EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  splashRadius: 16,
                ),
              ),
            ],
          ),
        ),

        // ── Filter chip ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: context.appTheme.tabActive,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Playlists',
              style: TextStyle(
                color: context.appTheme.button,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        Divider(color: context.appTheme.shadow, height: 16, thickness: 0.5),

        // ── List ───────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: 8),
            children: [
              if (likedPlaylist != null)
                _LikedSongsTile(
                  playlist: likedPlaylist,
                  isActive: widget.selectedPlaylist?.name == 'Liked Songs',
                  onTap: () {
                    final active =
                        widget.selectedPlaylist?.name == 'Liked Songs';
                    widget.onPlaylistSelected(active ? null : likedPlaylist);
                  },
                ),
              if (likedPlaylist != null)
                Divider(
                    color: context.appTheme.shadow, height: 16, thickness: 0.5),
              if (library.playlists.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No playlists yet.\nTap + Create to add one.',
                    style: TextStyle(
                        color: context.appTheme.subtext, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...library.playlists.map((playlist) {
                  final isActive = widget.selectedPlaylist != null &&
                      _isSamePlaylist(widget.selectedPlaylist!, playlist);
                  return _PlaylistTile(
                    playlist: playlist,
                    isActive: isActive,
                    onTap: () =>
                        widget.onPlaylistSelected(isActive ? null : playlist),
                    onOpen: () => widget.onPlaylistSelected(playlist),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    var visibility = 'private';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.card,
        insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        title: Text('New Playlist',
            style: TextStyle(color: context.appTheme.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: context.appTheme.text),
              decoration: InputDecoration(
                hintText: 'Playlist name',
                hintStyle: TextStyle(color: context.appTheme.subtext),
                filled: true,
                fillColor: context.appTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
            ),
            DropdownButtonFormField<String>(
              value: visibility,
              decoration: InputDecoration(labelText: 'Privacy'),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('Private')),
                DropdownMenuItem(value: 'friends', child: Text('Friends')),
                DropdownMenuItem(value: 'public', child: Text('Public')),
              ],
              onChanged: (value) => visibility = value ?? 'private',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.appTheme.subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.appTheme.button),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child:
                Text('Create', style: TextStyle(color: context.appTheme.text)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref
          .read(libraryProvider.notifier)
          .createPlaylist(name, visibility: visibility);
    }
  }
}

// Top-level enum — cannot be declared inside a class in Dart
// ─── Icon-only tile (collapsed mode) ─────────────────────────────────────────

class _IconOnlyTile extends StatefulWidget {
  final IconData? icon;
  final Color? color;
  final Color? bgColor;
  final String? thumbUrl;
  final bool isActive;
  final VoidCallback onTap;

  const _IconOnlyTile({
    this.icon,
    this.color,
    this.bgColor,
    this.thumbUrl,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_IconOnlyTile> createState() => _IconOnlyTileState();
}

class _IconOnlyTileState extends State<_IconOnlyTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.isActive
                ? context.appTheme.selectedRow
                : _hovered
                    ? context.appTheme.highlight
                    : context.appTheme.main.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(
                    color: context.appTheme.button.withValues(alpha: 0.5),
                    width: 1)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.thumbUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _iconBox(),
                    errorWidget: (_, __, ___) => _iconBox(),
                  )
                : _iconBox(),
          ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      color: widget.bgColor ?? context.appTheme.misc.withValues(alpha: 0.7),
      child: Icon(
        widget.icon ?? Icons.queue_music,
        color: widget.color ?? context.appTheme.subtext.withValues(alpha: 0.54),
        size: 22,
      ),
    );
  }
}

// ─── Playlist tile with right-click + ··· menu ───────────────────────────────

class _PlaylistTile extends ConsumerStatefulWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _PlaylistTile({
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.onOpen,
  });

  @override
  ConsumerState<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends ConsumerState<_PlaylistTile> {
  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.playlist.songs.isNotEmpty
        ? widget.playlist.songs.first.thumbnailUrl
        : '';

    return MouseRegion(
      child: GestureDetector(
        // Right-click opens context menu
        onSecondaryTapUp: (d) => _showMenu(context, d.globalPosition),
        child: Material(
          color: widget.isActive
              ? context.appTheme.selectedRow
              : context.appTheme.main.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: thumbUrl.isEmpty
                        ? Container(
                            width: 48,
                            height: 48,
                            color: context.appTheme.misc.withValues(alpha: 0.7),
                            child: Icon(Icons.queue_music,
                                color: context.appTheme.subtext
                                    .withValues(alpha: 0.54),
                                size: 22),
                          )
                        : CachedNetworkImage(
                            imageUrl: thumbUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 48,
                                height: 48,
                                color: context.appTheme.misc
                                    .withValues(alpha: 0.7)),
                            errorWidget: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color:
                                  context.appTheme.misc.withValues(alpha: 0.7),
                              child: Icon(Icons.queue_music,
                                  color: context.appTheme.subtext
                                      .withValues(alpha: 0.54),
                                  size: 22),
                            ),
                          ),
                  ),
                  SizedBox(width: 12),

                  // Name + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isActive
                                ? context.appTheme.button
                                : context.appTheme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Playlist • ${widget.playlist.songs.length} songs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.appTheme.subtext, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Playlist options',
                    icon: Icon(Icons.more_horiz,
                        color: context.appTheme.subtext, size: 22),
                    onPressed: () {
                      final box = context.findRenderObject() as RenderBox;
                      _showMenu(context, box.localToGlobal(Offset.zero));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu<_PlaylistAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: context.appTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appTheme.shadow),
      ),
      items: [
        _menuItem(
          _PlaylistAction.open,
          Icons.open_in_new,
          'Open',
        ),
        _menuItem(
          _PlaylistAction.addToQueue,
          Icons.queue_music_outlined,
          'Add to Queue',
        ),
        const PopupMenuDivider(height: 1),
        _menuItem(
          _PlaylistAction.rename,
          Icons.edit_outlined,
          'Edit playlist',
        ),
        _menuItem(
          _PlaylistAction.visibility,
          Icons.lock_outline,
          'Change privacy',
        ),
        _menuItem(
          _PlaylistAction.delete,
          Icons.delete_outline,
          'Remove playlist',
          color: context.appTheme.notificationError,
        ),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case _PlaylistAction.open:
          widget.onOpen();
        case _PlaylistAction.addToQueue:
          _addAllToQueue();
        case _PlaylistAction.rename:
          _showRenameDialog();
        case _PlaylistAction.visibility:
          _showVisibilityMenu();
        case _PlaylistAction.delete:
          _confirmDelete();
      }
    });
  }

  PopupMenuItem<_PlaylistAction> _menuItem(
    _PlaylistAction value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? context.appTheme.text;
    return PopupMenuItem(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.withValues(alpha: 0.85)),
          SizedBox(width: 10),
          Text(label, style: TextStyle(color: c, fontSize: 13)),
        ],
      ),
    );
  }

  void _addAllToQueue() {
    final notifier = ref.read(playerProvider.notifier);
    for (final song in widget.playlist.songs) {
      notifier.addToQueue(song);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.playlist.songs.length} songs added to queue'),
        backgroundColor: context.appTheme.button,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: widget.playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.card,
        title: Text('Rename Playlist',
            style: TextStyle(color: context.appTheme.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: context.appTheme.text),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: context.appTheme.subtext),
            filled: true,
            fillColor: context.appTheme.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.appTheme.subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.appTheme.button),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: TextStyle(color: context.appTheme.text)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await ref
          .read(libraryProvider.notifier)
          .renamePlaylistObj(widget.playlist, name);
    }
  }

  Future<void> _showVisibilityMenu() async {
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appTheme.card,
        title: Text('Playlist privacy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ['private', 'friends', 'public'])
              RadioListTile<String>(
                value: option,
                groupValue: widget.playlist.visibility,
                title: Text(option[0].toUpperCase() + option.substring(1)),
                onChanged: (selected) => Navigator.pop(dialogContext, selected),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      await ref
          .read(libraryProvider.notifier)
          .setPlaylistVisibility(widget.playlist, value);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.card,
        title: Text('Remove Playlist',
            style: TextStyle(color: context.appTheme.text)),
        content: Text(
          'Remove "${widget.playlist.name}"? This cannot be undone.',
          style: TextStyle(color: context.appTheme.subtext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: context.appTheme.subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.appTheme.notificationError),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Remove', style: TextStyle(color: context.appTheme.text)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(libraryProvider.notifier)
          .deletePlaylistObj(widget.playlist);
    }
  }
}

enum _PlaylistAction { open, addToQueue, rename, visibility, delete }

// ─── Liked Songs tile (read-only, opens like a playlist) ─────────────────────

class _LikedSongsTile extends StatefulWidget {
  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;

  const _LikedSongsTile({
    required this.playlist,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_LikedSongsTile> createState() => _LikedSongsTileState();
}

class _LikedSongsTileState extends State<_LikedSongsTile> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isActive
          ? context.appTheme.selectedRow
          : context.appTheme.main.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Purple gradient icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.appTheme.misc.withValues(alpha: 0.65),
                      context.appTheme.misc,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.favorite,
                    color: context.appTheme.text, size: 22),
              ),
              SizedBox(width: 12),

              // Title + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liked Songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isActive
                            ? context.appTheme.button
                            : context.appTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Playlist • ${widget.playlist.songs.length} songs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.appTheme.subtext, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

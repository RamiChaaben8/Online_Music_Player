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
import '../../providers/auth_provider.dart';
import '../../screens/auth/delete_account_screen.dart';
import '../theme/desktop_theme.dart';

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
      decoration: const BoxDecoration(
        color: kPanelColor,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _collapsed ? _buildCollapsed(likedPlaylist, library) : _buildExpanded(likedPlaylist, library),
    );
  }

  // ── Collapsed: icon-only column ──────────────────────────────────────────

  Widget _buildCollapsed(Playlist? likedPlaylist, LibraryState library) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Library icon — tap to expand
        Tooltip(
          message: 'Expand library',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _collapsed = false),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.library_music, color: kAccent, size: 24),
            ),
          ),
        ),

        const SizedBox(height: 8),
        const Divider(color: kBorderColor, height: 1, thickness: 0.5),
        const SizedBox(height: 8),

        // Liked Songs icon
        if (likedPlaylist != null)
          Tooltip(
            message: 'Liked Songs',
            child: _IconOnlyTile(
              icon: Icons.favorite,
              color: const Color(0xFF7B4FE9),
              bgColor: const Color(0xFF2A1A4A),
              isActive: widget.selectedPlaylist?.name == 'Liked Songs',
              onTap: () {
                final active = widget.selectedPlaylist?.name == 'Liked Songs';
                widget.onPlaylistSelected(active ? null : likedPlaylist);
              },
            ),
          ),

        if (likedPlaylist != null) const SizedBox(height: 4),

        // Playlist icons
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: library.playlists.map((pl) {
              final thumbUrl = pl.songs.isNotEmpty
                  ? pl.songs.first.thumbnailUrl
                  : '';
              final isActive = widget.selectedPlaylist != null &&
                  _isSamePlaylist(widget.selectedPlaylist!, pl);
              return Tooltip(
                message: pl.name,
                child: _IconOnlyTile(
                  thumbUrl: thumbUrl,
                  isActive: isActive,
                  onTap: () =>
                      widget.onPlaylistSelected(isActive ? null : pl),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              // Library icon — tap to collapse
              Tooltip(
                message: 'Collapse library',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _collapsed = true),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.library_music,
                        color: kAccent, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Library',
                style: TextStyle(
                  color: kAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    _showCreatePlaylistDialog(context),
                icon: const Icon(Icons.add, size: 16, color: kAccent),
                label: const Text(
                  'Create',
                  style: TextStyle(color: kAccent, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              // Sign-out button
              Tooltip(
                message: 'Sign out',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _confirmSignOut(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.logout,
                        color: Color(0xFFB3B3B3), size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Filter chip ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3321),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Playlists',
              style: TextStyle(
                color: kAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ── Search row ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: const [
              Icon(Icons.search, color: kTextSecondary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recents',
                  style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.list, color: kTextSecondary, size: 18),
            ],
          ),
        ),

        const Divider(
            color: kBorderColor, height: 16, thickness: 0.5),

        // ── List ───────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              if (likedPlaylist != null)
                _LikedSongsTile(
                  playlist: likedPlaylist,
                  isActive:
                      widget.selectedPlaylist?.name == 'Liked Songs',
                  onTap: () {
                    final active =
                        widget.selectedPlaylist?.name == 'Liked Songs';
                    widget.onPlaylistSelected(
                        active ? null : likedPlaylist);
                  },
                ),

              if (likedPlaylist != null)
                const Divider(
                    color: kBorderColor,
                    height: 16,
                    thickness: 0.5),

              if (library.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No playlists yet.\nTap + Create to add one.',
                    style: TextStyle(
                        color: kTextSecondary, fontSize: 13),
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
                    onTap: () => widget.onPlaylistSelected(
                        isActive ? null : playlist),
                    onOpen: () =>
                        widget.onPlaylistSelected(playlist),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final action = await showDialog<_SignOutAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Account',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'What would you like to do?',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SignOutAction.deleteAccount),
            child: const Text('Delete Account',
                style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kAccent, foregroundColor: Colors.black),
            onPressed: () =>
                Navigator.pop(ctx, _SignOutAction.signOut),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (action) {
      case _SignOutAction.signOut:
        await ref.read(playerProvider.notifier).pause().catchError((_) {});
        await ref.read(authServiceProvider).signOut();
      case _SignOutAction.deleteAccount:
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const DeleteAccountScreen()),
        );
      case null:
        break;
    }
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelLight,
        title: const Text('New Playlist',
            style: TextStyle(color: kTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: kTextSecondary),
            filled: true,
            fillColor: kCardColor,
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
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: kAccent),
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(libraryProvider.notifier)
          .createPlaylist(name);
    }
  }
}

// Top-level enum — cannot be declared inside a class in Dart
enum _SignOutAction { signOut, deleteAccount }

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
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF1A2A1A)
                : _hovered
                    ? const Color(0xFF2A2A2A)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(color: kAccent.withOpacity(0.5), width: 1)
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
      color: widget.bgColor ?? const Color(0xFF4A2C7A),
      child: Icon(
        widget.icon ?? Icons.queue_music,
        color: widget.color ?? Colors.white54,
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
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.playlist.songs.isNotEmpty
        ? widget.playlist.songs.first.thumbnailUrl
        : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        // Right-click opens context menu
        onSecondaryTapUp: (d) =>
            _showMenu(context, d.globalPosition),
        child: Material(
          color: widget.isActive
              ? const Color(0xFF1A2A1A)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: thumbUrl.isEmpty
                        ? Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF4A2C7A),
                            child: const Icon(Icons.queue_music,
                                color: Colors.white54, size: 22),
                          )
                        : CachedNetworkImage(
                            imageUrl: thumbUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 48,
                                height: 48,
                                color: const Color(0xFF4A2C7A)),
                            errorWidget: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: const Color(0xFF4A2C7A),
                              child: const Icon(Icons.queue_music,
                                  color: Colors.white54,
                                  size: 22),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Name + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isActive
                                ? kAccent
                                : kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Playlist • ${widget.playlist.songs.length} songs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kTextSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // ··· button (visible on hover or active)
                  AnimatedOpacity(
                    opacity:
                        (_hovering || widget.isActive) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.more_horiz,
                            color: kTextSecondary, size: 18),
                        onPressed: () {
                          // Get the button's position for the menu
                          final box = context.findRenderObject()
                              as RenderBox;
                          final offset = box
                              .localToGlobal(Offset.zero);
                          _showMenu(
                            context,
                            Offset(offset.dx + box.size.width,
                                offset.dy + box.size.height / 2),
                          );
                        },
                      ),
                    ),
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
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2E2E50)),
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
          'Rename',
        ),
        _menuItem(
          _PlaylistAction.delete,
          Icons.delete_outline,
          'Remove playlist',
          color: Colors.redAccent,
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
        case _PlaylistAction.delete:
          _confirmDelete();
      }
    });
  }

  PopupMenuItem<_PlaylistAction> _menuItem(
    _PlaylistAction value,
    IconData icon,
    String label, {
    Color color = Colors.white,
  }) {
    return PopupMenuItem(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.85)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: color, fontSize: 13)),
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
        content: Text(
            '${widget.playlist.songs.length} songs added to queue'),
        backgroundColor: kAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    final controller =
        TextEditingController(text: widget.playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelLight,
        title: const Text('Rename Playlist',
            style: TextStyle(color: kTextPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle:
                const TextStyle(color: kTextSecondary),
            filled: true,
            fillColor: kCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) =>
              Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kAccent),
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: Colors.black)),
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanelLight,
        title: const Text('Remove Playlist',
            style: TextStyle(color: kTextPrimary)),
        content: Text(
          'Remove "${widget.playlist.name}"? This cannot be undone.',
          style: const TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
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

enum _PlaylistAction { open, addToQueue, rename, delete }

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
            ? const Color(0xFF1A2A1A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Purple gradient icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4B2D8A),
                        Color(0xFF7B4FE9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.favorite,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),

                // Title + count
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liked Songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isActive
                              ? kAccent
                              : kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Playlist • ${widget.playlist.songs.length} songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12),
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

// ============================================================
// desktop/shell/desktop_title_bar.dart
// 64px top bar — sits inside Flutter content area.
// ============================================================

import 'package:flutter/material.dart';
import '../theme/desktop_theme.dart';

class DesktopTitleBar extends StatefulWidget {
  final int currentView;           // 0=home, 1=search
  final VoidCallback? onSearchTap;
  final void Function(String query)? onSearch;
  final VoidCallback? onHome;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final bool canGoBack;
  final bool canGoForward;

  const DesktopTitleBar({
    super.key,
    this.currentView = 0,
    this.onSearchTap,
    this.onSearch,
    this.onHome,
    this.onBack,
    this.onForward,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.instance.value;
    final isRed = theme.name == 'Red';

    return Container(
      height: kTopBarHeight,
      color: theme.bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Left: nav controls ─────────────────────────────────────────
          _navBtn(
            Icons.arrow_back_ios_new,
            size: 16,
            enabled: widget.canGoBack,
            onPressed: widget.onBack,
            theme: theme,
          ),
          const SizedBox(width: 4),
          _navBtn(
            Icons.arrow_forward_ios,
            size: 16,
            enabled: widget.canGoForward,
            onPressed: widget.onForward,
            theme: theme,
          ),

          // ── Center: home + search ──────────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconBtn(
                  Icons.home,
                  color: widget.currentView == 0
                      ? theme.accent
                      : theme.textSecondary,
                  onPressed: widget.onHome,
                  tooltip: 'Home',
                ),
                const SizedBox(width: 8),
                _buildSearchField(theme),
              ],
            ),
          ),

          // ── Right: theme toggle + bell + people + avatar ───────────────
          // Theme toggle button
          Tooltip(
            message: isRed ? 'Switch to Green theme' : 'Switch to Red theme',
            child: GestureDetector(
              onTap: () => AppThemeNotifier.instance.toggle(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.cardColor,
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRed
                          ? const Color(0xFF1DB954) // show green when red is active
                          : const Color(0xFFE8173A), // show red when green is active
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.notifications_none_outlined,
              color: theme.textSecondary),
          const SizedBox(width: 4),
          _iconBtn(Icons.people_outline, color: theme.textSecondary),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.cardColor,
            child: Icon(Icons.person, color: theme.textSecondary, size: 18),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppThemeData theme) {
    return Container(
      height: 40,
      width: 340,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: theme.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'What do you want to play?',
                hintStyle:
                    TextStyle(color: theme.textSecondary, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) {
                  widget.onSearch?.call(q.trim());
                }
              },
              onTap: widget.onSearchTap,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon,
      {double size = 20,
      bool enabled = true,
      VoidCallback? onPressed,
      required AppThemeData theme}) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon,
          color: enabled
              ? theme.textPrimary
              : theme.textSecondary.withValues(alpha: 0.4),
          size: size),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _iconBtn(IconData icon,
      {Color? color,
      double size = 20,
      VoidCallback? onPressed,
      String? tooltip}) {
    final theme = AppThemeNotifier.instance.value;
    return IconButton(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, color: color ?? theme.textSecondary, size: size),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: tooltip,
    );
  }
}

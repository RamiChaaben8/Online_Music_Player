// ============================================================
// desktop/shell/desktop_title_bar.dart
// 64px top bar — sits inside Flutter content area.
// No window_manager needed; native OS title bar remains above.
// ============================================================

import 'package:flutter/material.dart';
import '../theme/desktop_theme.dart';

class DesktopTitleBar extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final void Function(String query)? onSearch;

  const DesktopTitleBar({
    super.key,
    this.onSearchTap,
    this.onSearch,
  });

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      color: kBgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Left: nav controls ─────────────────────────────────────────
          _iconBtn(Icons.more_horiz),
          const SizedBox(width: 4),
          _iconBtn(Icons.arrow_back_ios_new, size: 16),
          const SizedBox(width: 4),
          _iconBtn(Icons.arrow_forward_ios, size: 16),
          const SizedBox(width: 8),
          _iconBtn(Icons.shopping_cart_outlined),

          // ── Center: home + search + inbox ──────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconBtn(Icons.home, color: kAccent),
                const SizedBox(width: 8),
                _buildSearchField(),
                const SizedBox(width: 8),
                _iconBtn(Icons.inbox_outlined),
              ],
            ),
          ),

          // ── Right: bell + people + avatar ─────────────────────────────
          _iconBtn(Icons.notifications_none_outlined),
          const SizedBox(width: 4),
          _iconBtn(Icons.people_outline),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: kCardColor,
            child: const Icon(Icons.person, color: kTextSecondary, size: 18),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: kTextSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'What do you want to play?',
                hintStyle: TextStyle(color: kTextSecondary, fontSize: 14),
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

  Widget _iconBtn(IconData icon,
      {Color color = kTextSecondary, double size = 20}) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, color: color, size: size),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

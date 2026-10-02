// ============================================================
// widgets/error_banner.dart — inline error message strip
// ============================================================

import 'package:flutter/material.dart';

import '../desktop/theme/desktop_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // The theme's error hue, not Material's red — the Red theme's
    // notificationError is amber, so this banner used to contradict it.
    final error = context.appTheme.notificationError;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.12),
        border: Border.all(color: error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

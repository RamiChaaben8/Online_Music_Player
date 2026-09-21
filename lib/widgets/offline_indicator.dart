// ============================================================
// widgets/offline_indicator.dart
//
// A small banner that appears when the device has no network
// access. Uses Firestore's snapshotMetadata.fromCache to detect
// offline state — no extra connectivity package needed.
//
// Wire this into the app shell as a Positioned top banner
// (similar to RemotePlaybackBanner).
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../desktop/theme/desktop_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// True when the last known network state is offline.
/// Detected by listening to any Firestore snapshot and checking
/// metadata.isFromCache AND !metadata.hasPendingWrites.
final offlineProvider = StateProvider<bool>((ref) => false);

// ── Controller — wire this up once in the app ─────────────────────────────────

class OfflineDetector {
  StreamSubscription? _sub;

  void start(WidgetRef ref) {
    // Use the settings document (always exists once profile is written)
    // as a heartbeat to detect offline state. We listen to any document
    // that we know Firestore will keep syncing.
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('_ping') // doesn't need to exist
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      // fromCache = true AND hasPendingWrites = false → we're offline
      final isOffline =
          snap.metadata.isFromCache && !snap.metadata.hasPendingWrites;
      ref.read(offlineProvider.notifier).state = isOffline;
    }, onError: (_) {
      ref.read(offlineProvider.notifier).state = true;
    });
  }

  void stop() {
    _sub?.cancel();
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(offlineProvider);
    if (!isOffline) return const SizedBox.shrink();
    final theme = AppThemeScope.maybeOf(context);
    final warning = theme?.notificationError ?? Colors.orange;

    return Material(
      color: theme?.main.withValues(alpha: 0) ?? Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: warning, size: 16),
            SizedBox(width: 8),
            Text(
              'Offline — changes will sync when reconnected',
              style: TextStyle(color: warning, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

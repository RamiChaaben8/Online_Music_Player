// ============================================================
// services/app_constants.dart
//
// Single source of truth for app-wide constants.
// Edit GITHUB_OWNER and GITHUB_REPO here when you fork or
// rename the repository — nowhere else needs to change.
// ============================================================

class AppConstants {
  AppConstants._();

  // ── GitHub Release config ─────────────────────────────────────────────────
  static const String githubOwner = 'RamiChaaben8';
  static const String githubRepo  = 'Online_Music_Player';

  /// Full GitHub Releases API URL — derived, never needs editing.
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// URL to the GitHub releases page (used as fallback for unsupported platforms).
  static const String githubReleasesPageUrl =
      'https://github.com/$githubOwner/$githubRepo/releases/latest';

  // ── Asset name patterns (must match what release.yml uploads) ─────────────
  // GitHub Actions packages the Windows build as this filename.
  static const String windowsAssetName = 'utify-windows.zip';

  // TODO(macOS): update this when macOS build is added to release.yml
  static const String macosAssetName = 'utify-macos.zip';

  // TODO(Linux): update this when Linux build is added to release.yml
  static const String linuxAssetName = 'utify-linux.tar.gz';
}

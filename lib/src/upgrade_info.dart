import 'dart:io' show Platform;

/// How "different" the latest store version is from the local one.
///
/// Drives whether [EasyUpgrade] forces, prompts, or stays silent.
enum UpgradeSeverity {
  /// No upgrade available (or version comparison failed).
  none,

  /// Patch-level diff (e.g. `1.2.3 → 1.2.4`). Silent — no prompt is shown.
  patch,

  /// Minor-level diff (e.g. `1.2.3 → 1.3.0`). Optional prompt is shown.
  minor,

  /// Major-level diff (e.g. `1.2.3 → 2.0.0`). Forced — user must upgrade.
  major,
}

/// Snapshot of the result of an upgrade check.
///
/// Passed to every hook on [EasyUpgrade] so callbacks can inspect what was
/// found and decide what to do.
class UpgradeInfo {
  /// Local app version, as reported by `package_info_plus` (e.g. `'1.2.3'`).
  final String currentVersion;

  /// Store version. `null` on Android (Play Core doesn't expose the new
  /// semver string — only [androidUpdatePriority] and
  /// [androidAvailableVersionCode]).
  final String? latestVersion;

  /// Severity of the diff. See [UpgradeSeverity].
  final UpgradeSeverity severity;

  /// Direct App Store URL on iOS (the `trackViewUrl` from iTunes Search).
  /// `null` on Android.
  final String? appStoreUrl;

  /// Release notes for [latestVersion] on iOS. `null` on Android.
  final String? releaseNotes;

  /// One of `'ios'`, `'android'`, or another OS name (in which case
  /// [severity] is always [UpgradeSeverity.none]).
  final String platform;

  /// Play Console `inAppUpdatePriority` (0–5) reported by Play Core.
  /// `null` on iOS.
  final int? androidUpdatePriority;

  /// `versionCode` of the update available on Play Store. `null` on iOS.
  final int? androidAvailableVersionCode;

  /// Creates an [UpgradeInfo]. Used internally; you typically receive these
  /// from [EasyUpgrade] hooks rather than constructing them yourself.
  const UpgradeInfo({
    required this.currentVersion,
    required this.severity,
    required this.platform,
    this.latestVersion,
    this.appStoreUrl,
    this.releaseNotes,
    this.androidUpdatePriority,
    this.androidAvailableVersionCode,
  });

  /// Convenience constructor for "no upgrade available."
  factory UpgradeInfo.none({required String currentVersion}) => UpgradeInfo(
        currentVersion: currentVersion,
        severity: UpgradeSeverity.none,
        platform: Platform.operatingSystem,
      );

  /// Serialise to a `Map` suitable for analytics payloads.
  Map<String, dynamic> toMap() => {
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'severity': severity.name,
        'appStoreUrl': appStoreUrl,
        'releaseNotes': releaseNotes,
        'platform': platform,
        'androidUpdatePriority': androidUpdatePriority,
        'androidAvailableVersionCode': androidAvailableVersionCode,
      };

  @override
  String toString() => 'UpgradeInfo(${toMap()})';
}

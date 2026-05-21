import 'dart:io' show Platform;

enum UpgradeSeverity { none, patch, minor, major }

class UpgradeInfo {
  final String currentVersion;
  final String? latestVersion;
  final UpgradeSeverity severity;
  final String? appStoreUrl;
  final String? releaseNotes;
  final String platform;
  final int? androidUpdatePriority;
  final int? androidAvailableVersionCode;

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

  factory UpgradeInfo.none({required String currentVersion}) => UpgradeInfo(
        currentVersion: currentVersion,
        severity: UpgradeSeverity.none,
        platform: Platform.operatingSystem,
      );

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

// Internal — not exported from `package:easy_upgrade/easy_upgrade.dart`.
// ignore_for_file: public_member_api_docs

import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import 'android_update_manager.dart';
import 'ios_store_lookup.dart';
import 'semver.dart';
import 'upgrade_info.dart';

class UpgradeChecker {
  final String appStoreRegion;
  final String? bundleIdOverride;
  final int androidImmediatePriority;
  final int androidFlexiblePriority;

  const UpgradeChecker({
    this.appStoreRegion = 'US',
    this.bundleIdOverride,
    this.androidImmediatePriority = 4,
    this.androidFlexiblePriority = 1,
  });

  Future<UpgradeInfo> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    if (Platform.isIOS) {
      return _checkIos(currentVersion, packageInfo.packageName);
    }
    if (Platform.isAndroid) {
      return _checkAndroid(currentVersion);
    }
    return UpgradeInfo.none(currentVersion: currentVersion);
  }

  Future<UpgradeInfo> _checkIos(String currentVersion, String packageId) async {
    final current = SemVer.tryParse(currentVersion);
    if (current == null) {
      return UpgradeInfo.none(currentVersion: currentVersion);
    }
    final bundleId = bundleIdOverride ?? packageId;
    final lookup = await IosStoreLookup.lookup(
      bundleId: bundleId,
      regionCode: appStoreRegion,
    );
    if (lookup == null) return UpgradeInfo.none(currentVersion: currentVersion);
    final latest = SemVer.tryParse(lookup.version);
    if (latest == null) {
      return UpgradeInfo.none(currentVersion: currentVersion);
    }
    final severity = current.severityAgainst(latest);
    return UpgradeInfo(
      currentVersion: currentVersion,
      latestVersion: lookup.version,
      severity: severity,
      appStoreUrl: lookup.trackViewUrl,
      releaseNotes: lookup.releaseNotes,
      platform: 'ios',
    );
  }

  Future<UpgradeInfo> _checkAndroid(String currentVersion) async {
    final info = await AndroidUpdateManager.checkForUpdate();
    if (info == null || !info.updateAvailable) {
      return UpgradeInfo.none(currentVersion: currentVersion);
    }
    UpgradeSeverity severity;
    if (info.immediateAllowed &&
        info.updatePriority >= androidImmediatePriority) {
      severity = UpgradeSeverity.major;
    } else if (info.flexibleAllowed &&
        info.updatePriority >= androidFlexiblePriority) {
      severity = UpgradeSeverity.minor;
    } else {
      severity = UpgradeSeverity.none;
    }
    return UpgradeInfo(
      currentVersion: currentVersion,
      severity: severity,
      platform: 'android',
      androidUpdatePriority: info.updatePriority,
      androidAvailableVersionCode: info.availableVersionCode,
    );
  }
}

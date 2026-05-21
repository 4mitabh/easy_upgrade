// Internal — not exported from `package:easy_upgrade/easy_upgrade.dart`.
// ignore_for_file: public_member_api_docs

import 'upgrade_info.dart';

class SemVer {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, this.minor, this.patch);

  static SemVer? tryParse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final clean = trimmed.split(RegExp(r'[-+]')).first;
    final parts = clean.split('.');
    if (parts.length < 2) return null;
    try {
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = parts.length >= 3 ? int.parse(parts[2]) : 0;
      if (major < 0 || minor < 0 || patch < 0) return null;
      return SemVer(major, minor, patch);
    } catch (_) {
      return null;
    }
  }

  UpgradeSeverity severityAgainst(SemVer latest) {
    if (latest.major > major) return UpgradeSeverity.major;
    if (latest.major < major) return UpgradeSeverity.none;
    if (latest.minor > minor) return UpgradeSeverity.minor;
    if (latest.minor < minor) return UpgradeSeverity.none;
    if (latest.patch > patch) return UpgradeSeverity.patch;
    return UpgradeSeverity.none;
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is SemVer &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

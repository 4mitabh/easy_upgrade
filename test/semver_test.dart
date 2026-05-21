import 'package:easy_upgrade/easy_upgrade.dart';
import 'package:easy_upgrade/src/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemVer.tryParse', () {
    test('parses major.minor.patch', () {
      final v = SemVer.tryParse('1.2.3');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('parses major.minor (patch defaults to 0)', () {
      expect(SemVer.tryParse('1.2'), const SemVer(1, 2, 0));
    });

    test('strips pre-release tag', () {
      expect(SemVer.tryParse('1.2.3-beta.1'), const SemVer(1, 2, 3));
    });

    test('strips build metadata', () {
      expect(SemVer.tryParse('1.2.3+build.42'), const SemVer(1, 2, 3));
    });

    test('rejects single component', () {
      expect(SemVer.tryParse('1'), isNull);
    });

    test('rejects empty / null / garbage', () {
      expect(SemVer.tryParse(''), isNull);
      expect(SemVer.tryParse(null), isNull);
      expect(SemVer.tryParse('not.a.version'), isNull);
      expect(SemVer.tryParse('1.x.3'), isNull);
    });

    test('rejects negative components', () {
      expect(SemVer.tryParse('-1.2.3'), isNull);
    });
  });

  group('SemVer.severityAgainst', () {
    test('patch bump → patch', () {
      expect(const SemVer(1, 2, 3).severityAgainst(const SemVer(1, 2, 4)),
          UpgradeSeverity.patch);
    });

    test('minor bump → minor (regardless of patch)', () {
      expect(const SemVer(1, 2, 3).severityAgainst(const SemVer(1, 3, 0)),
          UpgradeSeverity.minor);
      expect(const SemVer(1, 2, 9).severityAgainst(const SemVer(1, 3, 0)),
          UpgradeSeverity.minor);
    });

    test('major bump → major', () {
      expect(const SemVer(1, 9, 9).severityAgainst(const SemVer(2, 0, 0)),
          UpgradeSeverity.major);
    });

    test('same version → none', () {
      expect(const SemVer(1, 2, 3).severityAgainst(const SemVer(1, 2, 3)),
          UpgradeSeverity.none);
    });

    test('older latest → none (no false downgrade)', () {
      expect(const SemVer(2, 0, 0).severityAgainst(const SemVer(1, 9, 9)),
          UpgradeSeverity.none);
      expect(const SemVer(1, 2, 3).severityAgainst(const SemVer(1, 2, 2)),
          UpgradeSeverity.none);
    });
  });
}

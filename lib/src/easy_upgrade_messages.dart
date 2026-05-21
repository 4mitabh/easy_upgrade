/// User-facing strings for the iOS upgrade dialog.
///
/// Defaults are English. Override individual fields (or pass a fully
/// localised instance) to translate.
class EasyUpgradeMessages {
  /// Dialog title.
  final String title;

  /// Body text shown for optional (minor) upgrades.
  final String bodyMinor;

  /// Body text shown for forced (major) upgrades.
  final String bodyMajor;

  /// Label of the "accept the upgrade" button.
  final String updateButton;

  /// Label of the "dismiss for now" button. Hidden on forced upgrades.
  final String laterButton;

  /// Heading shown above the release notes block (when iTunes returned any).
  final String releaseNotesLabel;

  /// Creates a set of dialog strings. Every field has a sensible English
  /// default; pass only the ones you want to override.
  const EasyUpgradeMessages({
    this.title = 'Update Available',
    this.bodyMinor =
        'A new version of the app is available. Would you like to update?',
    this.bodyMajor =
        'A required update is available. You must update to continue using the app.',
    this.updateButton = 'Update',
    this.laterButton = 'Later',
    this.releaseNotesLabel = "What's new",
  });
}

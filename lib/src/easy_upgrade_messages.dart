class EasyUpgradeMessages {
  final String title;
  final String bodyMinor;
  final String bodyMajor;
  final String updateButton;
  final String laterButton;
  final String releaseNotesLabel;

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

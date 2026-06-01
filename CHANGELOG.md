## 0.1.1

* Documentation: rewritten README  and examples.
* Updated package description. No functional or API changes from 0.1.0.

## 0.1.0

* Initial release.
* iOS: App Store version lookup via iTunes Search API. Major-version bump forces an upgrade dialog, minor prompts, patch is silent.
* Android: in-app updates via Play Core. `updatePriority >= 4` triggers an immediate (blocking) flow, `>= 1` a flexible (background) flow.
* Auto-detects Material vs Cupertino for the iOS dialog; fully overridable via `dialogBuilder`.
* Hooks: `onCheck`, `shouldPromptOptional` (persistence gate for minor upgrades), `onPromptShown`, `onUpgradeFlowStarted`, `onUpdateAccepted`, `onError`.
* `EasyUpgrade.checkNow()` for manually-triggered checks.
* Android resume handling for interrupted immediate updates.

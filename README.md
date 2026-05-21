# easy_upgrade

An opinionated, drop-in upgrade prompter for Flutter apps.

- **Major** version bump → force an upgrade.
- **Minor** version bump → prompt the user.
- **Patch** version bump → silent.

Works out of the box. Supports iOS App Store version lookup and Android in-app updates via Play Core.

## Install

```yaml
dependencies:
  easy_upgrade: ^0.1.0
```

## Quickstart

```dart
import 'package:easy_upgrade/easy_upgrade.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EasyUpgrade(
        child: const HomePage(),
      ),
    );
  }
}
```

That's it. On first frame (after a 1-second delay), the plugin checks the appropriate store and shows a prompt if needed.

## How it decides

| Platform | Source of truth | Major (force) | Minor (prompt) | Patch (silent) |
| --- | --- | --- | --- | --- |
| iOS | iTunes Search API `version`, parsed as semver | Different major component | Different minor component | Different patch component |
| Android | Play Core `updatePriority` (set in Play Console at release time) | `priority ≥ 4` | `priority ≥ 1` | `priority == 0` |

Android relies on Play Console priority because Play Core does not expose the new app's semver string — only its `versionCode` and the priority you configure. Priority is also Google's recommended signal.

### No custom dialog on Android

Play Core renders its own UI for both flows:

- **Immediate**: full-screen Google-branded blocking update screen.
- **Flexible**: silent background download; we call `completeUpdate()` when the download finishes, which triggers Play's native restart prompt.

The auto-detected Material/Cupertino dialog is only used on iOS.

## Customization

```dart
EasyUpgrade(
  appStoreRegion: 'GB',                     // default: 'US'
  bundleIdOverride: 'com.example.prod',     // useful when staging build's bundle id != store bundle id
  androidImmediatePriority: 5,              // default: 4
  androidFlexiblePriority: 2,               // default: 1
  initialDelay: const Duration(seconds: 2), // default: 1 second
  enabledInDebug: false,                    // default: false (skip in debug builds)
  messages: const EasyUpgradeMessages(
    title: 'Time to update',
    bodyMinor: 'A newer version of the app is available.',
    bodyMajor: 'You must update to keep using the app.',
    updateButton: 'Update',
    laterButton: 'Later',
  ),
  // Persistence gate — only consulted for minor (optional) upgrades.
  shouldPromptOptional: (info) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString('easy_upgrade_dismissed');
    return dismissed != info.latestVersion;
  },
  onCheck: (info) => print('check: ${info.severity}'),
  onPromptShown: (info) => analytics.log('upgrade_shown'),
  onUpdateTapped: (info) => analytics.log('upgrade_accepted'),
  onError: (e, st) => crashlytics.recordError(e, st),
  child: const HomePage(),
)
```

## Manual check

```dart
final info = await EasyUpgrade.checkNow();
```

Returns `null` if no `EasyUpgrade` widget is currently mounted, otherwise the `UpgradeInfo` from the check. All hooks still fire.

## Fully custom dialog (iOS)

```dart
EasyUpgrade(
  dialogBuilder: (context, info, force, onUpdate, onLater) {
    return AlertDialog(
      title: const Text('Custom UI'),
      content: Text('Update to ${info.latestVersion}'),
      actions: [
        if (onLater != null) TextButton(onPressed: onLater, child: const Text('Later')),
        FilledButton(onPressed: onUpdate, child: const Text('Update')),
      ],
    );
  },
  child: const HomePage(),
)
```

## Android setup

- **`minSdkVersion 21`** is required (Play Core requirement).
- Play Core `app-update` is pulled in transitively — no extra setup needed.
- When releasing in Play Console, set your **in-app update priority** (0–5). The default mapping (`4+` immediate, `1+` flexible, `0` silent) is configurable.

## iOS setup

- No native setup. `iTunes Search API` is public.
- Set `appStoreRegion` if your app's primary store is outside the US.
- Set `bundleIdOverride` if your debug/staging bundle id differs from your store listing.

## Limitations

- No built-in persistence — provide your own via `shouldPromptOptional` (wire `shared_preferences` or anything else).
- No built-in localization — provide your own strings via `EasyUpgradeMessages`.
- No Appcast / custom feed support.
- macOS, Windows, Linux, and Web are unsupported and return `severity = none`.

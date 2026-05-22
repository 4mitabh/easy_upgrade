# easy_upgrade

A drop-in upgrade prompter for Flutter apps. Zero configuration — just wrap your app and it works.

- **Major** bump → force the upgrade.
- **Minor** bump → prompt the user.
- **Patch** bump → silent.

Talks to the iOS App Store via the iTunes Search API and uses Android Play Core for in-app updates. The iOS prompt auto-adapts to Material or Cupertino based on your app.

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

That's it. One second after the first frame, the plugin checks the store and shows a prompt if an upgrade is available.

## How it decides

| Platform | Source of truth | Major (force) | Minor (prompt) | Patch (silent) |
| --- | --- | --- | --- | --- |
| iOS | iTunes Search API `version`, parsed as semver | Different major component | Different minor component | Different patch component |
| Android | Play Core `updatePriority` (set in Play Console at release time) | `priority ≥ 4` | `priority ≥ 1` | `priority == 0` |

Android relies on Play Console priority because Play Core does not expose the new app's semver string — only its `versionCode` and the priority you configure. Priority is also Google's recommended signal.

## What the user sees

- **iOS** — an auto-detected Material or Cupertino dialog (or your own widget, via `dialogBuilder`).
- **Android, immediate** — Play Core's full-screen, Google-branded blocking update screen.
- **Android, flexible** — silent background download; when it finishes, Play's native restart prompt appears.

Android UI is owned by Play Core by design — Google requires their UI for in-app updates, so there is no custom-dialog escape hatch on Android.

## Customization

All parameters are optional. The defaults are tuned for the common case.

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
  onUpgradeFlowStarted: (info) => analytics.log('upgrade_flow_started'),
  onUpdateAccepted: (info) => analytics.log('upgrade_accepted'),
  onError: (e, st) => crashlytics.recordError(e, st),
  child: const HomePage(),
)
```

## Manual check

```dart
final info = await EasyUpgrade.checkNow();
```

Returns `null` if no `EasyUpgrade` widget is currently mounted, otherwise the `UpgradeInfo` from the check. All hooks still fire.

## Override the iOS dialog

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

### Automating `inAppUpdatePriority` with Fastlane (optional)

Skip this section if you're happy setting priority by hand in Play Console. If you ship from CI, this is how you keep the major/minor/patch contract honest without thinking about it.

The Android path works by telling Play Console *how* to nag users at release time. Fastlane can diff your local version against what's currently live and set the priority for you — so a major bump auto-forces, a minor bump auto-prompts, and a patch ships silently.

Fastlane's `upload_to_play_store` (a.k.a. `supply`) accepts an `in_app_update_priority:` parameter. Combine it with `google_play_track_release_names` to read the current production version. A minimal `Fastfile`:

```ruby
default_platform(:android)

PACKAGE_NAME = "com.example.app"

# Map semver delta -> Play Console priority that matches easy_upgrade's defaults:
#   major bump  -> 5  (priority >= androidImmediatePriority=4 -> IMMEDIATE flow)
#   minor bump  -> 2  (priority >= androidFlexiblePriority=1  -> FLEXIBLE  flow)
#   patch / no change -> 0 (silent)
def priority_for(local, store)
  return 0 if store.nil? || store.empty?
  l_maj, l_min, _ = local.split(/[-+]/).first.split(".").map(&:to_i)
  s_maj, s_min, _ = store.split(/[-+]/).first.split(".").map(&:to_i)
  return 5 if l_maj > s_maj
  return 2 if l_maj == s_maj && l_min > s_min
  0
end

platform :android do
  desc "Build + upload to Play Store with auto-computed in-app update priority"
  lane :deploy do
    # 1. Read the version we're about to ship from pubspec.yaml
    pubspec     = File.read("../pubspec.yaml")
    local_full  = pubspec.match(/^version:\s*(.+)/)[1].strip   # e.g. "1.3.0+42"
    local_semver = local_full.split("+").first                 # -> "1.3.0"

    # 2. Read what's currently live on the production track
    store_names = google_play_track_release_names(
      package_name: PACKAGE_NAME,
      track: "production",
    )
    store_semver = store_names&.first&.split(/\s|-/)&.first    # release names are usually the version string

    priority = priority_for(local_semver, store_semver)
    UI.message("local=#{local_semver}  store=#{store_semver}  -> in_app_update_priority=#{priority}")

    # 3. Build the AAB
    sh("cd .. && flutter build appbundle --release")

    # 4. Upload with the computed priority
    upload_to_play_store(
      package_name: PACKAGE_NAME,
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      track: "production",
      in_app_update_priority: priority,
      release_status: "completed",
    )
  end
end
```

Prerequisites:

- A Google Play service-account JSON key with the *Release manager* role; point Fastlane at it via `json_key_file:` (or the `SUPPLY_JSON_KEY` env var) in an `Appfile` or directly on the action.
- The release name in Play Console must contain the semver (the default Play Console "Release name" is the version string, so this works out of the box). If your release names are freeform, pull the version from `pubspec.yaml` on both sides instead — keep `local_semver` as the source of truth and only call `google_play_track_release_names` to detect "no previous release."
- `in_app_update_priority` is **per-release**, not per-app. Setting it once doesn't affect older releases.

How this lines up with the plugin defaults:

| Local vs. store | Fastlane sets | easy_upgrade behavior on user device |
| --- | --- | --- |
| Major bump (e.g. `1.x.x` → `2.0.0`) | priority `5` | Immediate (blocking) Play Core flow |
| Minor bump (`1.2.x` → `1.3.0`) | priority `2` | Flexible (background) Play Core flow |
| Patch only / no change | priority `0` | No prompt |

If you change `androidImmediatePriority` / `androidFlexiblePriority` in your widget, update the numbers `priority_for` returns to match.

## iOS setup

- No native setup. `iTunes Search API` is public.
- Set `appStoreRegion` if your app's primary store is outside the US.
- Set `bundleIdOverride` if your debug/staging bundle id differs from your store listing.

## Hooks

| Hook | Fires when |
| --- | --- |
| `onCheck` | After every check, including no-upgrade-available |
| `shouldPromptOptional` | Before showing a *minor* prompt — return `false` to skip |
| `onPromptShown` | Immediately before the iOS dialog or Play Core flow |
| `onUpgradeFlowStarted` | iOS: user tapped "Update". Android: Play Core's UI launched |
| `onUpdateAccepted` | iOS: `launchUrl` returned `true`. Android: Play Core returned `RESULT_OK` |
| `onError` | Any failure (network, channel, hook execution) |

## Limitations

- No built-in persistence — provide your own via `shouldPromptOptional` (wire `shared_preferences` or anything else).
- No built-in localization — provide your own strings via `EasyUpgradeMessages`.
- No Appcast / custom feed support.
- macOS, Windows, Linux, and Web are unsupported and return `severity = none`.
- `EasyUpgrade.checkNow()` uses the most-recently-mounted `EasyUpgrade` widget. If you nest multiple, only the inner one is reachable via `checkNow()`.

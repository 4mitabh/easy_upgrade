import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'android_update_manager.dart';
import 'easy_upgrade_messages.dart';
import 'upgrade_checker.dart';
import 'upgrade_dialog.dart';
import 'upgrade_info.dart';

/// Gate consulted before showing an optional (minor) upgrade prompt.
///
/// Return `false` to skip the prompt for this check. Use this hook to wire
/// `shared_preferences` (or any other persistence) so a user who already
/// dismissed a given version isn't nagged on every cold start.
///
/// Not consulted for [UpgradeSeverity.major] — those upgrades are always
/// surfaced.
typedef ShouldPromptOptional = FutureOr<bool> Function(UpgradeInfo info);

/// Signature for [EasyUpgrade] event hooks.
typedef UpgradeInfoCallback = void Function(UpgradeInfo info);

/// Custom-dialog builder for iOS (Android always uses Play Core's native UI).
///
/// [force] is `true` for major upgrades. When `force` is `true`, [onLater] is
/// `null` and your dialog must not be dismissible.
typedef UpgradeDialogBuilder = Widget Function(
  BuildContext context,
  UpgradeInfo info,
  bool force,
  VoidCallback onUpdate,
  VoidCallback? onLater,
);

/// Drop-in upgrade prompter.
///
/// Place anywhere below `MaterialApp` / `CupertinoApp`. On the first frame
/// (after [initialDelay]) it queries the appropriate store and:
///
/// - shows a forced dialog (iOS) / Play Core immediate flow (Android) on
///   [UpgradeSeverity.major];
/// - shows an optional dialog (iOS) / Play Core flexible flow (Android) on
///   [UpgradeSeverity.minor];
/// - does nothing on [UpgradeSeverity.patch] / [UpgradeSeverity.none].
///
/// All knobs are optional — the defaults work out of the box.
class EasyUpgrade extends StatefulWidget {
  /// Widget tree this guards. Always rendered; the prompt is layered on top.
  final Widget child;

  /// iTunes Search API region (ISO 3166 alpha-2). Defaults to `'US'`. If the
  /// region returns no results, falls back to `'US'` automatically.
  final String appStoreRegion;

  /// Override the bundle id used for the iOS store lookup. Useful for
  /// staging/dev builds whose runtime bundle id differs from the App Store
  /// listing (e.g. `com.foo.app.staging` vs `com.foo.app`).
  final String? bundleIdOverride;

  /// Play Console `inAppUpdatePriority` threshold (0–5) at which we trigger
  /// the **immediate** (blocking) Play Core flow. Default `4`.
  final int androidImmediatePriority;

  /// Play Console `inAppUpdatePriority` threshold (0–5) at which we trigger
  /// the **flexible** (background) Play Core flow. Default `1`.
  final int androidFlexiblePriority;

  /// User-facing strings for the iOS dialog.
  final EasyUpgradeMessages messages;

  /// Optional full override of the iOS dialog. Ignored on Android (Play Core
  /// renders its own UI).
  final UpgradeDialogBuilder? dialogBuilder;

  /// Delay between mount and the first store check. Default 1 second to let
  /// the app paint first.
  final Duration initialDelay;

  /// Master kill switch. When `false`, no check is performed.
  final bool enabled;

  /// Whether to run in debug builds. Default `false` so devs aren't nagged
  /// during `flutter run`.
  final bool enabledInDebug;

  /// Gate for minor upgrades — return `false` to skip the prompt. See
  /// [ShouldPromptOptional]. Not consulted for major upgrades.
  final ShouldPromptOptional? shouldPromptOptional;

  /// Fires after every successful check, including those that produced no
  /// upgrade. Good for analytics.
  final UpgradeInfoCallback? onCheck;

  /// Fires immediately before the iOS dialog appears or Play Core's flow is
  /// kicked off.
  final UpgradeInfoCallback? onPromptShown;

  /// Fires when the upgrade flow has been **initiated**:
  /// - iOS: user tapped "Update" in the dialog (before `launchUrl`).
  /// - Android: Play Core's UI launched successfully (the user has not yet
  ///   accepted in Play's dialog; see [onUpdateAccepted] for that).
  final UpgradeInfoCallback? onUpgradeFlowStarted;

  /// Fires when the user has **accepted** the upgrade:
  /// - iOS: `launchUrl` returned `true` (App Store opened).
  /// - Android: Play Core returned `RESULT_OK` from its update activity.
  final UpgradeInfoCallback? onUpdateAccepted;

  /// Catches any error from store lookup, channel call, or hook execution.
  /// All errors are otherwise silent.
  final void Function(Object error, StackTrace stack)? onError;

  /// Creates an [EasyUpgrade]. The only required argument is [child].
  const EasyUpgrade({
    super.key,
    required this.child,
    this.appStoreRegion = 'US',
    this.bundleIdOverride,
    this.androidImmediatePriority = 4,
    this.androidFlexiblePriority = 1,
    this.messages = const EasyUpgradeMessages(),
    this.dialogBuilder,
    this.initialDelay = const Duration(seconds: 1),
    this.enabled = true,
    this.enabledInDebug = false,
    this.shouldPromptOptional,
    this.onCheck,
    this.onPromptShown,
    this.onUpgradeFlowStarted,
    this.onUpdateAccepted,
    this.onError,
  });

  static _EasyUpgradeState? _activeInstance;

  /// Manually trigger an upgrade check.
  ///
  /// Returns `null` if no [EasyUpgrade] widget is currently mounted, otherwise
  /// the [UpgradeInfo] from the check (which may be [UpgradeSeverity.none]).
  /// All hooks fire as part of the normal flow.
  ///
  /// If multiple [EasyUpgrade] widgets are mounted, the most recently mounted
  /// one is used.
  static Future<UpgradeInfo?> checkNow() async {
    final state = _activeInstance;
    if (state == null) return null;
    return state._runCheck();
  }

  @override
  State<EasyUpgrade> createState() => _EasyUpgradeState();
}

class _EasyUpgradeState extends State<EasyUpgrade> with WidgetsBindingObserver {
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyUpgrade._activeInstance = this;
    if (!widget.enabled) return;
    if (kDebugMode && !widget.enabledInDebug) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialDelay > Duration.zero) {
        await Future<void>.delayed(widget.initialDelay);
      }
      if (!mounted) return;
      await _runCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AndroidUpdateManager.setFlexibleDownloadedListener(null);
    AndroidUpdateManager.setUpdateAcceptedListener(null);
    if (EasyUpgrade._activeInstance == this) {
      EasyUpgrade._activeInstance = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!Platform.isAndroid) return;
    if (!widget.enabled) return;
    if (kDebugMode && !widget.enabledInDebug) return;
    _resumeAndroidIfNeeded();
  }

  Future<void> _resumeAndroidIfNeeded() async {
    try {
      final info = await AndroidUpdateManager.checkForUpdate();
      if (info == null) return;
      if (info.developerTriggeredUpdateInProgress && info.immediateAllowed) {
        await AndroidUpdateManager.startImmediateUpdate();
      }
    } catch (e, st) {
      widget.onError?.call(e, st);
    }
  }

  Future<UpgradeInfo?> _runCheck() async {
    if (_inFlight) return null;
    _inFlight = true;
    try {
      final checker = UpgradeChecker(
        appStoreRegion: widget.appStoreRegion,
        bundleIdOverride: widget.bundleIdOverride,
        androidImmediatePriority: widget.androidImmediatePriority,
        androidFlexiblePriority: widget.androidFlexiblePriority,
      );
      UpgradeInfo info;
      try {
        info = await checker.check();
      } catch (e, st) {
        widget.onError?.call(e, st);
        return null;
      }
      if (!mounted) return info;
      widget.onCheck?.call(info);
      if (info.severity == UpgradeSeverity.none ||
          info.severity == UpgradeSeverity.patch) {
        return info;
      }
      if (info.severity == UpgradeSeverity.minor &&
          widget.shouldPromptOptional != null) {
        bool shouldPrompt;
        try {
          shouldPrompt = await widget.shouldPromptOptional!(info);
        } catch (e, st) {
          widget.onError?.call(e, st);
          shouldPrompt = true;
        }
        if (!shouldPrompt) return info;
      }
      if (!mounted) return info;
      widget.onPromptShown?.call(info);
      await _dispatch(info);
      return info;
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _dispatch(UpgradeInfo info) async {
    if (Platform.isIOS) {
      await _dispatchIos(info);
    } else if (Platform.isAndroid) {
      await _dispatchAndroid(info);
    }
  }

  Future<void> _dispatchIos(UpgradeInfo info) async {
    if (!mounted) return;
    final force = info.severity == UpgradeSeverity.major;

    if (widget.dialogBuilder != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: !force,
        builder: (innerCtx) => PopScope(
          canPop: !force,
          child: widget.dialogBuilder!(
            innerCtx,
            info,
            force,
            () => _onIosUpdateTapped(innerCtx, info, force),
            force ? null : () => Navigator.of(innerCtx).pop(),
          ),
        ),
      );
      return;
    }

    await showEasyUpgradeDialog(
      context: context,
      info: info,
      force: force,
      messages: widget.messages,
      onUpdate: (dialogCtx) => _onIosUpdateTapped(dialogCtx, info, force),
      onLater: force ? null : () {},
    );
  }

  Future<void> _onIosUpdateTapped(
    BuildContext dialogCtx,
    UpgradeInfo info,
    bool force,
  ) async {
    widget.onUpgradeFlowStarted?.call(info);
    final url = info.appStoreUrl;
    if (url == null) {
      if (dialogCtx.mounted && Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
      }
      return;
    }
    bool launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      widget.onError?.call(e, st);
    }
    if (launched) {
      widget.onUpdateAccepted?.call(info);
      if (!force && dialogCtx.mounted && Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
      }
    }
  }

  Future<void> _dispatchAndroid(UpgradeInfo info) async {
    try {
      AndroidUpdateManager.setUpdateAcceptedListener(() {
        widget.onUpdateAccepted?.call(info);
      });
      if (info.severity == UpgradeSeverity.major) {
        final ok = await AndroidUpdateManager.startImmediateUpdate();
        if (ok) widget.onUpgradeFlowStarted?.call(info);
      } else if (info.severity == UpgradeSeverity.minor) {
        AndroidUpdateManager.setFlexibleDownloadedListener(() async {
          try {
            await AndroidUpdateManager.completeFlexibleUpdate();
          } catch (e, st) {
            widget.onError?.call(e, st);
          }
        });
        final ok = await AndroidUpdateManager.startFlexibleUpdate();
        if (ok) widget.onUpgradeFlowStarted?.call(info);
      }
    } catch (e, st) {
      widget.onError?.call(e, st);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

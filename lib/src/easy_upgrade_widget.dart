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

typedef ShouldPromptOptional = FutureOr<bool> Function(UpgradeInfo info);
typedef UpgradeInfoCallback = void Function(UpgradeInfo info);
typedef UpgradeDialogBuilder = Widget Function(
  BuildContext context,
  UpgradeInfo info,
  bool force,
  VoidCallback onUpdate,
  VoidCallback? onLater,
);

class EasyUpgrade extends StatefulWidget {
  final Widget child;
  final String appStoreRegion;
  final String? bundleIdOverride;
  final int androidImmediatePriority;
  final int androidFlexiblePriority;
  final EasyUpgradeMessages messages;
  final UpgradeDialogBuilder? dialogBuilder;
  final Duration initialDelay;
  final bool enabled;
  final bool enabledInDebug;

  final ShouldPromptOptional? shouldPromptOptional;
  final UpgradeInfoCallback? onCheck;
  final UpgradeInfoCallback? onPromptShown;
  final UpgradeInfoCallback? onUpdateTapped;
  final void Function(Object error, StackTrace stack)? onError;

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
    this.onUpdateTapped,
    this.onError,
  });

  static _EasyUpgradeState? _activeInstance;

  /// Manually trigger an upgrade check. Returns `null` if no [EasyUpgrade]
  /// widget is currently mounted. All hooks (`onCheck`, `shouldPromptOptional`,
  /// `onPromptShown`, `onUpdateTapped`) still fire as part of the normal flow.
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
    widget.onUpdateTapped?.call(info);
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
    if (launched && !force && dialogCtx.mounted) {
      if (Navigator.of(dialogCtx).canPop()) {
        Navigator.of(dialogCtx).pop();
      }
    }
  }

  Future<void> _dispatchAndroid(UpgradeInfo info) async {
    try {
      if (info.severity == UpgradeSeverity.major) {
        final ok = await AndroidUpdateManager.startImmediateUpdate();
        if (ok) widget.onUpdateTapped?.call(info);
      } else if (info.severity == UpgradeSeverity.minor) {
        AndroidUpdateManager.setFlexibleDownloadedListener(() async {
          try {
            await AndroidUpdateManager.completeFlexibleUpdate();
          } catch (e, st) {
            widget.onError?.call(e, st);
          }
        });
        final ok = await AndroidUpdateManager.startFlexibleUpdate();
        if (ok) widget.onUpdateTapped?.call(info);
      }
    } catch (e, st) {
      widget.onError?.call(e, st);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

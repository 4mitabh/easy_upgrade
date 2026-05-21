// Internal — not exported from `package:easy_upgrade/easy_upgrade.dart`.
// ignore_for_file: public_member_api_docs

import 'package:flutter/services.dart';

class AndroidUpdateInfo {
  final bool updateAvailable;
  final int updatePriority;
  final bool immediateAllowed;
  final bool flexibleAllowed;
  final int? availableVersionCode;
  final bool developerTriggeredUpdateInProgress;

  const AndroidUpdateInfo({
    required this.updateAvailable,
    required this.updatePriority,
    required this.immediateAllowed,
    required this.flexibleAllowed,
    required this.developerTriggeredUpdateInProgress,
    this.availableVersionCode,
  });

  factory AndroidUpdateInfo.fromMap(Map<dynamic, dynamic> m) =>
      AndroidUpdateInfo(
        updateAvailable: m['updateAvailable'] == true,
        updatePriority: (m['updatePriority'] as num?)?.toInt() ?? 0,
        immediateAllowed: m['immediateAllowed'] == true,
        flexibleAllowed: m['flexibleAllowed'] == true,
        availableVersionCode: (m['availableVersionCode'] as num?)?.toInt(),
        developerTriggeredUpdateInProgress:
            m['developerTriggeredUpdateInProgress'] == true,
      );
}

typedef AndroidFlexibleDownloadedCallback = void Function();
typedef AndroidUpdateAcceptedCallback = void Function();

// Android Activity.RESULT_OK == -1
const int _androidResultOk = -1;

class AndroidUpdateManager {
  static const MethodChannel _channel =
      MethodChannel('com.mysthetic.easyupgrade');

  static AndroidFlexibleDownloadedCallback? _onFlexibleDownloaded;
  static AndroidUpdateAcceptedCallback? _onUpdateAccepted;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFlexibleDownloaded':
          _onFlexibleDownloaded?.call();
          break;
        case 'onUpdateActivityResult':
          final args = call.arguments;
          if (args is Map && args['resultCode'] == _androidResultOk) {
            _onUpdateAccepted?.call();
          }
          break;
      }
      return null;
    });
  }

  static void setFlexibleDownloadedListener(
      AndroidFlexibleDownloadedCallback? cb) {
    _ensureHandler();
    _onFlexibleDownloaded = cb;
  }

  static void setUpdateAcceptedListener(AndroidUpdateAcceptedCallback? cb) {
    _ensureHandler();
    _onUpdateAccepted = cb;
  }

  static Future<AndroidUpdateInfo?> checkForUpdate() async {
    _ensureHandler();
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('checkForUpdate');
    if (result == null) return null;
    return AndroidUpdateInfo.fromMap(result);
  }

  static Future<bool> startImmediateUpdate() async {
    _ensureHandler();
    final ok = await _channel.invokeMethod<bool>('startImmediateUpdate');
    return ok ?? false;
  }

  static Future<bool> startFlexibleUpdate() async {
    _ensureHandler();
    final ok = await _channel.invokeMethod<bool>('startFlexibleUpdate');
    return ok ?? false;
  }

  static Future<bool> completeFlexibleUpdate() async {
    _ensureHandler();
    final ok = await _channel.invokeMethod<bool>('completeFlexibleUpdate');
    return ok ?? false;
  }
}

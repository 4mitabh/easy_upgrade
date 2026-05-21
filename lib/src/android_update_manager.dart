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

class AndroidUpdateManager {
  static const MethodChannel _channel =
      MethodChannel('dev.easyupgrade/easy_upgrade');

  static AndroidFlexibleDownloadedCallback? _onFlexibleDownloaded;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFlexibleDownloaded') {
        _onFlexibleDownloaded?.call();
      }
      return null;
    });
  }

  static void setFlexibleDownloadedListener(
      AndroidFlexibleDownloadedCallback? cb) {
    _ensureHandler();
    _onFlexibleDownloaded = cb;
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

package com.mysthetic.easyupgrade

import android.app.Activity
import android.content.Intent
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

class EasyUpgradePlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    ActivityResultListener {

    private companion object {
        const val CHANNEL_NAME = "com.mysthetic.easyupgrade"
        const val IMMEDIATE_REQUEST_CODE = 0x6E11
        const val FLEXIBLE_REQUEST_CODE = 0x6E12
    }

    private lateinit var channel: MethodChannel
    private lateinit var appUpdateManager: AppUpdateManager
    private var activity: Activity? = null
    private var cachedInfo: AppUpdateInfo? = null
    private var flexibleListener: InstallStateUpdatedListener? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        appUpdateManager = AppUpdateManagerFactory.create(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        unregisterFlexibleListener()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkForUpdate" -> checkForUpdate(result)
            "startImmediateUpdate" -> startUpdate(result, AppUpdateType.IMMEDIATE)
            "startFlexibleUpdate" -> startUpdate(result, AppUpdateType.FLEXIBLE)
            "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
            else -> result.notImplemented()
        }
    }

    private fun checkForUpdate(result: Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                cachedInfo = info
                val map = HashMap<String, Any?>()
                map["updateAvailable"] =
                    info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                map["updatePriority"] = info.updatePriority()
                map["immediateAllowed"] = info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                map["flexibleAllowed"] = info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
                map["availableVersionCode"] = info.availableVersionCode()
                map["developerTriggeredUpdateInProgress"] =
                    info.updateAvailability() ==
                        UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                result.success(map)
            }
            .addOnFailureListener { e ->
                result.error("CHECK_FAILED", e.message, null)
            }
    }

    private fun startUpdate(result: Result, type: Int) {
        val info = cachedInfo
        val act = activity
        if (info == null) {
            result.error("NO_INFO", "Call checkForUpdate first.", null)
            return
        }
        if (act == null) {
            result.error("NO_ACTIVITY", "Plugin not attached to an activity.", null)
            return
        }
        if (!info.isUpdateTypeAllowed(type)) {
            result.error("UPDATE_TYPE_NOT_ALLOWED",
                "AppUpdateType $type not allowed for this update.", null)
            return
        }
        try {
            if (type == AppUpdateType.FLEXIBLE) {
                registerFlexibleListener()
            }
            val started = appUpdateManager.startUpdateFlowForResult(
                info,
                type,
                act,
                if (type == AppUpdateType.IMMEDIATE) IMMEDIATE_REQUEST_CODE
                else FLEXIBLE_REQUEST_CODE,
            )
            result.success(started)
        } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun completeFlexibleUpdate(result: Result) {
        try {
            appUpdateManager.completeUpdate()
            result.success(true)
        } catch (e: Exception) {
            result.error("COMPLETE_FAILED", e.message, null)
        }
    }

    private fun registerFlexibleListener() {
        unregisterFlexibleListener()
        val listener = InstallStateUpdatedListener { state: InstallState ->
            if (state.installStatus() == InstallStatus.DOWNLOADED) {
                channel.invokeMethod("onFlexibleDownloaded", null)
            }
        }
        appUpdateManager.registerListener(listener)
        flexibleListener = listener
    }

    private fun unregisterFlexibleListener() {
        flexibleListener?.let { appUpdateManager.unregisterListener(it) }
        flexibleListener = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            IMMEDIATE_REQUEST_CODE, FLEXIBLE_REQUEST_CODE -> {
                channel.invokeMethod(
                    "onUpdateActivityResult",
                    mapOf("requestCode" to requestCode, "resultCode" to resultCode),
                )
                true
            }
            else -> false
        }
    }
}

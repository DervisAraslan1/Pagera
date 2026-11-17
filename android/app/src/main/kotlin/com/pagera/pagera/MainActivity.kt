package com.pagera.pagera

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = intent?.getStringExtra(InterceptService.EXTRA_PKG)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pagera/intercept").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "hasOverlay" -> result.success(Settings.canDrawOverlays(this@MainActivity))
                    "openUsageSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "start" -> {
                        @Suppress("UNCHECKED_CAST")
                        val apps = (call.arguments as? List<String>) ?: emptyList()
                        InterceptService.saveApps(this@MainActivity, apps)
                        InterceptService.setEnabled(this@MainActivity, true)
                        val i = Intent(this@MainActivity, InterceptService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(null)
                    }
                    "stop" -> {
                        InterceptService.setEnabled(this@MainActivity, false)
                        stopService(Intent(this@MainActivity, InterceptService::class.java))
                        result.success(null)
                    }
                    "updateWidget" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = (call.arguments as? Map<String, String>) ?: emptyMap()
                        PageraWidget.save(this@MainActivity, data)
                        result.success(null)
                    }
                    "consumePending" -> {
                        result.success(pending)
                        pending = null
                    }
                    "allowFor" -> {
                        val pkg = call.argument<String>("pkg") ?: ""
                        val minutes = call.argument<Int>("minutes") ?: 10
                        InterceptService.allowFor(this@MainActivity, pkg, minutes)
                        result.success(null)
                    }
                    "openApp" -> {
                        val pkg = call.arguments as String
                        packageManager.getLaunchIntentForPackage(pkg)?.let {
                            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val pkg = intent.getStringExtra(InterceptService.EXTRA_PKG) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("intercepted", pkg) else pending = pkg
    }

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}

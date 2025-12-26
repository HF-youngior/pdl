package com.example.testflutterproject

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.example.testflutterproject.R

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.testflutterproject/lock_task"
        private const val PUSH_UTILS_CHANNEL = "com.example.testflutterproject/push_utils"
        private const val PUSH_CHANNEL_ID = "developer-default"
        private const val PUSH_CHANNEL_NAME = "默认通知通道"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 确保在 Android 8+ 创建通知通道，使系统设置可打开总开关
        createDefaultNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                startLockTask()
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    "stopLockTask" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                stopLockTask()
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSH_UTILS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                                val pkg = packageName
                                if (!pm.isIgnoringBatteryOptimizations(pkg)) {
                                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    intent.data = Uri.parse("package:$pkg")
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "openNotificationSettings" -> {
                        try {
                            val intent = Intent()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                intent.action = "android.settings.APP_NOTIFICATION_SETTINGS"
                                intent.putExtra("app_package", packageName)
                                intent.putExtra("app_uid", applicationInfo.uid)
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager != null) {
                val channel = manager.getNotificationChannel(PUSH_CHANNEL_ID)
                if (channel == null) {
                    val newChannel = NotificationChannel(
                        PUSH_CHANNEL_ID,
                        PUSH_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "企业管理系统默认通知通道"
                        setShowBadge(true)
                    }
                    manager.createNotificationChannel(newChannel)
                }
            }
        }
    }
}

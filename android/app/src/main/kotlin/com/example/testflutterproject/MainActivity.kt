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

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.testflutterproject/lock_task"
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
                            startLockTask()   // 安卓原生锁机 API
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    "stopLockTask" -> {
                        try {
                            stopLockTask()    // 安卓原生解锁 API
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
                var channel = manager.getNotificationChannel(PUSH_CHANNEL_ID)
                if (channel == null) {
                    channel = NotificationChannel(
                        PUSH_CHANNEL_ID,
                        PUSH_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "企业管理系统默认通知通道"
                        setShowBadge(true)
                    }
                    manager.createNotificationChannel(channel)
                }
                // 发送一次本地通知，确保系统识别为“会发送通知”的应用
                try {
                    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Notification.Builder(this, PUSH_CHANNEL_ID)
                    } else {
                        Notification.Builder(this)
                    }
                    val notification = builder
                        .setContentTitle("通知通道已创建")
                        .setContentText("企业管理系统已创建默认通知通道")
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setAutoCancel(true)
                        .build()
                    manager.notify(10001, notification)
                } catch (_: Exception) {
                }
            }
        }
    }
}

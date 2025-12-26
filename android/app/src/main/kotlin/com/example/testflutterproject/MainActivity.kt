package com.example.testflutterproject

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.testflutterproject/lock_task"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
package com.example.facebaby_flutter

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alarmChannel = "facebaby/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "needsExactAlarmFix" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        result.success(false)
                    } else {
                        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(!am.canScheduleExactAlarms())
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            startActivity(intent)
                        } catch (e: Exception) {
                            // Alguns OEMs: abrir definições da app
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            try {
                                startActivity(fallback)
                            } catch (ignored: Exception) {
                            }
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

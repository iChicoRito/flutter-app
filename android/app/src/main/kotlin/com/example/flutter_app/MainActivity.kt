package com.example.flutter_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "flutter_app/task_alarm_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDueAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val taskTitle = call.argument<String>("taskTitle")
                    val notificationId = call.argument<Int>("notificationId")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val scheduledAt = call.argument<Number>("scheduledAt")

                    if (
                        taskId == null ||
                        taskTitle == null ||
                        notificationId == null ||
                        title == null ||
                        body == null ||
                        scheduledAt == null
                    ) {
                        result.error("invalid_args", "Missing due alarm arguments.", null)
                        return@setMethodCallHandler
                    }

                    TaskAlarmScheduler.schedule(
                        context = applicationContext,
                        taskId = taskId,
                        taskTitle = taskTitle,
                        notificationId = notificationId,
                        title = title,
                        body = body,
                        scheduledAtMillis = scheduledAt.toLong(),
                    )
                    result.success(null)
                }

                "cancelDueAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val notificationId = call.argument<Int>("notificationId")
                    if (taskId == null || notificationId == null) {
                        result.error("invalid_args", "Missing cancel alarm arguments.", null)
                        return@setMethodCallHandler
                    }

                    TaskAlarmScheduler.cancel(
                        context = applicationContext,
                        taskId = taskId,
                        notificationId = notificationId,
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}

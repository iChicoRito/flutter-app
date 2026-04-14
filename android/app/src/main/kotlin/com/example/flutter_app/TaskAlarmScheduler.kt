package com.example.flutter_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object TaskAlarmScheduler {
    const val channelId = "task_due_alarms"
    const val actionTrigger = "com.example.flutter_app.ACTION_TRIGGER_DUE_ALARM"
    const val actionDismiss = "com.example.flutter_app.ACTION_DISMISS_DUE_ALARM"
    const val actionSnooze = "com.example.flutter_app.ACTION_SNOOZE_DUE_ALARM"
    const val prefsName = "FlutterSharedPreferences"
    const val latchedAlarmKey = "flutter.active_alarm_payload"

    const val extraTaskId = "extra_task_id"
    const val extraTaskTitle = "extra_task_title"
    const val extraNotificationId = "extra_notification_id"
    const val extraTitle = "extra_title"
    const val extraBody = "extra_body"
    const val extraScheduledAt = "extra_scheduled_at"

    fun schedule(
        context: Context,
        taskId: String,
        taskTitle: String,
        notificationId: Int,
        title: String,
        body: String,
        scheduledAtMillis: Long,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerIntent = Intent(context, TaskAlarmTriggerReceiver::class.java).apply {
            action = actionTrigger
            putAlarmExtras(
                taskId = taskId,
                taskTitle = taskTitle,
                notificationId = notificationId,
                title = title,
                body = body,
                scheduledAtMillis = scheduledAtMillis,
            )
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeFor(taskId),
            triggerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val showIntent = contentPendingIntent(
                context = context,
                taskId = taskId,
                taskTitle = taskTitle,
                scheduledAtMillis = scheduledAtMillis,
            )
            val info = AlarmManager.AlarmClockInfo(scheduledAtMillis, showIntent)
            alarmManager.setAlarmClock(info, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledAtMillis, pendingIntent)
        }
    }

    fun cancel(context: Context, taskId: String, notificationId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCodeFor(taskId),
            Intent(context, TaskAlarmTriggerReceiver::class.java).apply {
                action = actionTrigger
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        TaskAlarmForegroundService.stop(context, taskId = taskId, notificationId = notificationId)
        clearLatchedAlarm(context, taskId)
    }

    fun contentPendingIntent(
        context: Context,
        taskId: String,
        taskTitle: String,
        scheduledAtMillis: Long,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putAlarmExtras(
                taskId = taskId,
                taskTitle = taskTitle,
                notificationId = requestCodeFor(taskId),
                title = "",
                body = "",
                scheduledAtMillis = scheduledAtMillis,
            )
        }

        return PendingIntent.getActivity(
            context,
            requestCodeFor(taskId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun dismissPendingIntent(
        context: Context,
        taskId: String,
        notificationId: Int,
    ): PendingIntent {
        val intent = Intent(context, TaskAlarmActionReceiver::class.java).apply {
            action = actionDismiss
            putExtra(extraTaskId, taskId)
            putExtra(extraNotificationId, notificationId)
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun snoozePendingIntent(
        context: Context,
        taskId: String,
        taskTitle: String,
        notificationId: Int,
        title: String,
        body: String,
        scheduledAtMillis: Long,
    ): PendingIntent {
        val intent = Intent(context, TaskAlarmActionReceiver::class.java).apply {
            action = actionSnooze
            putAlarmExtras(
                taskId = taskId,
                taskTitle = taskTitle,
                notificationId = notificationId,
                title = title,
                body = body,
                scheduledAtMillis = scheduledAtMillis,
            )
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId + 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun persistLatchedAlarm(
        context: Context,
        taskId: String,
        taskTitle: String,
        scheduledAtMillis: Long,
    ) {
        val isoValue = java.time.Instant.ofEpochMilli(scheduledAtMillis).toString()
        val payload =
            """{"taskId":"${escape(taskId)}","taskTitle":"${escape(taskTitle)}","kind":"due","scheduledAt":"$isoValue"}"""
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(latchedAlarmKey, payload)
            .apply()
    }

    fun clearLatchedAlarm(context: Context, taskId: String? = null) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val current = prefs.getString(latchedAlarmKey, null)
        if (current == null) {
            return
        }
        if (taskId != null && !current.contains("\"taskId\":\"${escape(taskId)}\"")) {
            return
        }
        prefs.edit().remove(latchedAlarmKey).apply()
    }

    fun requestCodeFor(taskId: String): Int {
        return taskId.hashCode().let { if (it == Int.MIN_VALUE) 0 else kotlin.math.abs(it) }
    }

    private fun Intent.putAlarmExtras(
        taskId: String,
        taskTitle: String,
        notificationId: Int,
        title: String,
        body: String,
        scheduledAtMillis: Long,
    ) {
        putExtra(extraTaskId, taskId)
        putExtra(extraTaskTitle, taskTitle)
        putExtra(extraNotificationId, notificationId)
        putExtra(extraTitle, title)
        putExtra(extraBody, body)
        putExtra(extraScheduledAt, scheduledAtMillis)
    }

    private fun escape(value: String): String {
        return value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
    }
}

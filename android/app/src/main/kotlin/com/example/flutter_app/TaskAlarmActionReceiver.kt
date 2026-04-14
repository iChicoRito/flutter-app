package com.example.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TaskAlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra(TaskAlarmScheduler.extraTaskId) ?: return
        val notificationId = intent.getIntExtra(TaskAlarmScheduler.extraNotificationId, 0)

        when (intent.action) {
            TaskAlarmScheduler.actionDismiss -> {
                TaskAlarmScheduler.cancel(context, taskId, notificationId)
            }

            TaskAlarmScheduler.actionSnooze -> {
                TaskAlarmForegroundService.stop(
                    context = context,
                    taskId = taskId,
                    notificationId = notificationId,
                )
                TaskAlarmScheduler.clearLatchedAlarm(context, taskId)

                val taskTitle =
                    intent.getStringExtra(TaskAlarmScheduler.extraTaskTitle) ?: "Task reminder"
                val title = intent.getStringExtra(TaskAlarmScheduler.extraTitle) ?: "Hi, there"
                val body = intent.getStringExtra(TaskAlarmScheduler.extraBody)
                    ?: "Your task \"$taskTitle\" is due now."

                TaskAlarmScheduler.schedule(
                    context = context,
                    taskId = taskId,
                    taskTitle = taskTitle,
                    notificationId = notificationId,
                    title = title,
                    body = body,
                    scheduledAtMillis = System.currentTimeMillis() + (5 * 60 * 1000L),
                )
            }
        }
    }
}

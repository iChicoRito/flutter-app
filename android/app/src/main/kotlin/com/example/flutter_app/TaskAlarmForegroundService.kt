package com.example.flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class TaskAlarmForegroundService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val taskId = intent.getStringExtra(TaskAlarmScheduler.extraTaskId) ?: run {
            stopSelf()
            return START_NOT_STICKY
        }
        val taskTitle = intent.getStringExtra(TaskAlarmScheduler.extraTaskTitle) ?: "Task reminder"
        val notificationId = intent.getIntExtra(TaskAlarmScheduler.extraNotificationId, 0)
        val title = intent.getStringExtra(TaskAlarmScheduler.extraTitle) ?: "Hi, there"
        val body = intent.getStringExtra(TaskAlarmScheduler.extraBody) ?: "Your task is due now."
        val scheduledAtMillis = intent.getLongExtra(TaskAlarmScheduler.extraScheduledAt, System.currentTimeMillis())

        ensureChannel()
        TaskAlarmScheduler.persistLatchedAlarm(
            context = this,
            taskId = taskId,
            taskTitle = taskTitle,
            scheduledAtMillis = scheduledAtMillis,
        )

        val notification = buildNotification(
            taskId = taskId,
            taskTitle = taskTitle,
            notificationId = notificationId,
            title = title,
            body = body,
            scheduledAtMillis = scheduledAtMillis,
        )
        startForeground(notificationId, notification)
        startAlarmEffects()
        return START_STICKY
    }

    override fun onDestroy() {
        stopAlarmEffects()
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            TaskAlarmScheduler.channelId,
            "Task due alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "High-priority alerts when a task reaches its due time."
            enableVibration(true)
            setSound(
                null,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build(),
            )
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        taskId: String,
        taskTitle: String,
        notificationId: Int,
        title: String,
        body: String,
        scheduledAtMillis: Long,
    ): Notification {
        val openIntent = TaskAlarmScheduler.contentPendingIntent(
            context = this,
            taskId = taskId,
            taskTitle = taskTitle,
            scheduledAtMillis = scheduledAtMillis,
        )

        return NotificationCompat.Builder(this, TaskAlarmScheduler.channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(false)
            .setFullScreenIntent(openIntent, true)
            .setContentIntent(openIntent)
            .addAction(
                0,
                "Dismiss",
                TaskAlarmScheduler.dismissPendingIntent(
                    context = this,
                    taskId = taskId,
                    notificationId = notificationId,
                ),
            )
            .addAction(
                0,
                "Snooze 5 min",
                TaskAlarmScheduler.snoozePendingIntent(
                    context = this,
                    taskId = taskId,
                    taskTitle = taskTitle,
                    notificationId = notificationId,
                    title = title,
                    body = body,
                    scheduledAtMillis = scheduledAtMillis,
                ),
            )
            .build()
    }

    private fun startAlarmEffects() {
        if (mediaPlayer?.isPlaying == true) {
            return
        }

        val alarmUri =
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        mediaPlayer = MediaPlayer().apply {
            setDataSource(this@TaskAlarmForegroundService, alarmUri)
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            isLooping = true
            prepare()
            start()
        }

        @Suppress("DEPRECATION")
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        vibrator?.let { deviceVibrator ->
            val pattern = longArrayOf(0, 1200, 500, 1200)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                deviceVibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                deviceVibrator.vibrate(pattern, 0)
            }
        }
    }

    private fun stopAlarmEffects() {
        mediaPlayer?.runCatching {
            if (isPlaying) {
                stop()
            }
            reset()
            release()
        }
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    companion object {
        fun stop(context: Context, taskId: String, notificationId: Int) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            context.stopService(
                Intent(context, TaskAlarmForegroundService::class.java).apply {
                    putExtra(TaskAlarmScheduler.extraTaskId, taskId)
                },
            )
        }
    }
}

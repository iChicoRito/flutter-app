package com.example.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class TaskAlarmTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TaskAlarmScheduler.actionTrigger) {
            return
        }
        val extras = intent.extras ?: return

        val serviceIntent = Intent(context, TaskAlarmForegroundService::class.java).apply {
            action = TaskAlarmScheduler.actionTrigger
            replaceExtras(extras)
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}

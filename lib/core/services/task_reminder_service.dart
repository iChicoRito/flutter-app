import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/task_management/domain/task_item.dart';

abstract class TaskReminderService {
  Future<void> initialize();

  Future<void> syncTask(TaskItem task, {DateTime? now});

  Future<void> syncTaskIfSchedulingChanged({
    required TaskItem previous,
    required TaskItem next,
    DateTime? now,
  });

  Future<void> cancelTask(String taskId);

  Future<void> clearDueNotification(String taskId);

  Future<void> rebuildPendingReminders(Iterable<TaskItem> tasks, {DateTime? now});

  Future<void> snoozeTask(
    String taskId, {
    required String taskTitle,
    Duration duration = const Duration(minutes: 5),
  });

  bool isTaskAlarmSuppressed(String taskId, {DateTime? now});

  void bindAlarmHandler(Future<void> Function(TaskReminderEvent event) handler);
}

class NoopTaskReminderService implements TaskReminderService {
  const NoopTaskReminderService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncTask(TaskItem task, {DateTime? now}) async {}

  @override
  Future<void> syncTaskIfSchedulingChanged({
    required TaskItem previous,
    required TaskItem next,
    DateTime? now,
  }) async {}

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> clearDueNotification(String taskId) async {}

  @override
  Future<void> rebuildPendingReminders(
    Iterable<TaskItem> tasks, {
    DateTime? now,
  }) async {}

  @override
  Future<void> snoozeTask(
    String taskId, {
    required String taskTitle,
    Duration duration = const Duration(minutes: 5),
  }) async {}

  @override
  bool isTaskAlarmSuppressed(String taskId, {DateTime? now}) => false;

  @override
  void bindAlarmHandler(Future<void> Function(TaskReminderEvent event) handler) {}
}

enum TaskReminderKind { reminder, due }

@immutable
class TaskReminderEntry {
  const TaskReminderEntry({
    required this.id,
    required this.kind,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final TaskReminderKind kind;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

@immutable
class TaskReminderPayload {
  const TaskReminderPayload({
    required this.taskId,
    required this.taskTitle,
    required this.kind,
    this.scheduledAt,
  });

  factory TaskReminderPayload.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return TaskReminderPayload(
      taskId: map['taskId'] as String,
      taskTitle: map['taskTitle'] as String? ?? 'Task reminder',
      kind: TaskReminderKind.values.byName(map['kind'] as String),
      scheduledAt: map['scheduledAt'] == null
          ? null
          : DateTime.parse(map['scheduledAt'] as String),
    );
  }

  final String taskId;
  final String taskTitle;
  final TaskReminderKind kind;
  final DateTime? scheduledAt;

  String toJson() {
    return jsonEncode({
      'taskId': taskId,
      'taskTitle': taskTitle,
      'kind': kind.name,
      'scheduledAt': scheduledAt?.toIso8601String(),
    });
  }
}

@immutable
class TaskReminderEvent {
  const TaskReminderEvent({
    required this.payload,
    required this.responseType,
    this.actionId,
  });

  final TaskReminderPayload payload;
  final NotificationResponseType responseType;
  final String? actionId;
}

@immutable
class TaskReminderPlan {
  const TaskReminderPlan._();

  static const Duration reminderLeadTime = Duration(minutes: 15);

  static bool hasSchedulingChange(TaskItem previous, TaskItem next) {
    return previous.isCompleted != next.isCompleted ||
        previous.endDate != next.endDate ||
        previous.endMinutes != next.endMinutes ||
        previous.title != next.title;
  }

  static int reminderNotificationId(String taskId) {
    return _notificationId(taskId, salt: 17);
  }

  static int dueNotificationId(String taskId) {
    return _notificationId(taskId, salt: 31);
  }

  static Set<int> allNotificationIds(String taskId) {
    return {reminderNotificationId(taskId), dueNotificationId(taskId)};
  }

  static List<TaskReminderEntry> buildEntries(
    TaskItem task, {
    required DateTime now,
  }) {
    if (task.isCompleted) {
      return const [];
    }

    final dueAt = task.endDateTime;
    if (dueAt == null || !dueAt.isAfter(now)) {
      return const [];
    }

    final dueEntry = TaskReminderEntry(
      id: dueNotificationId(task.id),
      kind: TaskReminderKind.due,
      scheduledAt: dueAt,
      title: task.title,
      body: 'Task is due now.',
    );

    final reminderAt = dueAt.subtract(reminderLeadTime);
    if (!reminderAt.isAfter(now)) {
      return [dueEntry];
    }

    return [
      TaskReminderEntry(
        id: reminderNotificationId(task.id),
        kind: TaskReminderKind.reminder,
        scheduledAt: reminderAt,
        title: 'Task due soon',
        body: '"${task.title}" is due in 15 minutes.',
      ),
      dueEntry,
    ];
  }

  static int _notificationId(String taskId, {required int salt}) {
    const int fnvPrime = 16777619;
    var hash = 2166136261;

    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    hash ^= salt;
    hash = (hash * fnvPrime) & 0x7fffffff;
    return hash;
  }
}

class LocalTaskReminderService implements TaskReminderService {
  LocalTaskReminderService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = 'task_reminders';
  static const String dueChannelId = 'task_due_alarms';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;
  bool _isAvailable = true;
  Future<void> Function(TaskReminderEvent event)? _alarmHandler;
  TaskReminderEvent? _pendingAlarmEvent;
  final Map<String, Timer> _dueTimers = {};
  final Map<String, DateTime> _snoozedUntil = {};

  @override
  Future<void> initialize() async {
    if (_isInitialized || !_isAvailable || kIsWeb) {
      return;
    }

    try {
      tz.initializeTimeZones();
      await _configureLocalTimezone();

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) {
            _dispatchPayload(
              payload,
              actionId: response.actionId,
              responseType: response.notificationResponseType,
            );
          }
        },
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final initialPayload = launchDetails?.notificationResponse?.payload;
      if (initialPayload != null) {
        _dispatchPayload(
          initialPayload,
          actionId: launchDetails?.notificationResponse?.actionId,
          responseType:
              launchDetails?.notificationResponse?.notificationResponseType ??
              NotificationResponseType.selectedNotification,
        );
      }

      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          reminderChannelId,
          'Task reminders',
          description: 'Pre-deadline reminders for upcoming tasks.',
          importance: Importance.high,
        ),
      );
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          dueChannelId,
          'Task due alarms',
          description: 'High-priority alerts when a task reaches its due time.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestFullScreenIntentPermission();
        final canScheduleExact =
            await androidImplementation?.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          await androidImplementation?.requestExactAlarmsPermission();
        }
      }
    } on MissingPluginException {
      _isAvailable = false;
      return;
    }

    _isInitialized = true;
  }

  @override
  void bindAlarmHandler(Future<void> Function(TaskReminderEvent event) handler) {
    _alarmHandler = handler;
    final pendingEvent = _pendingAlarmEvent;
    if (pendingEvent != null) {
      _pendingAlarmEvent = null;
      unawaited(handler(pendingEvent));
    }
  }

  @override
  Future<void> syncTask(TaskItem task, {DateTime? now}) async {
    await initialize();
    if (!_isAvailable) {
      return;
    }
    await cancelTask(task.id);
    _snoozedUntil.remove(task.id);
    _scheduleForegroundDueTimer(task, now: now);

    final entries = TaskReminderPlan.buildEntries(
      task,
      now: now ?? DateTime.now(),
    );
    for (final entry in entries) {
      await _scheduleEntry(
        taskId: task.id,
        taskTitle: task.title,
        entry: entry,
      );
    }
  }

  @override
  Future<void> syncTaskIfSchedulingChanged({
    required TaskItem previous,
    required TaskItem next,
    DateTime? now,
  }) async {
    if (!TaskReminderPlan.hasSchedulingChange(previous, next)) {
      return;
    }

    await syncTask(next, now: now);
  }

  @override
  Future<void> cancelTask(String taskId) async {
    await initialize();
    if (!_isAvailable) {
      return;
    }
    _snoozedUntil.remove(taskId);
    _dueTimers.remove(taskId)?.cancel();
    for (final notificationId in TaskReminderPlan.allNotificationIds(taskId)) {
      await _plugin.cancel(id: notificationId);
    }
  }

  @override
  Future<void> clearDueNotification(String taskId) async {
    await initialize();
    if (!_isAvailable) {
      return;
    }

    await _plugin.cancel(id: TaskReminderPlan.dueNotificationId(taskId));
  }

  @override
  Future<void> rebuildPendingReminders(
    Iterable<TaskItem> tasks, {
    DateTime? now,
  }) async {
    await initialize();
    if (!_isAvailable) {
      return;
    }

    final currentTime = now ?? DateTime.now();
    final activeIds = <int>{};

    for (final task in tasks) {
      final entries = TaskReminderPlan.buildEntries(task, now: currentTime);
      activeIds.addAll(entries.map((entry) => entry.id));
      await syncTask(task, now: currentTime);
    }

    final pendingRequests = await _plugin.pendingNotificationRequests();
    for (final request in pendingRequests) {
      if (!activeIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<void> snoozeTask(
    String taskId, {
    required String taskTitle,
    Duration duration = const Duration(minutes: 5),
  }) async {
    await initialize();
    if (!_isAvailable) {
      return;
    }

    final snoozeUntil = DateTime.now().add(duration);
    _snoozedUntil[taskId] = snoozeUntil;
    _dueTimers.remove(taskId)?.cancel();

    for (final notificationId in TaskReminderPlan.allNotificationIds(taskId)) {
      await _plugin.cancel(id: notificationId);
    }

    _scheduleSingleForegroundTimer(
      taskId: taskId,
      taskTitle: taskTitle,
      dueAt: snoozeUntil,
    );

    await _scheduleEntry(
      taskId: taskId,
      taskTitle: taskTitle,
      entry: TaskReminderEntry(
        id: TaskReminderPlan.dueNotificationId(taskId),
        kind: TaskReminderKind.due,
        scheduledAt: snoozeUntil,
        title: taskTitle,
        body: 'Snoozed task is due now.',
      ),
    );
  }

  @override
  bool isTaskAlarmSuppressed(String taskId, {DateTime? now}) {
    final suppressedUntil = _snoozedUntil[taskId];
    if (suppressedUntil == null) {
      return false;
    }

    final currentTime = now ?? DateTime.now();
    if (suppressedUntil.isAfter(currentTime)) {
      return true;
    }

    _snoozedUntil.remove(taskId);
    return false;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  tz.TZDateTime _toScheduledDate(DateTime value) {
    return tz.TZDateTime.from(value, tz.local);
  }

  Future<AndroidScheduleMode> _scheduleModeFor(TaskReminderKind kind) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications();

    if (canScheduleExact == false) {
      await androidImplementation?.requestExactAlarmsPermission();
    }

    final canScheduleAfterRequest =
        await androidImplementation?.canScheduleExactNotifications();

    if (canScheduleAfterRequest == false) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    return switch (kind) {
      TaskReminderKind.reminder => AndroidScheduleMode.exactAllowWhileIdle,
      TaskReminderKind.due => AndroidScheduleMode.alarmClock,
    };
  }

  AndroidNotificationDetails _androidDetailsFor(TaskReminderKind kind) {
    return switch (kind) {
      TaskReminderKind.reminder => const AndroidNotificationDetails(
        reminderChannelId,
        'Task reminders',
        channelDescription: 'Pre-deadline reminders for upcoming tasks.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      TaskReminderKind.due => const AndroidNotificationDetails(
        dueChannelId,
        'Task due alarms',
        channelDescription: 'High-priority alerts when a task reaches its due time.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        ticker: 'Task due alarm',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze_5m',
            'Snooze 5 min',
            showsUserInterface: true,
          ),
        ],
      ),
    };
  }

  DarwinNotificationDetails _darwinDetailsFor(TaskReminderKind kind) {
    return switch (kind) {
      TaskReminderKind.reminder => const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      TaskReminderKind.due => const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    };
  }

  Future<void> _scheduleEntry({
    required String taskId,
    required String taskTitle,
    required TaskReminderEntry entry,
  }) async {
    await _plugin.zonedSchedule(
      id: entry.id,
      title: entry.title,
      body: entry.body,
      scheduledDate: _toScheduledDate(entry.scheduledAt),
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(entry.kind),
        iOS: _darwinDetailsFor(entry.kind),
        macOS: _darwinDetailsFor(entry.kind),
      ),
      androidScheduleMode: await _scheduleModeFor(entry.kind),
      payload: TaskReminderPayload(
        taskId: taskId,
        taskTitle: taskTitle,
        kind: entry.kind,
        scheduledAt: entry.scheduledAt,
      ).toJson(),
    );
  }

  void _dispatchPayload(
    String rawPayload, {
    String? actionId,
    NotificationResponseType responseType =
        NotificationResponseType.selectedNotification,
  }) {
    final payload = TaskReminderPayload.fromJson(rawPayload);
    final event = TaskReminderEvent(
      payload: payload,
      responseType: responseType,
      actionId: actionId,
    );
    final handler = _alarmHandler;
    if (handler == null) {
      _pendingAlarmEvent = event;
      return;
    }

    unawaited(handler(event));
  }

  void _scheduleForegroundDueTimer(TaskItem task, {DateTime? now}) {
    _dueTimers.remove(task.id)?.cancel();

    if (task.isCompleted) {
      return;
    }

    final dueAt = task.endDateTime;
    final currentTime = now ?? DateTime.now();
    if (dueAt == null || !dueAt.isAfter(currentTime)) {
      return;
    }

    _scheduleSingleForegroundTimer(
      taskId: task.id,
      taskTitle: task.title,
      dueAt: dueAt,
      now: currentTime,
    );
  }

  void _scheduleSingleForegroundTimer({
    required String taskId,
    required String taskTitle,
    required DateTime dueAt,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    _dueTimers[taskId] = Timer(dueAt.difference(currentTime), () {
      _dueTimers.remove(taskId);
      _dispatchPayload(
        TaskReminderPayload(
          taskId: taskId,
          taskTitle: taskTitle,
          kind: TaskReminderKind.due,
          scheduledAt: dueAt,
        ).toJson(),
      );
    });
  }
}

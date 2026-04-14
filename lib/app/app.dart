import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/display_name_store.dart';
import '../core/services/onboarding_status_store.dart';
import '../core/services/task_reminder_scope.dart';
import '../core/services/task_reminder_service.dart';
import '../core/services/task_repository_scope.dart';
import '../features/task_reminder/presentation/task_alarm_screen.dart';
import '../features/task_management/data/hive_task_repository.dart';
import '../features/task_management/domain/task_repository.dart';
import '../features/splash/presentation/splash_screen.dart';

class MyApp extends StatefulWidget {
  MyApp({
    super.key,
    OnboardingStatusStore? onboardingStatusStore,
    DisplayNameStore? displayNameStore,
    TaskRepository? taskRepository,
    TaskReminderService? reminderService,
  }) : onboardingStatusStore =
           onboardingStatusStore ??
           const SharedPreferencesOnboardingStatusStore(),
       displayNameStore =
           displayNameStore ?? const SharedPreferencesDisplayNameStore(),
       taskRepository = taskRepository ?? InMemoryTaskRepository(),
       reminderService = reminderService ?? const NoopTaskReminderService();

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;
  final TaskRepository taskRepository;
  final TaskReminderService reminderService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const Duration _foregroundAlarmGracePeriod = Duration(seconds: 10);

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  String? _activeAlarmTaskId;
  Timer? _foregroundAlarmPoller;
  final Set<String> _handledDueTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reminderService.bindAlarmHandler(_handleAlarmEvent);
    _startForegroundAlarmPoller();
  }

  @override
  void dispose() {
    _foregroundAlarmPoller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _startForegroundAlarmPoller();
      unawaited(_checkForDueTasks());
    } else {
      _foregroundAlarmPoller?.cancel();
      _foregroundAlarmPoller = null;
    }
  }

  Future<void> _handleAlarmEvent(TaskReminderEvent event) async {
    final payload = event.payload;
    switch (event.actionId) {
      case 'dismiss_alarm':
        await widget.reminderService.cancelTask(payload.taskId);
        return;
      case 'snooze_5m':
        await widget.reminderService.snoozeTask(
          payload.taskId,
          taskTitle: payload.taskTitle,
        );
        return;
    }

    if (payload.kind != TaskReminderKind.due) {
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (_activeAlarmTaskId == payload.taskId) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _activeAlarmTaskId = payload.taskId;
    _handledDueTaskIds.add(payload.taskId);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => TaskAlarmScreen(
          payload: payload,
          reminderService: widget.reminderService,
          taskRepository: widget.taskRepository,
        ),
        settings: const RouteSettings(name: TaskAlarmScreen.routeName),
        fullscreenDialog: true,
      ),
    );
    _activeAlarmTaskId = null;
  }

  void _startForegroundAlarmPoller() {
    _foregroundAlarmPoller?.cancel();
    _foregroundAlarmPoller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_checkForDueTasks()),
    );
  }

  Future<void> _checkForDueTasks() async {
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (_activeAlarmTaskId != null) {
      return;
    }

    final now = DateTime.now();
    final tasks = await widget.taskRepository.getTasks();
    for (final task in tasks) {
      final dueAt = task.endDateTime;
      if (task.isCompleted || dueAt == null || dueAt.isAfter(now)) {
        continue;
      }
      if (now.difference(dueAt) > _foregroundAlarmGracePeriod) {
        _handledDueTaskIds.add(task.id);
        continue;
      }
      if (_handledDueTaskIds.contains(task.id)) {
        continue;
      }

      if (widget.reminderService.isTaskAlarmSuppressed(task.id, now: now)) {
        continue;
      }

      await _handleAlarmEvent(
        TaskReminderEvent(
          payload: TaskReminderPayload(
            taskId: task.id,
            taskTitle: task.title,
            kind: TaskReminderKind.due,
            scheduledAt: dueAt,
          ),
          responseType: NotificationResponseType.selectedNotification,
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF066FD1);

    return TaskReminderScope(
      reminderService: widget.reminderService,
      child: TaskRepositoryScope(
        repository: widget.taskRepository,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Flutter App',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: primaryBlue,
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryTextTheme: GoogleFonts.poppinsTextTheme(),
          ),
          home: SplashScreen(
            onboardingStatusStore: widget.onboardingStatusStore,
            displayNameStore: widget.displayNameStore,
          ),
        ),
      ),
    );
  }
}

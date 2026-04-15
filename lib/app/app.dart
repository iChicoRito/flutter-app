import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/display_name_store.dart';
import '../core/services/onboarding_status_store.dart';
import '../core/services/task_reminder_scope.dart';
import '../core/services/task_reminder_service.dart';
import '../core/services/task_repository_scope.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/task_reminder/presentation/task_alarm_screen.dart';
import '../features/task_management/data/hive_task_repository.dart';
import '../features/task_management/domain/task_repository.dart';

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
  static const String _latchedAlarmPayloadKey = 'active_alarm_payload';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  String? _activeAlarmTaskId;
  TaskReminderPayload? _activeAlarmPayload;
  bool _isAlarmScreenVisible = false;
  Timer? _foregroundAlarmPoller;
  final Set<String> _handledDueTaskIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reminderService.bindAlarmHandler(_handleAlarmEvent);
    _startForegroundAlarmPoller();
    unawaited(_restoreLatchedAlarm());
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
      unawaited(_restoreLatchedAlarm());
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
        if (_isAlarmScreenVisible && _activeAlarmTaskId == payload.taskId) {
          return;
        }
        await widget.reminderService.cancelTask(payload.taskId);
        await _clearLatchedAlarm();
        return;
      case 'snooze_5m':
        if (_isAlarmScreenVisible && _activeAlarmTaskId == payload.taskId) {
          return;
        }
        await widget.reminderService.snoozeTask(
          payload.taskId,
          taskTitle: payload.taskTitle,
        );
        await _clearLatchedAlarm();
        return;
    }

    if (payload.kind != TaskReminderKind.due) {
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (_isAlarmScreenVisible) {
      _handledDueTaskIds.add(payload.taskId);
      return;
    }
    if (_activeAlarmTaskId == payload.taskId) {
      return;
    }

    await widget.reminderService.clearDueNotification(payload.taskId);
    await _persistLatchedAlarm(payload);
    if (!mounted) {
      return;
    }

    setState(() {
      _activeAlarmTaskId = payload.taskId;
      _activeAlarmPayload = payload;
      _handledDueTaskIds.add(payload.taskId);
      _isAlarmScreenVisible = true;
    });
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

  Future<void> _persistLatchedAlarm(TaskReminderPayload payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latchedAlarmPayloadKey, payload.toJson());
  }

  Future<void> _clearLatchedAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latchedAlarmPayloadKey);
  }

  Future<void> _restoreLatchedAlarm() async {
    if (_activeAlarmPayload != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawPayload = prefs.getString(_latchedAlarmPayloadKey);
    if (rawPayload == null) {
      return;
    }

    final payload = TaskReminderPayload.fromJson(rawPayload);
    await widget.reminderService.clearDueNotification(payload.taskId);
    if (!mounted) {
      return;
    }

    setState(() {
      _activeAlarmTaskId = payload.taskId;
      _activeAlarmPayload = payload;
      _handledDueTaskIds.add(payload.taskId);
      _isAlarmScreenVisible = true;
    });
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
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (_activeAlarmPayload != null)
                  Positioned.fill(
                    child: TaskAlarmScreen(
                      payload: _activeAlarmPayload!,
                      reminderService: widget.reminderService,
                      taskRepository: widget.taskRepository,
                      displayNameStore: widget.displayNameStore,
                      onDismissed: () {
                        if (!mounted) {
                          return;
                        }
                        unawaited(_clearLatchedAlarm());
                        setState(() {
                          _activeAlarmPayload = null;
                          _activeAlarmTaskId = null;
                          _isAlarmScreenVisible = false;
                        });
                      },
                    ),
                  ),
              ],
            );
          },
          title: 'Remindly',
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
            scaffoldBackgroundColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryTextTheme: GoogleFonts.poppinsTextTheme(),
          ),
          home: _InitialLaunchGate(
            onboardingStatusStore: widget.onboardingStatusStore,
            displayNameStore: widget.displayNameStore,
          ),
        ),
      ),
    );
  }
}

class _InitialLaunchGate extends StatelessWidget {
  const _InitialLaunchGate({
    required this.onboardingStatusStore,
    required this.displayNameStore,
  });

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: onboardingStatusStore.isCompleted(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.data ?? false) {
          return DashboardScreen(displayNameStore: displayNameStore);
        }

        return OnboardingScreen(
          onboardingStatusStore: onboardingStatusStore,
          displayNameStore: displayNameStore,
        );
      },
    );
  }
}

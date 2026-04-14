import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/task_reminder_service.dart';
import '../../task_management/data/task_note_codec.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/domain/task_repository.dart';

class TaskAlarmScreen extends StatefulWidget {
  const TaskAlarmScreen({
    super.key,
    required this.payload,
    required this.reminderService,
    required this.taskRepository,
    this.onDismissed,
  });

  static const routeName = 'task-alarm-screen';

  final TaskReminderPayload payload;
  final TaskReminderService reminderService;
  final TaskRepository taskRepository;
  final VoidCallback? onDismissed;

  @override
  State<TaskAlarmScreen> createState() => _TaskAlarmScreenState();
}

class _TaskAlarmScreenState extends State<TaskAlarmScreen>
    with SingleTickerProviderStateMixin {
  bool _isDismissing = false;
  List<_AlarmTaskDetails> _alarmTasks = const [];
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _loadTaskDetails();
    _startAlarmEffects();
  }

  @override
  void dispose() {
    _iconController.dispose();
    _stopAlarmEffects();
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
    final allTasks = await widget.taskRepository.getTasks();
    final categories = await widget.taskRepository.getCategories();
    if (!mounted) {
      return;
    }

    final dueAt = widget.payload.scheduledAt;
    final matchingTasks = <_AlarmTaskDetails>[];

    for (final task in allTasks) {
      if (task.isCompleted) {
        continue;
      }
      if (!_isSameAlarmTime(task.endDateTime, dueAt)) {
        continue;
      }

      TaskCategory? category;
      for (final item in categories) {
        if (item.id == task.categoryId) {
          category = item;
          break;
        }
      }

      matchingTasks.add(_AlarmTaskDetails(task: task, category: category));
    }

    setState(() {
      _alarmTasks = matchingTasks.isEmpty
          ? [
              _AlarmTaskDetails(
                task: null,
                category: null,
                fallbackTitle: widget.payload.taskTitle,
              ),
            ]
          : matchingTasks;
    });
  }

  Future<void> _startAlarmEffects() async {
    await WakelockPlus.enable();

    FlutterRingtonePlayer().play(
      android: AndroidSounds.alarm,
      ios: const IosSound(1023),
      looping: true,
      volume: 1,
      asAlarm: true,
    );

    final canVibrate = await Vibration.hasVibrator();
    if (!canVibrate) {
      return;
    }

    final supportsCustomPatterns =
        await Vibration.hasCustomVibrationsSupport();
    if (supportsCustomPatterns) {
      await Vibration.vibrate(
        pattern: const [0, 1200, 500, 1200],
        repeat: 0,
        intensities: const [255, 180],
      );
      return;
    }

    await Vibration.vibrate(duration: 1500);
  }

  Future<void> _stopAlarmEffects() async {
    FlutterRingtonePlayer().stop();
    await Vibration.cancel();
    await WakelockPlus.disable();
  }

  Future<void> _dismissAlarm() async {
    if (_isDismissing) {
      return;
    }

    setState(() {
      _isDismissing = true;
    });

    await _stopAlarmEffects();
    for (final item in _alarmTasks) {
      final taskId = item.task?.id;
      if (taskId != null) {
        await widget.reminderService.cancelTask(taskId);
      }
    }
    if (_alarmTasks.every((item) => item.task == null)) {
      await widget.reminderService.cancelTask(widget.payload.taskId);
    }

    if (!mounted) {
      return;
    }

    if (widget.onDismissed != null) {
      widget.onDismissed!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueTime(widget.payload.scheduledAt);
    final alarmTasks = _alarmTasks;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF066FD1),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 22,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _iconController,
                        builder: (context, child) => child!,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FA),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _iconController,
                              builder: (context, _) {
                                return Transform.rotate(
                                  angle: _shakeAngle(_iconController.value),
                                  child: const Icon(
                                    Icons.alarm_rounded,
                                    size: 36,
                                    color: Color(0xFF066FD1),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.payload.kind == TaskReminderKind.due
                            ? 'Tasks Due Now!'
                            : 'Task Reminder',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF333333),
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (dueText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Your task is scheduled for $dueText',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E8EC)),
                      const SizedBox(height: 14),
                      ..._buildAlarmTaskSections(context, alarmTasks),
                      const SizedBox(height: 14),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E8EC)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _isDismissing ? null : _dismissAlarm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF066FD1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _isDismissing ? 'Stopping Alarm...' : 'Dismiss Alarm',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _formatDueTime(DateTime? value) {
    if (value == null) {
      return null;
    }

    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year} at $hour:$minute $suffix';
  }

  String _resolveTaskDetails(TaskItem? task) {
    if (task == null) {
      return 'Task details will appear here when available.';
    }

    final description = taskDescriptionPreview(task);
    if (description.isNotEmpty) {
      return description;
    }

    final notePreview = taskActualNotePreview(task);
    if (notePreview.isNotEmpty) {
      return notePreview;
    }

    return 'No additional task details were added yet.';
  }

  double _shakeAngle(double progress) {
    if (progress >= 0.6) {
      return 0;
    }

    final activeProgress = progress / 0.6;
    return 0.16 * sin(activeProgress * 8 * pi) * (1 - (activeProgress * 0.12));
  }

  List<Widget> _buildAlarmTaskSections(
    BuildContext context,
    List<_AlarmTaskDetails> alarmTasks,
  ) {
    final sections = <Widget>[];

    for (var index = 0; index < alarmTasks.length; index++) {
      final item = alarmTasks[index];
      final task = item.task;
      final category = item.category;

      sections.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            task?.title ?? item.fallbackTitle ?? widget.payload.taskTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF333333),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      sections.add(const SizedBox(height: 6));
      sections.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _resolveTaskDetails(task),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF999999),
              height: 1.35,
            ),
          ),
        ),
      );
      sections.add(const SizedBox(height: 10));
      if (category != null) {
        sections.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    resolveTaskCategoryIcon(category.iconKey),
                    size: 13,
                    color: category.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: category.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        sections.add(const SizedBox(height: 10));
      }

      if (index != alarmTasks.length - 1) {
        sections.add(
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E8EC)),
        );
        sections.add(const SizedBox(height: 14));
      }
    }

    return sections;
  }

  bool _isSameAlarmTime(DateTime? first, DateTime? second) {
    if (first == null || second == null) {
      return false;
    }

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day &&
        first.hour == second.hour &&
        first.minute == second.minute;
  }
}

class _AlarmTaskDetails {
  const _AlarmTaskDetails({
    required this.task,
    required this.category,
    this.fallbackTitle,
  });

  final TaskItem? task;
  final TaskCategory? category;
  final String? fallbackTitle;
}

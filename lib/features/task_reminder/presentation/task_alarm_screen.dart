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
  });

  static const routeName = 'task-alarm-screen';

  final TaskReminderPayload payload;
  final TaskReminderService reminderService;
  final TaskRepository taskRepository;

  @override
  State<TaskAlarmScreen> createState() => _TaskAlarmScreenState();
}

class _TaskAlarmScreenState extends State<TaskAlarmScreen>
    with SingleTickerProviderStateMixin {
  bool _isDismissing = false;
  TaskItem? _task;
  TaskCategory? _category;
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
    final task = await widget.taskRepository.getTaskById(widget.payload.taskId);
    final categories = await widget.taskRepository.getCategories();
    if (!mounted) {
      return;
    }

    TaskCategory? category;
    if (task != null) {
      for (final item in categories) {
        if (item.id == task.categoryId) {
          category = item;
          break;
        }
      }
    }

    setState(() {
      _task = task;
      _category = category;
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
    await widget.reminderService.cancelTask(widget.payload.taskId);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueTime(widget.payload.scheduledAt);
    final task = _task;
    final category = _category;
    final title = task?.title ?? widget.payload.taskTitle;
    final detailsText = _resolveTaskDetails(task);

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
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FA),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _iconController,
                              builder: (context, _) {
                                return Transform.rotate(
                                  angle: _shakeAngle(_iconController.value),
                                  child: const Icon(
                                    Icons.alarm_rounded,
                                    size: 44,
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
                      const SizedBox(height: 12),
                      Text(
                        widget.payload.taskTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF333333),
                          fontWeight: FontWeight.w600,
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF333333),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          detailsText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF999999),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (category != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: category.color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}

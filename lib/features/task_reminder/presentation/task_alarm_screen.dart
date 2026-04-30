import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/display_name_store.dart';
import '../../../core/services/task_reminder_service.dart';
import '../../../core/theme/app_design_tokens.dart';
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
    required this.displayNameStore,
    this.onDismissed,
  });

  static const routeName = 'task-alarm-screen';

  final TaskReminderPayload payload;
  final TaskReminderService reminderService;
  final TaskRepository taskRepository;
  final DisplayNameStore displayNameStore;
  final VoidCallback? onDismissed;

  @override
  State<TaskAlarmScreen> createState() => _TaskAlarmScreenState();
}

class _TaskAlarmScreenState extends State<TaskAlarmScreen> {
  bool _isDismissing = false;
  List<_AlarmTaskDetails> _alarmTasks = const [];

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
    _startAlarmEffects();
  }

  @override
  void dispose() {
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

    final supportsCustomPatterns = await Vibration.hasCustomVibrationsSupport();
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
        backgroundColor: AppColors.primaryButtonFill,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth < AppSizes.heroDialogMaxWidth
                  ? constraints.maxWidth - (AppSpacing.four * 2)
                  : AppSizes.heroDialogMaxWidth;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.four,
                    vertical: AppSpacing.six,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.heroDialogTopInset,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardFill,
                              borderRadius: BorderRadius.circular(
                                AppRadii.threeXl,
                              ),
                              border: Border.all(color: AppColors.neutral200),
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.heroDialogCardPadding,
                              AppSizes.heroDialogTopInset -
                                  AppSizes.heroDialogIllustrationOverlap,
                              AppSizes.heroDialogCardPadding,
                              AppSpacing.eight,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.payload.kind == TaskReminderKind.due
                                      ? 'Tasks Due Now!'
                                      : 'Task Reminder',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.primaryButtonFill,
                                        fontSize: AppTypography.size2xl,
                                        fontWeight:
                                            AppTypography.weightSemibold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                if (dueText != null) ...[
                                  const SizedBox(height: AppSpacing.three),
                                  Text(
                                    _summaryLine(dueText),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.subHeaderText,
                                          height: 1.2,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.six),
                                if (alarmTasks.length > 2)
                                  SizedBox(
                                    height:
                                        AppSizes.heroDialogTaskListMaxHeight,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: _buildAlarmTaskSections(
                                          context,
                                          alarmTasks,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: _buildAlarmTaskSections(
                                      context,
                                      alarmTasks,
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.five),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isDismissing
                                        ? null
                                        : _dismissAlarm,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(
                                        AppSizes.heroDialogButtonHeight,
                                      ),
                                      backgroundColor:
                                          AppColors.primaryButtonFill,
                                      foregroundColor:
                                          AppColors.primaryButtonText,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.xl,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _isDismissing
                                          ? 'Stopping Alarm...'
                                          : 'Dismiss Alarm',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: SizedBox(
                            width: AppSizes.heroDialogIllustrationWidth,
                            height: AppSizes.heroDialogIllustrationHeight,
                            child: SvgPicture.asset(
                              'assets/svgs/welcome/remindly-alarm.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _summaryLine(String dueText) {
    if (widget.payload.kind == TaskReminderKind.due) {
      return 'Your tasks is scheduled for $dueText';
    }

    return 'Task reminder is scheduled for $dueText';
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: AppSpacing.five,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardFill,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task?.title ??
                          item.fallbackTitle ??
                          widget.payload.taskTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.titleText,
                        fontSize: AppTypography.size2xl,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                  ),
                  if (category != null)
                    Container(
                      margin: const EdgeInsets.only(left: AppSpacing.three),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.four,
                        vertical: AppSpacing.one,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        category.name,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: category.color,
                          fontSize: AppTypography.sizeXs,
                          fontWeight: AppTypography.weightMedium,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.three),
              Text(
                _resolveTaskDetails(task),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.subHeaderText),
              ),
            ],
          ),
        ),
      );

      if (index != alarmTasks.length - 1) {
        sections.add(const SizedBox(height: AppSpacing.three));
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

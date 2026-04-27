import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import 'task_management_controller.dart';
import 'task_management_ui.dart';

class TaskCalendarView extends StatelessWidget {
  const TaskCalendarView({
    super.key,
    required this.controller,
    required this.segmentControl,
    required this.selectedMonth,
    required this.selectedDate,
    required this.statusFilter,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onStatusSelected,
    required this.onSchedulePressed,
    required this.onTaskTap,
    required this.monthDropdownKey,
    required this.statusChipKeyBuilder,
    required this.dateKeyBuilder,
    required this.scheduleButtonKey,
  });

  final TaskManagementController controller;
  final Widget segmentControl;
  final DateTime selectedMonth;
  final DateTime selectedDate;
  final TaskStatusFilter statusFilter;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<TaskStatusFilter> onStatusSelected;
  final VoidCallback onSchedulePressed;
  final ValueChanged<TaskItem> onTaskTap;
  final Key monthDropdownKey;
  final Key Function(String value) statusChipKeyBuilder;
  final Key Function(String value) dateKeyBuilder;
  final Key scheduleButtonKey;

  @override
  Widget build(BuildContext context) {
    final calendarTasks = controller.calendarTasksForDate(
      selectedDate: selectedDate,
      statusFilter: statusFilter,
      now: DateTime.now(),
    );

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.blue500,
          onRefresh: controller.load,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.four,
                  AppSpacing.six,
                  AppSpacing.four,
                  120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _CalendarHeader(),
                    const SizedBox(height: AppSpacing.six),
                    _CalendarMonthPicker(
                      buttonKey: monthDropdownKey,
                      selectedMonth: selectedMonth,
                      onSelected: onMonthChanged,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    _CalendarStatusRow(
                      selectedFilter: statusFilter,
                      onSelected: onStatusSelected,
                      chipKeyBuilder: statusChipKeyBuilder,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    segmentControl,
                    const SizedBox(height: AppSpacing.six),
                    _TaskCalendarDateRail(
                      selectedMonth: selectedMonth,
                      selectedDate: selectedDate,
                      availableDays: controller.calendarDaysForMonth(
                        selectedMonth,
                      ),
                      onSelected: onDateSelected,
                      dateKeyBuilder: dateKeyBuilder,
                    ),
                    const SizedBox(height: AppSpacing.six),
                    _CalendarMonthSummary(selectedMonth: selectedMonth),
                    const SizedBox(height: AppSpacing.three),
                    _CalendarTimeline(
                      tasks: calendarTasks,
                      categoryFor: controller.categoryFor,
                      selectedDate: selectedDate,
                      onTaskTap: onTaskTap,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.four,
          bottom: AppSpacing.four,
          child: FilledButton.icon(
            key: scheduleButtonKey,
            onPressed: onSchedulePressed,
            icon: const Icon(TablerIcons.plus, size: 18),
            label: const Text('Schedule Task'),
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.large,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.five,
                vertical: AppSpacing.four,
              ),
              minimumSize: const Size(0, 52),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.one),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calendar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.titleText,
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
          const SizedBox(height: AppSpacing.one),
          Text(
            'View and manage your scheduled tasks',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.subHeaderText,
              fontSize: AppTypography.sizeBase,
              fontWeight: AppTypography.weightNormal,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthPicker extends StatelessWidget {
  const _CalendarMonthPicker({
    required this.buttonKey,
    required this.selectedMonth,
    required this.onSelected,
  });

  final Key buttonKey;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: buttonKey,
      initialValue: selectedMonth.month,
      color: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      onSelected: (value) => onSelected(DateTime(selectedMonth.year, value, 1)),
      itemBuilder: (context) => List.generate(12, (index) {
        final month = index + 1;
        return PopupMenuItem<int>(value: month, child: Text(_monthName(month)));
      }),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.three),
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _monthName(selectedMonth.month),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.titleText,
                  fontSize: AppTypography.sizeBase,
                ),
              ),
            ),
            const Icon(
              TablerIcons.chevron_down,
              size: 18,
              color: AppColors.subHeaderText,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarStatusRow extends StatelessWidget {
  const _CalendarStatusRow({
    required this.selectedFilter,
    required this.onSelected,
    required this.chipKeyBuilder,
  });

  final TaskStatusFilter selectedFilter;
  final ValueChanged<TaskStatusFilter> onSelected;
  final Key Function(String value) chipKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final filters = <(TaskStatusFilter, String, String)>[
      (TaskStatusFilter.all, 'All Status', 'all'),
      (TaskStatusFilter.completed, 'Completed', 'completed'),
      (TaskStatusFilter.today, 'Today', 'today'),
      (TaskStatusFilter.upcoming, 'Upcoming', 'upcoming'),
      (TaskStatusFilter.overdue, 'Overdue', 'overdue'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.oneAndHalf),
            child: InkWell(
              key: chipKeyBuilder(filter.$3),
              onTap: () => onSelected(filter.$1),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.three,
                  vertical: AppSpacing.two,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryButtonFill
                      : AppColors.cardFill,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryButtonFill
                        : AppColors.neutral200,
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primaryButtonText
                        : AppColors.subHeaderText,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: AppTypography.weightNormal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskCalendarDateRail extends StatelessWidget {
  const _TaskCalendarDateRail({
    required this.selectedMonth,
    required this.selectedDate,
    required this.availableDays,
    required this.onSelected,
    required this.dateKeyBuilder,
  });

  final DateTime selectedMonth;
  final DateTime selectedDate;
  final List<DateTime> availableDays;
  final ValueChanged<DateTime> onSelected;
  final Key Function(String value) dateKeyBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: availableDays.map((day) {
          final isSelected =
              day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;
          final keyValue =
              '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.oneAndHalf),
            child: InkWell(
              key: dateKeyBuilder(keyValue),
              onTap: () => onSelected(day),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: Container(
                width: 54,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.twoAndHalf,
                  vertical: AppSpacing.four,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blue100 : AppColors.cardFill,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.blue200
                        : AppColors.cardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? AppColors.blue500
                            : AppColors.titleText,
                        fontSize: AppTypography.sizeBase,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _weekdayName(day.weekday),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? AppColors.blue500
                            : AppColors.subHeaderText,
                        fontSize: AppTypography.sizeSm,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.blue500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalendarMonthSummary extends StatelessWidget {
  const _CalendarMonthSummary({required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.titleText,
            fontSize: AppTypography.sizeLg,
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
        const SizedBox(height: AppSpacing.one),
        Text(
          'Your scheduled tasks for month of ${_monthName(selectedMonth.month).toLowerCase()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.subHeaderText,
            fontSize: AppTypography.sizeSm,
          ),
        ),
      ],
    );
  }
}

class _CalendarTimeline extends StatelessWidget {
  const _CalendarTimeline({
    required this.tasks,
    required this.categoryFor,
    required this.selectedDate,
    required this.onTaskTap,
  });

  final List<TaskItem> tasks;
  final TaskCategory? Function(String categoryId) categoryFor;
  final DateTime selectedDate;
  final ValueChanged<TaskItem> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final timelineHours = _buildTimelineHours(tasks);
    const rowHeight = 82.0;
    const minimumCardHeight = 86.0;
    const timelineTopInset = 18.0;
    final timelineHeight =
        timelineTopInset + (timelineHours.length - 1) * rowHeight + 78;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.four),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: tasks.isEmpty
          ? SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'No scheduled tasks for ${_monthName(selectedDate.month)} ${selectedDate.day}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.subHeaderText,
                  ),
                ),
              ),
            )
          : SizedBox(
              height: timelineHeight,
              child: Stack(
                children: [
                  ...List.generate(timelineHours.length, (index) {
                    final hour = timelineHours[index];
                    final isLongLine = hour >= 17;
                    final top = index * rowHeight;
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: top,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Text(
                              _formatHour(hour),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.subHeaderText,
                                    fontSize: AppTypography.sizeBase,
                                    height: 1,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(top: 10),
                              height: 1,
                              color: isLongLine
                                  ? AppColors.neutral200
                                  : AppColors.checkboxCardBorder,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...tasks.map((task) {
                    final category = categoryFor(task.categoryId);
                    final tone = category?.color ?? AppColors.blue500;
                    final top = _timelineTopForTask(
                      task,
                      timelineHours,
                      rowHeight,
                      timelineTopInset,
                    );
                    final height = _timelineHeightForTask(
                      task,
                      timelineHours: timelineHours,
                      rowHeight: rowHeight,
                      timelineTopInset: timelineTopInset,
                      minimumHeight: minimumCardHeight,
                    );
                    return Positioned(
                      left: 96,
                      right: 0,
                      top: top,
                      child: SizedBox(
                        height: height,
                        child: _CalendarTaskCard(
                          task: task,
                          tone: tone,
                          category: category,
                          onTap: () => onTaskTap(task),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({
    required this.task,
    required this.tone,
    required this.category,
    required this.onTap,
  });

  final TaskItem task;
  final Color tone;
  final TaskCategory? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeBackground = _lightTone(tone);
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
                if ((task.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.two,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        category?.name ?? 'Category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle?.copyWith(
                          color: tone,
                          fontSize: 12,
                          height: 1,
                          fontWeight: AppTypography.weightMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.three),
                    Expanded(
                      child: Text(
                        _formatRange(task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: textStyle?.copyWith(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 12,
                          height: 1,
                          fontWeight: AppTypography.weightMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _lightTone(Color tone) {
  if (tone.toARGB32() == AppColors.teal500.toARGB32()) {
    return AppColors.teal50;
  }
  if (tone.toARGB32() == AppColors.rose500.toARGB32()) {
    return AppColors.rose50;
  }
  if (tone.toARGB32() == AppColors.amber500.toARGB32()) {
    return AppColors.amber50;
  }
  return AppColors.blue50;
}

String _formatHour(int hour24) {
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = switch (hour24 % 12) {
    0 => 12,
    _ => hour24 % 12,
  };
  return '${hour12.toString().padLeft(2, '0')}:00 $period';
}

String _formatRange(TaskItem task) {
  final start = task.startMinutes ?? task.endMinutes;
  final end = task.endMinutes;
  if (start == null || end == null) {
    return 'Not Set Yet';
  }
  return '${_formatCompactMinutes(start)} - ${_formatCompactMinutes(end)}';
}

String _formatCompactMinutes(int minutes) {
  final hour24 = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = switch (hour24 % 12) {
    0 => 12,
    _ => hour24 % 12,
  };
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}$period';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

String _weekdayName(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[weekday - 1];
}

double _timelineTopForTask(
  TaskItem task,
  List<int> timelineHours,
  double rowHeight,
  double timelineTopInset,
) {
  final startMinutes = task.startMinutes ?? task.endMinutes ?? 8 * 60;
  return _timelineOffsetForMinutes(
    startMinutes,
    timelineHours: timelineHours,
    rowHeight: rowHeight,
    timelineTopInset: timelineTopInset,
  );
}

double _timelineHeightForTask(
  TaskItem task, {
  required List<int> timelineHours,
  required double rowHeight,
  required double timelineTopInset,
  required double minimumHeight,
}) {
  final startMinutes = task.startMinutes ?? task.endMinutes;
  final endMinutes = task.endMinutes;
  if (startMinutes == null || endMinutes == null) {
    return minimumHeight;
  }

  final startOffset = _timelineOffsetForMinutes(
    startMinutes,
    timelineHours: timelineHours,
    rowHeight: rowHeight,
    timelineTopInset: timelineTopInset,
  );
  final endOffset = _timelineOffsetForMinutes(
    endMinutes,
    timelineHours: timelineHours,
    rowHeight: rowHeight,
    timelineTopInset: timelineTopInset,
  );
  final durationHeight = endOffset - startOffset;
  return durationHeight < minimumHeight ? minimumHeight : durationHeight;
}

double _timelineOffsetForMinutes(
  int minutes, {
  required List<int> timelineHours,
  required double rowHeight,
  required double timelineTopInset,
}) {
  final value = minutes / 60;

  if (value <= timelineHours.first) {
    return timelineTopInset;
  }
  if (value >= timelineHours.last) {
    return timelineTopInset + ((timelineHours.length - 1) * rowHeight);
  }

  for (var index = 0; index < timelineHours.length - 1; index++) {
    final startHour = timelineHours[index].toDouble();
    final endHour = timelineHours[index + 1].toDouble();
    if (value >= startHour && value <= endHour) {
      final fraction = (value - startHour) / (endHour - startHour);
      return timelineTopInset + ((index + fraction) * rowHeight);
    }
  }

  return timelineTopInset;
}

List<int> _buildTimelineHours(List<TaskItem> tasks) {
  if (tasks.isEmpty) {
    return const [8, 9, 10, 11, 12, 13, 14, 15];
  }

  final starts = tasks
      .map((task) => task.startMinutes ?? task.endMinutes)
      .whereType<int>()
      .toList();
  final ends = tasks.map((task) => task.endMinutes).whereType<int>().toList();

  if (starts.isEmpty || ends.isEmpty) {
    return const [8, 9, 10, 11, 12, 13, 14, 15];
  }

  var startHour = starts.reduce((a, b) => a < b ? a : b) ~/ 60;
  var endHour = (ends.reduce((a, b) => a > b ? a : b) / 60).ceil();

  if (startHour == endHour) {
    endHour += 1;
  }

  startHour = startHour.clamp(0, 23);
  endHour = endHour.clamp(startHour + 1, 23);

  return [for (var hour = startHour; hour <= endHour; hour++) hour];
}

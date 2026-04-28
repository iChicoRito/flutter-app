import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import 'task_management_controller.dart';
import 'task_management_ui.dart';

class TaskCalendarView extends StatefulWidget {
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
    required this.statusChipKeyBuilder,
    required this.dateKeyBuilder,
    required this.scheduleButtonKey,
    required this.timelineScrollKey,
    required this.monthHeaderKey,
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
  final Key Function(String value) statusChipKeyBuilder;
  final Key Function(String value) dateKeyBuilder;
  final Key scheduleButtonKey;
  final Key timelineScrollKey;
  final Key monthHeaderKey;

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  bool _isZoomGestureActive = false;

  void _handleZoomGestureStateChanged(bool isActive) {
    if (_isZoomGestureActive == isActive || !mounted) {
      return;
    }
    setState(() {
      _isZoomGestureActive = isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendarTasks = widget.controller.calendarTasksForDate(
      selectedDate: widget.selectedDate,
      statusFilter: widget.statusFilter,
      now: DateTime.now(),
    );

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.blue500,
          onRefresh: widget.controller.load,
          child: CustomScrollView(
            physics: _isZoomGestureActive
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
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
                    const SizedBox(height: AppSpacing.three),
                    widget.segmentControl,
                    const SizedBox(height: AppSpacing.three),
                    _CalendarStatusRow(
                      selectedFilter: widget.statusFilter,
                      onSelected: widget.onStatusSelected,
                      chipKeyBuilder: widget.statusChipKeyBuilder,
                    ),
                    const SizedBox(height: AppSpacing.six),
                    _TaskCalendarDateRail(
                      selectedMonth: widget.selectedMonth,
                      selectedDate: widget.selectedDate,
                      availableDays: widget.controller.calendarDaysForMonth(
                        widget.selectedMonth,
                      ),
                      onSelected: widget.onDateSelected,
                      dateKeyBuilder: widget.dateKeyBuilder,
                    ),
                    const SizedBox(height: AppSpacing.six),
                    _CalendarMonthSummary(
                      selectedMonth: widget.selectedMonth,
                      onMonthChanged: widget.onMonthChanged,
                      headerKey: widget.monthHeaderKey,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    _CalendarTimeline(
                      tasks: calendarTasks,
                      categoryFor: widget.controller.categoryFor,
                      selectedDate: widget.selectedDate,
                      onTaskTap: widget.onTaskTap,
                      scrollKey: widget.timelineScrollKey,
                      onZoomGestureStateChanged: _handleZoomGestureStateChanged,
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
            key: widget.scheduleButtonKey,
            onPressed: widget.onSchedulePressed,
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

class _TaskCalendarDateRail extends StatefulWidget {
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
  State<_TaskCalendarDateRail> createState() => _TaskCalendarDateRailState();
}

class _TaskCalendarDateRailState extends State<_TaskCalendarDateRail> {
  final GlobalKey _selectedItemKey = GlobalKey();
  String? _lastScrolledKeyValue;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToSelected();
  }

  @override
  void didUpdateWidget(covariant _TaskCalendarDateRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.availableDays != widget.availableDays) {
      _scheduleScrollToSelected();
    }
  }

  void _scheduleScrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final keyValue =
          '${widget.selectedDate.year.toString().padLeft(4, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';
      if (_lastScrolledKeyValue == keyValue) {
        return;
      }
      final selectedContext = _selectedItemKey.currentContext;
      if (selectedContext == null) {
        return;
      }
      _lastScrolledKeyValue = keyValue;
      Scrollable.ensureVisible(
        selectedContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.availableDays.map((day) {
          final isSelected =
              day.year == widget.selectedDate.year &&
              day.month == widget.selectedDate.month &&
              day.day == widget.selectedDate.day;
          final keyValue =
              '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

          return Padding(
            key: isSelected ? _selectedItemKey : null,
            padding: const EdgeInsets.only(right: AppSpacing.oneAndHalf),
            child: InkWell(
              key: widget.dateKeyBuilder(keyValue),
              onTap: () => widget.onSelected(day),
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

class _CalendarMonthSummary extends StatefulWidget {
  const _CalendarMonthSummary({
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.headerKey,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final Key headerKey;

  @override
  State<_CalendarMonthSummary> createState() => _CalendarMonthSummaryState();
}

class _CalendarMonthSummaryState extends State<_CalendarMonthSummary> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final months = List<DateTime>.generate(
      12,
      (index) => DateTime(widget.selectedMonth.year, index + 1, 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopupMenuButton<DateTime>(
          key: widget.headerKey,
          tooltip: '',
          elevation: 2,
          color: AppColors.cardFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          offset: const Offset(0, 8),
          padding: EdgeInsets.zero,
          onOpened: () {
            if (mounted) {
              setState(() {
                _isMenuOpen = true;
              });
            }
          },
          onCanceled: () {
            if (mounted) {
              setState(() {
                _isMenuOpen = false;
              });
            }
          },
          onSelected: (value) {
            setState(() {
              _isMenuOpen = false;
            });
            widget.onMonthChanged(value);
          },
          itemBuilder: (context) => months.map((month) {
            final isSelected =
                month.year == widget.selectedMonth.year &&
                month.month == widget.selectedMonth.month;
            return PopupMenuItem<DateTime>(
              value: month,
              child: Text(
                _monthName(month.month),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? AppColors.primaryBadgeText
                      : AppColors.titleText,
                  fontSize: AppTypography.sizeSm,
                ),
              ),
            );
          }).toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMenuOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.titleText,
                ),
                const SizedBox(width: AppSpacing.one),
                Text(
                  '${_monthName(widget.selectedMonth.month)} ${widget.selectedMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.titleText,
                    fontSize: AppTypography.sizeLg,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarTimeline extends StatefulWidget {
  const _CalendarTimeline({
    required this.tasks,
    required this.categoryFor,
    required this.selectedDate,
    required this.onTaskTap,
    required this.scrollKey,
    required this.onZoomGestureStateChanged,
  });

  final List<TaskItem> tasks;
  final TaskCategory? Function(String categoryId) categoryFor;
  final DateTime selectedDate;
  final ValueChanged<TaskItem> onTaskTap;
  final Key scrollKey;
  final ValueChanged<bool> onZoomGestureStateChanged;

  @override
  State<_CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<_CalendarTimeline> {
  static const double _minZoom = 0.75;
  static const double _maxZoom = 1.75;
  static const double _zoomSensitivity = 0.45;
  static const double _zoomDeadZone = 0.03;

  double _verticalZoom = 1.0;
  double _scaleStartVerticalZoom = 1.0;
  int _activePointers = 0;

  void _updateZoomGestureState() {
    widget.onZoomGestureStateChanged(_activePointers >= 2);
  }

  @override
  void dispose() {
    widget.onZoomGestureStateChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timelineHours = _buildTimelineHours(widget.tasks);
    final rowHeight = 82.0 * _verticalZoom;
    final minimumCardHeight = 86.0 * _verticalZoom;
    const timelineTopInset = 18.0;
    final taskLayouts = _buildTaskLayouts(
      widget.tasks,
      timelineHours: timelineHours,
      rowHeight: rowHeight,
      timelineTopInset: timelineTopInset,
      minimumHeight: minimumCardHeight,
    );
    final timelineHeight =
        timelineTopInset + (timelineHours.length - 1) * rowHeight + 78;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.four),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: widget.tasks.isEmpty
          ? SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'No scheduled tasks for ${_monthName(widget.selectedDate.month)} ${widget.selectedDate.day}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.subHeaderText,
                  ),
                ),
              ),
            )
          : Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                _activePointers += 1;
                _updateZoomGestureState();
              },
              onPointerUp: (event) {
                if (_activePointers > 0) {
                  _activePointers -= 1;
                }
                _updateZoomGestureState();
              },
              onPointerCancel: (event) {
                if (_activePointers > 0) {
                  _activePointers -= 1;
                }
                _updateZoomGestureState();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  _scaleStartVerticalZoom = _verticalZoom;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount < 2) {
                    return;
                  }
                  final verticalScale = dampenCalendarZoomScale(
                    details.verticalScale,
                    sensitivity: _zoomSensitivity,
                    deadZone: _zoomDeadZone,
                  );
                  final nextVerticalZoom =
                      (_scaleStartVerticalZoom * verticalScale).clamp(
                        _minZoom,
                        _maxZoom,
                      );
                  if (nextVerticalZoom == _verticalZoom) {
                    return;
                  }
                  setState(() {
                    _verticalZoom = nextVerticalZoom;
                  });
                },
                onScaleEnd: (details) {
                  widget.onZoomGestureStateChanged(false);
                },
                child: SizedBox(
                  height: timelineHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const timeLabelWidth = 52.0;
                      const timeLabelGap = 8.0;
                      const laneLeft = timeLabelWidth + timeLabelGap;
                      const columnGap = 4.0;
                      final availableLaneWidth =
                          constraints.maxWidth - laneLeft;
                      final maximumGroupLaneWidth = taskLayouts.isEmpty
                          ? 220.0
                          : taskLayouts
                                .map((layout) {
                                  return calendarGroupLaneWidth(
                                    columnCount: layout.columnCount,
                                    availableLaneWidth: availableLaneWidth,
                                    columnGap: columnGap,
                                  );
                                })
                                .reduce((a, b) => a > b ? a : b);
                      final canvasWidth =
                          constraints.maxWidth >
                              (laneLeft + maximumGroupLaneWidth)
                          ? constraints.maxWidth
                          : (laneLeft + maximumGroupLaneWidth);

                      return SingleChildScrollView(
                        key: widget.scrollKey,
                        scrollDirection: Axis.horizontal,
                        physics: _activePointers >= 2
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        child: SizedBox(
                          key: const ValueKey('calendar_timeline_canvas'),
                          width: canvasWidth,
                          height: timelineHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: timeLabelWidth,
                                        child: Text(
                                          _formatHour(hour),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.subHeaderText,
                                                fontSize:
                                                    AppTypography.sizeBase,
                                                height: 1,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: 10,
                                          ),
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
                              ...taskLayouts.map((layout) {
                                final category = widget.categoryFor(
                                  layout.task.categoryId,
                                );
                                final tone =
                                    category?.color ?? AppColors.blue500;
                                final columnCount = layout.columnCount;
                                final totalGapWidth =
                                    columnGap * (columnCount - 1);
                                final groupLaneWidth = calendarGroupLaneWidth(
                                  columnCount: columnCount,
                                  availableLaneWidth: availableLaneWidth,
                                  columnGap: columnGap,
                                );
                                final columnWidth =
                                    (groupLaneWidth - totalGapWidth) /
                                    columnCount;
                                final left =
                                    laneLeft +
                                    (layout.columnIndex *
                                        (columnWidth + columnGap));

                                return Positioned(
                                  left: left,
                                  top: layout.top,
                                  width: columnWidth,
                                  child: SizedBox(
                                    height: layout.height,
                                    child: _CalendarTaskCard(
                                      task: layout.task,
                                      tone: tone,
                                      category: category,
                                      preferCompactLayout: columnCount > 1,
                                      onTap: () =>
                                          widget.onTaskTap(layout.task),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _CalendarTaskLayout {
  const _CalendarTaskLayout({
    required this.task,
    required this.top,
    required this.height,
    required this.columnIndex,
    required this.columnCount,
  });

  final TaskItem task;
  final double top;
  final double height;
  final int columnIndex;
  final int columnCount;
}

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({
    required this.task,
    required this.tone,
    required this.category,
    required this.preferCompactLayout,
    required this.onTap,
  });

  final TaskItem task;
  final Color tone;
  final TaskCategory? category;
  final bool preferCompactLayout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeBackground = _lightTone(tone);
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('calendar_task_${task.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentMode = resolveCalendarTaskContentMode(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                preferCompact: preferCompactLayout,
              );
              if (contentMode == CalendarTaskContentMode.hidden) {
                return const SizedBox.expand();
              }
              if (contentMode == CalendarTaskContentMode.compact) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatCompactMinutes(task.startMinutes ?? 0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11,
                          height: 1,
                          fontWeight: AppTypography.weightMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.1,
                          fontWeight: AppTypography.weightSemibold,
                        ),
                      ),
                      const Spacer(),
                      _CalendarTaskBadge(
                        category: category,
                        badgeBackground: badgeBackground,
                        tone: tone,
                        textStyle: textStyle,
                      ),
                    ],
                  ),
                );
              }

              final showDescription =
                  (task.description ?? '').isNotEmpty &&
                  constraints.maxHeight >= 100;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatRange(task),
                      maxLines: 1,
                      style: textStyle?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        height: 1,
                        fontWeight: AppTypography.weightMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    if (showDescription) ...[
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
                    _CalendarTaskBadge(
                      category: category,
                      badgeBackground: badgeBackground,
                      tone: tone,
                      textStyle: textStyle,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CalendarTaskBadge extends StatelessWidget {
  const _CalendarTaskBadge({
    required this.category,
    required this.badgeBackground,
    required this.tone,
    required this.textStyle,
  });

  final TaskCategory? category;
  final Color badgeBackground;
  final Color tone;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  final normalizedHour = hour24 % 24;
  final period = normalizedHour >= 12 ? 'PM' : 'AM';
  final hour12 = switch (normalizedHour % 12) {
    0 => 12,
    _ => normalizedHour % 12,
  };
  return '$hour12$period';
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

List<_CalendarTaskLayout> _buildTaskLayouts(
  List<TaskItem> tasks, {
  required List<int> timelineHours,
  required double rowHeight,
  required double timelineTopInset,
  required double minimumHeight,
}) {
  if (tasks.isEmpty) {
    return const [];
  }

  final sortedTasks = [...tasks]
    ..sort((a, b) {
      final startComparison = _effectiveStartMinutes(
        a,
      ).compareTo(_effectiveStartMinutes(b));
      if (startComparison != 0) {
        return startComparison;
      }

      final durationComparison = _effectiveDurationMinutes(
        b,
      ).compareTo(_effectiveDurationMinutes(a));
      if (durationComparison != 0) {
        return durationComparison;
      }

      final idComparison = a.id.compareTo(b.id);
      if (idComparison != 0) {
        return idComparison;
      }

      return a.title.compareTo(b.title);
    });

  final layouts = <_CalendarTaskLayout>[];
  var groupTasks = <TaskItem>[];
  var groupMaxEnd = 0;

  for (final task in sortedTasks) {
    final start = _effectiveStartMinutes(task);
    final end = _effectiveEndMinutes(task);

    if (groupTasks.isEmpty) {
      groupTasks = [task];
      groupMaxEnd = end;
      continue;
    }

    if (start < groupMaxEnd) {
      groupTasks.add(task);
      if (end > groupMaxEnd) {
        groupMaxEnd = end;
      }
      continue;
    }

    layouts.addAll(
      _buildTaskLayoutsForGroup(
        groupTasks,
        timelineHours: timelineHours,
        rowHeight: rowHeight,
        timelineTopInset: timelineTopInset,
        minimumHeight: minimumHeight,
      ),
    );
    groupTasks = [task];
    groupMaxEnd = end;
  }

  if (groupTasks.isNotEmpty) {
    layouts.addAll(
      _buildTaskLayoutsForGroup(
        groupTasks,
        timelineHours: timelineHours,
        rowHeight: rowHeight,
        timelineTopInset: timelineTopInset,
        minimumHeight: minimumHeight,
      ),
    );
  }

  return layouts;
}

List<_CalendarTaskLayout> _buildTaskLayoutsForGroup(
  List<TaskItem> tasks, {
  required List<int> timelineHours,
  required double rowHeight,
  required double timelineTopInset,
  required double minimumHeight,
}) {
  const stackedTaskGap = 4.0;
  final columnEndMinutes = <int>[];
  final assignedColumns = <TaskItem, int>{};
  final columnTaskCounts = <int>[];
  final assignedTopOffsets = <TaskItem, double>{};

  for (final task in tasks) {
    final start = _effectiveStartMinutes(task);
    final end = _effectiveEndMinutes(task);
    var assignedColumn = -1;

    for (var index = 0; index < columnEndMinutes.length; index++) {
      if (start >= columnEndMinutes[index]) {
        assignedColumn = index;
        columnEndMinutes[index] = end;
        break;
      }
    }

    if (assignedColumn == -1) {
      assignedColumn = columnEndMinutes.length;
      columnEndMinutes.add(end);
      columnTaskCounts.add(0);
    }

    assignedColumns[task] = assignedColumn;
    assignedTopOffsets[task] =
        columnTaskCounts[assignedColumn] * stackedTaskGap;
    columnTaskCounts[assignedColumn] = columnTaskCounts[assignedColumn] + 1;
  }

  final columnCount = columnEndMinutes.length;
  return tasks.map((task) {
    return _CalendarTaskLayout(
      task: task,
      top:
          _timelineTopForTask(
            task,
            timelineHours,
            rowHeight,
            timelineTopInset,
          ) +
          assignedTopOffsets[task]!,
      height: _timelineHeightForTask(
        task,
        timelineHours: timelineHours,
        rowHeight: rowHeight,
        timelineTopInset: timelineTopInset,
        minimumHeight: minimumHeight,
      ),
      columnIndex: assignedColumns[task]!,
      columnCount: columnCount,
    );
  }).toList();
}

int _effectiveStartMinutes(TaskItem task) {
  return task.startMinutes ?? task.endMinutes ?? 8 * 60;
}

int _effectiveEndMinutes(TaskItem task) {
  final start = _effectiveStartMinutes(task);
  return task.endMinutes ?? (start + 30);
}

int _effectiveDurationMinutes(TaskItem task) {
  return _effectiveEndMinutes(task) - _effectiveStartMinutes(task);
}

enum CalendarTaskContentMode { hidden, compact, detailed }

CalendarTaskContentMode resolveCalendarTaskContentMode({
  required double width,
  required double height,
  bool preferCompact = false,
}) {
  if (width < 88 || height < 72) {
    return CalendarTaskContentMode.hidden;
  }
  if (preferCompact || width < 148 || height < 84) {
    return CalendarTaskContentMode.compact;
  }
  return CalendarTaskContentMode.detailed;
}

double calendarGroupLaneWidth({
  required int columnCount,
  required double availableLaneWidth,
  required double columnGap,
  double preferredOverlapColumnWidth = 176.0,
}) {
  if (columnCount <= 1) {
    return availableLaneWidth;
  }

  final preferredWidth =
      (preferredOverlapColumnWidth * columnCount) +
      (columnGap * (columnCount - 1));
  return preferredWidth;
}

double dampenCalendarZoomScale(
  double rawScale, {
  double sensitivity = 0.45,
  double deadZone = 0.03,
}) {
  final delta = rawScale - 1;
  if (delta.abs() <= deadZone) {
    return 1;
  }
  return 1 + (delta * sensitivity);
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
  endHour = endHour.clamp(startHour + 1, 24);

  return [for (var hour = startHour; hour <= endHour; hour++) hour];
}

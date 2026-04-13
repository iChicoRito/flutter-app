import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_repository_scope.dart';
import '../../task_management/presentation/task_management_screen.dart';
import '../domain/dashboard_task.dart';
import '../domain/dashboard_task_seed.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const Key markerKey = Key('dashboard-screen');
  static const Key homeTabKey = Key('dashboard-home-tab');
  static const Key tasksTabKey = Key('dashboard-tasks-tab');
  static const Key addTaskButtonKey = Key('dashboard-add-task');
  static const Key todayHeaderKey = Key('dashboard-today-header');
  static const Key upcomingHeaderKey = Key('dashboard-upcoming-header');
  static const Key overdueHeaderKey = Key('dashboard-overdue-header');
  static const Key completedHeaderKey = Key('dashboard-completed-header');
  static const Key progressLabelKey = Key('dashboard-progress-label');

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');
  static Key summaryCountKey(String label) => Key('summary-count-$label');

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum DashboardFilter { all, pending, completed, overdue }

const _primaryBlue = Color(0xFF1E88E5);
const _secondaryBlue = Color(0xFF90CAF9);
const _badgePrimaryBg = Color(0xFFE6F0FA);
const _badgePrimaryText = Color(0xFF066FD1);
const _badgeSecondaryText = Color(0xFF6B7280);
const _successBg = Color(0xFFE6F6F1);
const _successText = Color(0xFF0CA678);
const _warningBg = Color(0xFFFEF5E5);
const _warningText = Color(0xFFF59F00);
const _dangerBg = Color(0xFFFBEBEB);
const _dangerText = Color(0xFFD63939);
const _darkText = Color(0xFF1F2937);
const _borderColor = Color(0xFFE5E8EC);

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _isTodayExpanded = true;
  bool _isUpcomingExpanded = true;
  bool _isOverdueExpanded = true;
  bool _isCompletedExpanded = false;
  late List<DashboardTask> _tasks = seededDashboardTasks;

  static const List<_DashboardTab> _tabs = [
    _DashboardTab(
      label: 'Home',
      assetPath: 'assets/icons/home_filled.svg',
      title: 'Dashboard Home',
      description: 'Placeholder content for the main dashboard view.',
    ),
    _DashboardTab(
      label: 'Tasks',
      icon: TablerIcons.checklist,
      title: 'Task Management',
      description: 'Your offline task, note, and reminder hub.',
    ),
    _DashboardTab(
      label: 'Analysis',
      assetPath: 'assets/icons/chart_pie_filled.svg',
      title: 'Analysis',
      description: 'Placeholder content for insights and trends.',
    ),
    _DashboardTab(
      label: 'Profile',
      assetPath: 'assets/icons/user_filled.svg',
      title: 'Profile',
      description: 'Placeholder content for user profile and settings.',
    ),
  ];

  void _toggleTaskCompletion(String taskId) {
    setState(() {
      _tasks = _tasks.map((task) {
        if (task.id != taskId) {
          return task;
        }

        final nextCompleted = !task.isCompleted;
        return task.copyWith(
          isCompleted: nextCompleted,
          bucket: nextCompleted ? TaskBucket.completed : TaskBucket.today,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = _tabs[_currentIndex];
    final taskRepository = TaskRepositoryScope.of(context);

    return Scaffold(
      key: DashboardScreen.markerKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _currentIndex == 0
            ? _DashboardHomeTab(
                key: DashboardScreen.homeTabKey,
                theme: theme,
                tasks: _tasks,
                isTodayExpanded: _isTodayExpanded,
                isUpcomingExpanded: _isUpcomingExpanded,
                isOverdueExpanded: _isOverdueExpanded,
                isCompletedExpanded: _isCompletedExpanded,
                onTaskToggled: _toggleTaskCompletion,
                onTodayExpandedChanged: () {
                  setState(() {
                    _isTodayExpanded = !_isTodayExpanded;
                  });
                },
                onUpcomingExpandedChanged: () {
                  setState(() {
                    _isUpcomingExpanded = !_isUpcomingExpanded;
                  });
                },
                onOverdueExpandedChanged: () {
                  setState(() {
                    _isOverdueExpanded = !_isOverdueExpanded;
                  });
                },
                onCompletedExpandedChanged: () {
                  setState(() {
                    _isCompletedExpanded = !_isCompletedExpanded;
                  });
                },
              )
            : _currentIndex == 1
            ? KeyedSubtree(
                key: DashboardScreen.tasksTabKey,
                child: TaskManagementScreen(repository: taskRepository),
              )
            : _PlaceholderTab(tab: tab, theme: theme),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              key: DashboardScreen.addTaskButtonKey,
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Quick add is ready for the next task flow.',
                      ),
                    ),
                  );
              },
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onChanged: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
      ),
    );
  }
}

class _DashboardTab {
  const _DashboardTab({
    required this.label,
    required this.title,
    required this.description,
    this.assetPath,
    this.icon,
  }) : assert(assetPath != null || icon != null);

  final String label;
  final String? assetPath;
  final IconData? icon;
  final String title;
  final String description;
}

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab({
    super.key,
    required this.theme,
    required this.tasks,
    required this.isTodayExpanded,
    required this.isUpcomingExpanded,
    required this.isOverdueExpanded,
    required this.isCompletedExpanded,
    required this.onTaskToggled,
    required this.onTodayExpandedChanged,
    required this.onUpcomingExpandedChanged,
    required this.onOverdueExpandedChanged,
    required this.onCompletedExpandedChanged,
  });

  final ThemeData theme;
  final List<DashboardTask> tasks;
  final bool isTodayExpanded;
  final bool isUpcomingExpanded;
  final bool isOverdueExpanded;
  final bool isCompletedExpanded;
  final ValueChanged<String> onTaskToggled;
  final VoidCallback onTodayExpandedChanged;
  final VoidCallback onUpcomingExpandedChanged;
  final VoidCallback onOverdueExpandedChanged;
  final VoidCallback onCompletedExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final pendingCount = tasks
        .where((task) => !task.isCompleted && !task.isOverdue)
        .length;
    final completedCount = tasks.where((task) => task.isCompleted).length;
    final overdueCount = tasks
        .where((task) => task.isOverdue && !task.isCompleted)
        .length;

    final todayTasks = _sortedTasks(_tasksForBucket(TaskBucket.today));
    final tomorrowTasks = _sortedTasks(_tasksForBucket(TaskBucket.tomorrow));
    final thisWeekTasks = _sortedTasks(_tasksForBucket(TaskBucket.thisWeek));
    final laterTasks = _sortedTasks(_tasksForBucket(TaskBucket.later));
    final overdueTasks = _sortedTasks(_tasksForBucket(TaskBucket.overdue));
    final completedTasks = _sortedTasks(
      tasks.where((task) => task.isCompleted).toList(),
    );

    final todayProgressTotal = tasks
        .where((task) => task.bucket == TaskBucket.today || task.isCompleted)
        .length;
    final todayCompleted = completedCount;
    final progressValue = todayProgressTotal == 0
        ? 0.0
        : todayCompleted / todayProgressTotal;

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _HeaderRow(
            theme: theme,
            dateLabel: _formatDate(DateTime.now()),
            message: _buildContextMessage(
              DateTime.now(),
              pendingCount + overdueCount,
              overdueCount,
            ),
          ),
          const SizedBox(height: 20),
          _ProgressCard(
            completedCount: todayCompleted,
            totalCount: todayProgressTotal,
            progressValue: progressValue,
          ),
          const SizedBox(height: 16),
          _SummaryGrid(
            totalCount: tasks.length,
            pendingCount: pendingCount,
            completedCount: completedCount,
            overdueCount: overdueCount,
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Today\'s Tasks',
            subtitle: 'What needs your attention right now.',
            isExpanded: isTodayExpanded,
            headerKey: DashboardScreen.todayHeaderKey,
            onHeaderTap: onTodayExpandedChanged,
            trailing: _ExpandTrailing(
              countLabel: '${todayTasks.length}',
              countBackgroundColor: _badgePrimaryBg,
              countTextColor: _badgePrimaryText,
              isExpanded: isTodayExpanded,
            ),
            child: _AnimatedSectionBody(
              isExpanded: isTodayExpanded,
              child: todayTasks.isEmpty
                  ? const _EmptyState(
                      title: 'No tasks in this view',
                      message:
                          'Try another filter or add a task to shape the rest of your day.',
                    )
                  : Column(
                      children: [
                        for (final task in todayTasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TaskTile(
                              task: task,
                              onToggle: () => onTaskToggled(task.id),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Upcoming',
            subtitle: 'Tomorrow, this week, and later at a glance.',
            isExpanded: isUpcomingExpanded,
            headerKey: DashboardScreen.upcomingHeaderKey,
            onHeaderTap: onUpcomingExpandedChanged,
            trailing: _ExpandTrailing(
              countLabel:
                  '${tomorrowTasks.length + thisWeekTasks.length + laterTasks.length}',
              countBackgroundColor: _warningBg,
              countTextColor: _warningText,
              isExpanded: isUpcomingExpanded,
            ),
            child: _AnimatedSectionBody(
              isExpanded: isUpcomingExpanded,
              child:
                  tomorrowTasks.isEmpty &&
                      thisWeekTasks.isEmpty &&
                      laterTasks.isEmpty
                  ? const _EmptyState(
                      title: 'Nothing upcoming',
                      message: 'Your future queue is clear for this filter.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tomorrowTasks.isNotEmpty)
                          _TaskGroup(
                            title: 'Tomorrow',
                            tasks: tomorrowTasks,
                            onTaskToggled: onTaskToggled,
                          ),
                        if (thisWeekTasks.isNotEmpty)
                          _TaskGroup(
                            title: 'This Week',
                            tasks: thisWeekTasks,
                            onTaskToggled: onTaskToggled,
                          ),
                        if (laterTasks.isNotEmpty)
                          _TaskGroup(
                            title: 'Later',
                            tasks: laterTasks,
                            onTaskToggled: onTaskToggled,
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Overdue',
            subtitle: 'These need recovery first.',
            isExpanded: isOverdueExpanded,
            headerKey: DashboardScreen.overdueHeaderKey,
            onHeaderTap: onOverdueExpandedChanged,
            trailing: _ExpandTrailing(
              countLabel: '${overdueTasks.length}',
              countBackgroundColor: _dangerBg,
              countTextColor: _dangerText,
              isExpanded: isOverdueExpanded,
            ),
            child: _AnimatedSectionBody(
              isExpanded: isOverdueExpanded,
              child: overdueTasks.isEmpty
                  ? const _EmptyState(
                      title: 'No overdue tasks',
                      message: 'You are caught up on everything past due.',
                    )
                  : Column(
                      children: [
                        for (final task in overdueTasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TaskTile(
                              task: task,
                              onToggle: () => onTaskToggled(task.id),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Completed',
            subtitle: 'Collapsed by default so the focus stays on active work.',
            isExpanded: isCompletedExpanded,
            headerKey: DashboardScreen.completedHeaderKey,
            onHeaderTap: onCompletedExpandedChanged,
            trailing: _ExpandTrailing(
              countLabel: '$completedCount',
              countBackgroundColor: _successBg,
              countTextColor: _successText,
              isExpanded: isCompletedExpanded,
            ),
            child: _AnimatedSectionBody(
              isExpanded: isCompletedExpanded,
              child: completedTasks.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _EmptyState(
                        title: 'Nothing completed yet',
                        message:
                            'Completed tasks will appear here as you check them off.',
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          for (final task in completedTasks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TaskTile(
                                task: task,
                                onToggle: () => onTaskToggled(task.id),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<DashboardTask> _tasksForBucket(TaskBucket bucket) =>
      tasks.where((task) => task.bucket == bucket).toList();

  List<DashboardTask> _sortedTasks(List<DashboardTask> values) {
    final sorted = [...values];
    sorted.sort((a, b) {
      final pinnedCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinnedCompare != 0) {
        return pinnedCompare;
      }

      final priorityCompare = _priorityWeight(
        b.priority,
      ).compareTo(_priorityWeight(a.priority));
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return (a.timeLabel ?? '').compareTo(b.timeLabel ?? '');
    });
    return sorted;
  }

  int _priorityWeight(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.high => 3,
      TaskPriority.medium => 2,
      TaskPriority.low => 1,
    };
  }

  String _buildContextMessage(DateTime now, int taskCount, int overdueCount) {
    if (overdueCount > 0) {
      return 'You have $overdueCount overdue ${overdueCount == 1 ? 'task' : 'tasks'} to rescue first.';
    }

    if (now.hour < 12) {
      return 'You have $taskCount ${taskCount == 1 ? 'task' : 'tasks'} today.';
    }

    return '$taskCount ${taskCount == 1 ? 'task is' : 'tasks are'} left before you can wrap up.';
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.theme,
    required this.dateLabel,
    required this.message,
  });

  final ThemeData theme;
  final String dateLabel;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _badgePrimaryBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(TablerIcons.checklist, color: _badgePrimaryText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, Mark',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _badgeSecondaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _darkText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: const Icon(TablerIcons.bell, color: _badgeSecondaryText),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completedCount,
    required this.totalCount,
    required this.progressValue,
  });

  final int completedCount;
  final int totalCount;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$completedCount of $totalCount tasks completed today',
            key: DashboardScreen.progressLabelKey,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: _secondaryBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalCount,
    required this.pendingCount,
    required this.completedCount,
    required this.overdueCount,
  });

  final int totalCount;
  final int pendingCount;
  final int completedCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.18,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          label: 'Total',
          count: totalCount,
          icon: TablerIcons.list_details,
          backgroundColor: _badgePrimaryBg,
          textColor: _badgePrimaryText,
        ),
        _SummaryCard(
          label: 'Pending',
          count: pendingCount,
          icon: TablerIcons.clock_hour_8,
          backgroundColor: _warningBg,
          textColor: _warningText,
        ),
        _SummaryCard(
          label: 'Completed',
          count: completedCount,
          icon: TablerIcons.circle_check,
          backgroundColor: _successBg,
          textColor: _successText,
        ),
        _SummaryCard(
          label: 'Overdue',
          count: overdueCount,
          icon: TablerIcons.alert_circle,
          backgroundColor: _dangerBg,
          textColor: _dangerText,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _badgeSecondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            key: DashboardScreen.summaryCountKey(label),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.isExpanded,
    this.headerKey,
    this.onHeaderTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool? isExpanded;
  final Key? headerKey;
  final VoidCallback? onHeaderTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: headerKey,
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _darkText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _badgeSecondaryText,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ...(trailing != null ? [trailing!] : const <Widget>[]),
                ],
              ),
            ),
          ),
          if (isExpanded != false) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: _borderColor),
            const SizedBox(height: 18),
            Padding(padding: const EdgeInsets.only(bottom: 6), child: child),
          ],
        ],
      ),
    );
  }
}

class _ExpandTrailing extends StatelessWidget {
  const _ExpandTrailing({
    required this.countLabel,
    required this.countBackgroundColor,
    required this.countTextColor,
    required this.isExpanded,
  });

  final String countLabel;
  final Color countBackgroundColor;
  final Color countTextColor;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToneBadge(
          label: countLabel,
          backgroundColor: countBackgroundColor,
          textColor: countTextColor,
        ),
        const SizedBox(width: 8),
        AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          child: const Icon(
            Icons.expand_more_rounded,
            color: _badgeSecondaryText,
          ),
        ),
      ],
    );
  }
}

class _AnimatedSectionBody extends StatelessWidget {
  const _AnimatedSectionBody({required this.isExpanded, required this.child});

  final bool isExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isExpanded ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        child: child,
        builder: (context, value, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: value,
            child: child,
          );
        },
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.title,
    required this.tasks,
    required this.onTaskToggled,
  });

  final String title;
  final List<DashboardTask> tasks;
  final ValueChanged<String> onTaskToggled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskTile(
                task: task,
                onToggle: () => onTaskToggled(task.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final DashboardTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final toneData = switch (task.priority) {
      TaskPriority.high => (_dangerBg, _dangerText, 'High priority'),
      TaskPriority.medium => (_warningBg, _warningText, 'Pending'),
      TaskPriority.low => (_successBg, _successText, 'Low priority'),
    };

    final backgroundColor = task.isOverdue
        ? _dangerBg
        : task.isCompleted
        ? _successBg
        : Colors.white;
    final borderColor = task.isOverdue
        ? _dangerText.withValues(alpha: 0.35)
        : task.isCompleted
        ? _successText.withValues(alpha: 0.3)
        : _borderColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Theme(
              data: Theme.of(context).copyWith(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Checkbox(
                key: DashboardScreen.taskToggleKey(task.id),
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                activeColor: _successText,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _darkText,
                          fontWeight: FontWeight.w700,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (task.isPinned)
                      const Icon(
                        TablerIcons.pin_filled,
                        size: 16,
                        color: _badgePrimaryText,
                      ),
                  ],
                ),
                if (task.timeLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.timeLabel!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _badgeSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToneBadge(
                      label: toneData.$3,
                      backgroundColor: toneData.$1,
                      textColor: toneData.$2,
                    ),
                    if (task.isOverdue)
                      const _ToneBadge(
                        label: 'Overdue',
                        backgroundColor: _dangerBg,
                        textColor: _dangerText,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneBadge extends StatelessWidget {
  const _ToneBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _darkText,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _badgeSecondaryText,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.tab, required this.theme});

  final _DashboardTab tab;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _badgePrimaryBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    TablerIcons.layout_grid,
                    color: _badgePrimaryText,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tab.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _darkText,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  tab.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _badgeSecondaryText,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onChanged,
  });

  final int currentIndex;
  final List<_DashboardTab> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1E88E5);
    const inactiveColor = Color(0xFF9AA9C4);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          const indicatorWidth = 34.0;
          final indicatorLeft =
              (tabWidth * currentIndex) + (tabWidth / 2) - (indicatorWidth / 2);

          return Container(
            height: 80,
            color: Colors.white,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: indicatorLeft,
                  top: 6,
                  child: Container(
                    width: indicatorWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(tabs.length, (index) {
                    final tab = tabs[index];
                    final isActive = index == currentIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () => onChanged(index),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (tab.assetPath != null)
                                SvgPicture.asset(
                                  tab.assetPath!,
                                  width: 26,
                                  height: 26,
                                  colorFilter: ColorFilter.mode(
                                    isActive ? activeColor : inactiveColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              if (tab.icon != null)
                                Icon(
                                  tab.icon,
                                  size: 26,
                                  color: isActive ? activeColor : inactiveColor,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                tab.label,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: isActive
                                          ? activeColor
                                          : inactiveColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

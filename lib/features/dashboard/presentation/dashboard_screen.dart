import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/display_name_store.dart';
import '../../../shared/widgets/first_run_handoff_dialogs.dart';
import '../../../core/services/task_reminder_scope.dart';
import '../../../core/services/task_repository_scope.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_access.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/presentation/task_creation_sheet.dart';
import '../../task_management/presentation/task_editor_screen.dart';
import '../../task_management/presentation/task_management_controller.dart';
import '../../task_management/presentation/task_management_screen.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../../spaces/presentation/spaces_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.displayNameStore});

  static const Key markerKey = Key('dashboard-screen');
  static const Key homeTabKey = Key('dashboard-home-tab');
  static const Key tasksTabKey = Key('dashboard-tasks-tab');
  static const Key addTaskButtonKey = Key('dashboard-add-task');
  static const Key todayHeaderKey = Key('dashboard-today-header');
  static const Key upcomingHeaderKey = Key('dashboard-upcoming-header');
  static const Key overdueHeaderKey = Key('dashboard-overdue-header');
  static const Key completedHeaderKey = Key('dashboard-completed-header');
  static const Key progressLabelKey = Key('dashboard-progress-label');
  static const Key namePromptKey = FirstRunHandoffKeys.namePrompt;
  static const Key nameFieldKey = FirstRunHandoffKeys.nameField;
  static const Key nameSaveButtonKey = FirstRunHandoffKeys.nameSaveButton;
  static const Key welcomeScreenKey = FirstRunHandoffKeys.welcomeScreen;
  static const Key welcomeButtonKey = FirstRunHandoffKeys.welcomeButton;

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');
  static Key summaryCountKey(String label) => Key('summary-count-$label');

  final DisplayNameStore displayNameStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TaskManagementController? _taskController;
  int _currentIndex = 0;
  bool _isTodayExpanded = true;
  bool _isUpcomingExpanded = true;
  bool _isOverdueExpanded = true;
  bool _isCompletedExpanded = false;
  String? _displayName;
  bool _isPromptOpen = false;

  static const List<_DashboardTab> _tabs = [
    _DashboardTab(
      label: 'Home',
      assetPath: 'assets/icons/home_filled.svg',
      title: 'Dashboard Home',
      description: 'Your live task and notes overview.',
    ),
    _DashboardTab(
      label: 'Tasks',
      assetPath: 'assets/icons/list_details_filled.svg',
      title: 'Task Management',
      description: 'Your offline task, note, and reminder hub.',
    ),
    _DashboardTab(
      label: 'Spaces',
      assetPath: 'assets/icons/briefcase_filled.svg',
      title: 'Spaces',
      description: 'Organize your task spaces and open scoped work quickly.',
    ),
    _DashboardTab(
      label: 'Profile',
      assetPath: 'assets/icons/user_filled.svg',
      title: 'Profile',
      description: 'Profile and settings will live here next.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _taskController ??= TaskManagementController(
      TaskRepositoryScope.of(context),
      reminderService: TaskReminderScope.of(context),
    )..load();
  }

  @override
  void dispose() {
    _taskController?.dispose();
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    final value = await widget.displayNameStore.readDisplayName();
    if (!mounted) {
      return;
    }

    setState(() {
      _displayName = value;
    });

    if ((value == null || value.isEmpty) && !_isPromptOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNamePrompt();
        }
      });
    }
  }

  Future<void> _showNamePrompt() async {
    if (_isPromptOpen) {
      return;
    }

    _isPromptOpen = true;
    final enteredName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DisplayNamePromptDialog(),
    );
    _isPromptOpen = false;

    final trimmed = enteredName?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) {
      return;
    }

    await widget.displayNameStore.saveDisplayName(trimmed);
    if (!mounted) {
      return;
    }

    setState(() {
      _displayName = trimmed;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeHandoffDialog(displayName: trimmed),
    );
  }

  Future<void> _openCreateFlow() async {
    final taskController = _taskController;
    if (taskController == null) {
      return;
    }
    if (taskController.categories.isEmpty) {
      await taskController.load();
      if (!mounted) {
        return;
      }
    }

    final request = await Navigator.of(context).push<TaskCreationRequest>(
      MaterialPageRoute<TaskCreationRequest>(
        builder: (context) => TaskCreationScreen(
          repository: TaskRepositoryScope.of(context),
          categories: taskController.categories,
        ),
      ),
    );
    if (request == null || !mounted) {
      return;
    }

    final vaultService = VaultServiceScope.of(context);
    final resolvedVaultConfig = await vaultService.resolveConfig(
      entityKey: 'task:create:${DateTime.now().microsecondsSinceEpoch}',
      draft: request.vaultDraft,
    );
    final task = await taskController.createTask(
      title: request.title,
      description: request.description,
      categoryId: request.categoryId,
      priority: request.priority,
      spaceId: request.spaceId,
      endDate: request.endDate,
      endMinutes: request.endMinutes,
      vaultConfig: resolvedVaultConfig,
    );

    if (!mounted) {
      return;
    }
    await _openEditor(task.id);
  }

  Future<void> _openEditor(String taskId) async {
    final repository = TaskRepositoryScope.of(context);
    final task = await repository.getTaskById(taskId);
    if (!mounted || task == null) {
      return;
    }
    final vaultService = VaultServiceScope.of(context);
    final reminderService = TaskReminderScope.of(context);
    final parentSpace = _taskController?.spaceFor(task.spaceId);
    final taskUnlockResult = await ensureUnlocked(
      context: context,
      vaultService: vaultService,
      entityKey: taskVaultEntityKey(task.id),
      title: task.title,
      entityKind: VaultEntityKind.task,
      config: task.vaultConfig,
    );
    if (!mounted) {
      return;
    }
    if (taskUnlockResult == VaultUnlockResult.failed) {
      showTaskToast(
        context,
        message: 'Incorrect vault password or PIN.',
        backgroundColor: const Color(0xFFFFEBEE),
        foregroundColor: taskDangerText,
      );
      return;
    }
    if (taskUnlockResult == VaultUnlockResult.cancelled) {
      return;
    }
    if (taskUnlockResult == VaultUnlockResult.unlocked) {
      showTaskToast(context, message: 'Unlocked successfully.');
    }
    if (task.vaultConfig == null && parentSpace != null) {
      final spaceUnlockResult = await ensureUnlocked(
          context: context,
          vaultService: vaultService,
          entityKey: spaceVaultEntityKey(parentSpace.id),
          title: parentSpace.name,
          entityKind: VaultEntityKind.space,
          config: parentSpace.vaultConfig,
      );
      if (!mounted) {
        return;
      }
      if (spaceUnlockResult == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: taskDangerText,
        );
        return;
      }
      if (spaceUnlockResult == VaultUnlockResult.cancelled) {
        return;
      }
      if (spaceUnlockResult == VaultUnlockResult.unlocked) {
        showTaskToast(context, message: 'Unlocked successfully.');
      }
    }
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => TaskEditorScreen(
          repository: repository,
          taskId: taskId,
          reminderService: reminderService,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _taskController?.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = _tabs[_currentIndex];
    final repository = TaskRepositoryScope.of(context);
    final taskController = _taskController;

    return Scaffold(
      key: DashboardScreen.markerKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _currentIndex == 0
            ? KeyedSubtree(
                key: DashboardScreen.homeTabKey,
                child: taskController == null
                    ? const SizedBox.shrink()
                    : AnimatedBuilder(
                        animation: taskController,
                        builder: (context, _) {
                          if (taskController.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return _DashboardHomeTab(
                            theme: theme,
                            displayName: _displayName,
                            controller: taskController,
                            isTodayExpanded: _isTodayExpanded,
                            isUpcomingExpanded: _isUpcomingExpanded,
                            isOverdueExpanded: _isOverdueExpanded,
                            isCompletedExpanded: _isCompletedExpanded,
                            onTaskToggled: taskController.toggleTaskCompletion,
                            onTaskOpened: (task) => _openEditor(task.id),
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
                          );
                        },
                      ),
              )
            : _currentIndex == 1
            ? KeyedSubtree(
                key: DashboardScreen.tasksTabKey,
                child: TaskManagementScreen(
                  repository: repository,
                  controller: taskController!,
                ),
              )
            : _currentIndex == 2
            ? SpacesPage(
                repository: repository,
                reminderService: TaskReminderScope.of(context),
              )
            : _currentIndex == 3
            ? _AlarmReliabilityTab(theme: theme)
            : _PlaceholderTab(tab: tab, theme: theme),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              key: DashboardScreen.addTaskButtonKey,
              onPressed: _openCreateFlow,
              backgroundColor: taskPrimaryBlue,
              foregroundColor: Colors.white,
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
    required this.theme,
    required this.displayName,
    required this.controller,
    required this.isTodayExpanded,
    required this.isUpcomingExpanded,
    required this.isOverdueExpanded,
    required this.isCompletedExpanded,
    required this.onTaskToggled,
    required this.onTaskOpened,
    required this.onTodayExpandedChanged,
    required this.onUpcomingExpandedChanged,
    required this.onOverdueExpandedChanged,
    required this.onCompletedExpandedChanged,
  });

  final ThemeData theme;
  final String? displayName;
  final TaskManagementController controller;
  final bool isTodayExpanded;
  final bool isUpcomingExpanded;
  final bool isOverdueExpanded;
  final bool isCompletedExpanded;
  final Future<void> Function(TaskItem task) onTaskToggled;
  final Future<void> Function(TaskItem task) onTaskOpened;
  final VoidCallback onTodayExpandedChanged;
  final VoidCallback onUpcomingExpandedChanged;
  final VoidCallback onOverdueExpandedChanged;
  final VoidCallback onCompletedExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tasks = controller.tasks;
    final pendingTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final overdueTasks =
        tasks
            .where(
              (task) =>
                  !task.isCompleted && task.statusAt(now) == TaskStatus.overdue,
            )
            .toList()
          ..sort((a, b) => _sortByTimeline(a, b));
    final todayTasks = tasks.where((task) => _isTodayBucket(task, now)).toList()
      ..sort((a, b) => _sortByTimeline(a, b));
    final upcomingTasks =
        tasks.where((task) => _isUpcomingBucket(task, now)).toList()
          ..sort((a, b) => _sortByTimeline(a, b));

    final progressValue = tasks.isEmpty
        ? 0.0
        : completedTasks.length / tasks.length;

    return ColoredBox(
      color: taskSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _HeaderRow(
            theme: theme,
            displayName: displayName,
            dateLabel: _formatDate(DateTime.now()),
          ),
          const SizedBox(height: 14),
          _ProgressCard(
            completedCount: completedTasks.length,
            totalCount: tasks.length,
            progressValue: progressValue,
          ),
          const SizedBox(height: 16),
          _SummaryGrid(
            totalCount: tasks.length,
            pendingCount: pendingTasks.length,
            completedCount: completedTasks.length,
            overdueCount: overdueTasks.length,
          ),
          const SizedBox(height: 18),
          _DashboardSection(
            title: 'Today\'s Tasks',
            subtitle: 'Active work and unscheduled tasks for today.',
            headerKey: DashboardScreen.todayHeaderKey,
            isExpanded: isTodayExpanded,
            count: todayTasks.length,
            toneColor: taskPrimaryBlue,
            onHeaderTap: onTodayExpandedChanged,
            child: _TaskListBody(
              tasks: todayTasks,
              controller: controller,
              emptyTitle: 'Nothing for today',
              emptyMessage:
                  'Create a task to begin a new note or plan the next step.',
              onTaskOpened: onTaskOpened,
              onTaskToggled: onTaskToggled,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSection(
            title: 'Upcoming',
            subtitle: 'Tasks scheduled after today.',
            headerKey: DashboardScreen.upcomingHeaderKey,
            isExpanded: isUpcomingExpanded,
            count: upcomingTasks.length,
            toneColor: taskWarningText,
            onHeaderTap: onUpcomingExpandedChanged,
            child: _TaskListBody(
              tasks: upcomingTasks,
              controller: controller,
              emptyTitle: 'Nothing upcoming',
              emptyMessage: 'Future scheduled tasks will appear here.',
              onTaskOpened: onTaskOpened,
              onTaskToggled: onTaskToggled,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSection(
            title: 'Overdue',
            subtitle: 'Tasks that need attention first.',
            headerKey: DashboardScreen.overdueHeaderKey,
            isExpanded: isOverdueExpanded,
            count: overdueTasks.length,
            toneColor: taskDangerText,
            onHeaderTap: onOverdueExpandedChanged,
            child: _TaskListBody(
              tasks: overdueTasks,
              controller: controller,
              emptyTitle: 'No overdue tasks',
              emptyMessage: 'You are caught up on everything past due.',
              onTaskOpened: onTaskOpened,
              onTaskToggled: onTaskToggled,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSection(
            title: 'Completed',
            subtitle: 'Finished tasks stay here for quick review.',
            headerKey: DashboardScreen.completedHeaderKey,
            isExpanded: isCompletedExpanded,
            count: completedTasks.length,
            toneColor: taskSuccessText,
            onHeaderTap: onCompletedExpandedChanged,
            child: _TaskListBody(
              tasks: completedTasks,
              controller: controller,
              emptyTitle: 'Nothing completed yet',
              emptyMessage:
                  'Completed tasks will appear here as you check them off.',
              onTaskOpened: onTaskOpened,
              onTaskToggled: onTaskToggled,
            ),
          ),
        ],
      ),
    );
  }

  static bool _isTodayBucket(TaskItem task, DateTime now) {
    if (task.isCompleted || task.statusAt(now) == TaskStatus.overdue) {
      return false;
    }

    final dueDate = task.endDate;
    if (dueDate == null) {
      return true;
    }
    return _isSameDay(dueDate, now);
  }

  static bool _isUpcomingBucket(TaskItem task, DateTime now) {
    if (task.isCompleted || task.statusAt(now) == TaskStatus.overdue) {
      return false;
    }
    final dueDate = task.endDate;
    if (dueDate == null) {
      return false;
    }
    return dueDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  static int _sortByTimeline(TaskItem left, TaskItem right) {
    final leftDate = left.endDateTime ?? left.updatedAt;
    final rightDate = right.endDateTime ?? right.updatedAt;
    return leftDate.compareTo(rightDate);
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _formatDate(DateTime date) {
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
    required this.displayName,
    required this.dateLabel,
  });

  final ThemeData theme;
  final String? displayName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _UserAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName == null || displayName!.isEmpty
                    ? 'Hi!'
                    : 'Hi, $displayName',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: taskMutedText,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(TablerIcons.bell, color: taskMutedText, size: 24),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 24,
      backgroundColor: taskAccentBlue,
      child: Icon(TablerIcons.user, color: taskPrimaryBlue, size: 24),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: taskPrimaryBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedCount of $totalCount tasks completed',
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
              backgroundColor: taskSecondaryBlue,
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
          color: taskPrimaryBlue,
        ),
        _SummaryCard(
          label: 'Pending',
          count: pendingCount,
          icon: TablerIcons.clock_hour_8,
          color: taskWarningText,
        ),
        _SummaryCard(
          label: 'Completed',
          count: completedCount,
          icon: TablerIcons.circle_check,
          color: taskSuccessText,
        ),
        _SummaryCard(
          label: 'Overdue',
          count: overdueCount,
          icon: TablerIcons.alert_circle,
          color: taskDangerText,
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
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: taskSecondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            key: DashboardScreen.summaryCountKey(label),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.subtitle,
    required this.headerKey,
    required this.isExpanded,
    required this.count,
    required this.toneColor,
    required this.onHeaderTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Key headerKey;
  final bool isExpanded;
  final int count;
  final Color toneColor;
  final VoidCallback onHeaderTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: headerKey,
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(18),
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
                              color: taskDarkText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: taskSecondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: toneColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: toneColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({
    required this.tasks,
    required this.controller,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onTaskOpened,
    required this.onTaskToggled,
  });

  final List<TaskItem> tasks;
  final TaskManagementController controller;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function(TaskItem task) onTaskOpened;
  final Future<void> Function(TaskItem task) onTaskToggled;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _DashboardEmptyState(title: emptyTitle, message: emptyMessage);
    }

    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeTaskTile(
              task: task,
              previewProtected: isPreviewProtected(
                vaultService: VaultServiceScope.of(context),
                ownVault: task.vaultConfig,
                ownEntityKey: taskVaultEntityKey(task.id),
                inheritedVault: controller.spaceFor(task.spaceId)?.vaultConfig,
                inheritedEntityKey: task.spaceId == null
                    ? null
                    : spaceVaultEntityKey(task.spaceId!),
              ),
              onOpen: () => onTaskOpened(task),
              onToggle: () => onTaskToggled(task),
            ),
          ),
      ],
    );
  }
}

class _HomeTaskTile extends StatelessWidget {
  const _HomeTaskTile({
    required this.task,
    required this.previewProtected,
    required this.onOpen,
    required this.onToggle,
  });

  final TaskItem task;
  final bool previewProtected;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final preview = previewProtected
        ? 'Protected content'
        : task.notePlainText?.trim().isNotEmpty == true
        ? task.notePlainText!.trim()
        : 'Open the note editor to add rich content.';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: taskSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: taskBorderColor),
        ),
        padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: DashboardScreen.taskToggleKey(task.id),
              value: task.isCompleted,
              onChanged: (_) => onToggle(),
              activeColor: taskSuccessText,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: taskDarkText,
                      fontWeight: FontWeight.w700,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.vaultConfig?.isEnabled == true) ...[
                    const SizedBox(height: 4),
                    const Icon(
                      TablerIcons.lock,
                      size: 14,
                      color: taskMutedText,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: taskSecondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.title, required this.message});

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
                color: taskDarkText,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: taskSecondaryText,
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
      color: taskSurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: taskBorderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: taskAccentBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    TablerIcons.layout_grid,
                    color: taskPrimaryBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tab.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: taskDarkText,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  tab.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: taskSecondaryText,
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

class _AlarmReliabilityTab extends StatelessWidget {
  const _AlarmReliabilityTab({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: taskSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: taskBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: taskAccentBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    TablerIcons.alarm,
                    color: taskPrimaryBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Alarm Reliability',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: taskDarkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep reminders more dependable by letting the app stay available in the background.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: taskSecondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, thickness: 1, color: taskBorderColor),
                const SizedBox(height: 18),
                const _ReliabilityStep(
                  icon: TablerIcons.battery_charging,
                  title: 'Turn Off Battery Restrictions',
                  body:
                      'Set the app to unrestricted or no battery optimization so Android does not delay alarms in the background.',
                ),
                const SizedBox(height: 14),
                const _ReliabilityStep(
                  icon: TablerIcons.apps,
                  title: 'Keep It In Recent Apps',
                  body:
                      'Avoid clearing flutter_app from recent apps if you want the strongest reminder reliability on many phones.',
                ),
                const SizedBox(height: 14),
                const _ReliabilityStep(
                  icon: TablerIcons.lock,
                  title: 'Allow Lock Screen Alerts',
                  body:
                      'Lock-screen notifications and full-screen notification access help the alarm show more prominently when the phone is locked.',
                ),
                const SizedBox(height: 14),
                const _ReliabilityStep(
                  icon: TablerIcons.volume,
                  title: 'Check Alarm Volume',
                  body:
                      'The due screen now plays an alarm sound, so make sure media and alarm volume are not muted on your phone.',
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: taskAccentBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        TablerIcons.info_circle,
                        color: taskPrimaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Android may still show only a notification while you are actively using another app. Lock-screen and foreground cases are the most reliable for automatic alarm takeovers.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: taskPrimaryBlue,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityStep extends StatelessWidget {
  const _ReliabilityStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: taskAccentBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: taskPrimaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: taskSecondaryText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
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
    const activeColor = taskPrimaryBlue;
    const inactiveColor = taskMutedText;

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

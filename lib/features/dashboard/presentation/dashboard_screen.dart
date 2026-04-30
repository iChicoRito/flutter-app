import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/display_name_store.dart';
import '../../../core/services/task_data_refresh_scope.dart';
import '../../../core/services/task_reminder_scope.dart';
import '../../../core/services/task_repository_scope.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_access.dart';
import '../../../shared/widgets/first_run_handoff_dialogs.dart';
import '../../archive/presentation/archives_screen.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/presentation/task_editor_screen.dart';
import '../../task_management/presentation/task_management_controller.dart';
import '../../task_management/presentation/task_management_screen.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../../spaces/presentation/spaces_page.dart';

typedef DashboardClock = DateTime Function();

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.displayNameStore,
    this.clock = DateTime.now,
  });

  static const Key markerKey = Key('dashboard-screen');
  static const Key homeTabKey = Key('dashboard-home-tab');
  static const Key tasksTabKey = Key('dashboard-tasks-tab');
  static const Key todayHeaderKey = Key('dashboard-today-header');
  static const Key upcomingHeaderKey = Key('dashboard-upcoming-header');
  static const Key overdueHeaderKey = Key('dashboard-overdue-header');
  static const Key completedHeaderKey = Key('dashboard-completed-header');
  static const Key progressLabelKey = Key('dashboard-progress-label');
  static const Key profileTabKey = Key('dashboard-profile-tab');
  static const Key profileIdentityKey = Key('dashboard-profile-identity');
  static const Key profileAvatarImageKey = Key('dashboard-profile-avatar');
  static const Key homeAvatarImageKey = Key('dashboard-home-avatar');
  static const Key profileImageButtonKey = Key('dashboard-profile-image-edit');
  static const Key profileImagePermissionDialogKey = Key(
    'dashboard-profile-image-permission',
  );
  static const Key profileImagePermissionContinueKey = Key(
    'dashboard-profile-image-permission-continue',
  );
  static const Key profileImagePermissionSecondaryKey = Key(
    'dashboard-profile-image-permission-secondary',
  );
  static const Key profileUserRowKey = Key('dashboard-profile-user-row');
  static const Key profileNameFieldKey = Key('dashboard-profile-name-field');
  static const Key profileNameSaveButtonKey = Key(
    'dashboard-profile-name-save',
  );
  static const Key profileCompletedStatKey = Key(
    'dashboard-profile-completed-stat',
  );
  static const Key profilePendingStatKey = Key(
    'dashboard-profile-pending-stat',
  );
  static const Key profileOverdueStatKey = Key(
    'dashboard-profile-overdue-stat',
  );
  static const Key profileVaultRowKey = Key('dashboard-profile-vault-row');
  static const Key profileRecoveryRowKey = Key(
    'dashboard-profile-recovery-row',
  );
  static const Key profileArchivesRowKey = Key(
    'dashboard-profile-archives-row',
  );
  static const Key namePromptKey = FirstRunHandoffKeys.namePrompt;
  static const Key nameFieldKey = FirstRunHandoffKeys.nameField;
  static const Key nameSaveButtonKey = FirstRunHandoffKeys.nameSaveButton;
  static const Key welcomeScreenKey = FirstRunHandoffKeys.welcomeScreen;
  static const Key welcomeButtonKey = FirstRunHandoffKeys.welcomeButton;

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');
  static Key summaryCountKey(String label) => Key('summary-count-$label');

  final DisplayNameStore displayNameStore;
  final DashboardClock clock;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TaskManagementController? _taskController;
  int _currentIndex = 0;
  bool _isTodayExpanded = true;
  bool _isUpcomingExpanded = true;
  bool _isOverdueExpanded = false;
  bool _isCompletedExpanded = false;
  String? _displayName;
  String? _profileImageData;
  bool _isPromptOpen = false;
  final ImagePicker _imagePicker = ImagePicker();
  TaskDataRefreshController? _taskDataRefreshController;

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
    final refreshController = TaskDataRefreshScope.of(context);
    if (_taskDataRefreshController != refreshController) {
      _taskDataRefreshController?.removeListener(_handleTaskDataRefresh);
      _taskDataRefreshController = refreshController;
      _taskDataRefreshController?.addListener(_handleTaskDataRefresh);
    }
  }

  @override
  void dispose() {
    _taskDataRefreshController?.removeListener(_handleTaskDataRefresh);
    _taskController?.dispose();
    super.dispose();
  }

  void _handleTaskDataRefresh() {
    final controller = _taskController;
    if (!mounted ||
        controller == null ||
        controller.isLoading ||
        controller.isSaving) {
      return;
    }
    controller.load();
  }

  Future<void> _loadDisplayName() async {
    final value = await widget.displayNameStore.readDisplayName();
    final imageData = await widget.displayNameStore.readProfileImageData();
    if (!mounted) {
      return;
    }

    setState(() {
      _displayName = value;
      _profileImageData = imageData;
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

  Future<void> _openProfileNameEditor() async {
    final savedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ProfileNameSheet(
          initialName: _displayName ?? '',
          onSave: (value) async {
            final trimmed = value.trim();
            await widget.displayNameStore.saveDisplayName(trimmed);
            if (!mounted) {
              return;
            }
            setState(() {
              _displayName = trimmed;
            });
          },
        );
      },
    );
    if (!mounted || savedName == null) {
      return;
    }
    showTaskToast(context, message: 'Profile name updated.');
  }

  Future<void> _pickProfileImage() async {
    final hasProfileImage =
        _profileImageData != null && _profileImageData!.isNotEmpty;
    final action = await showDialog<_ProfileImageDialogAction>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          _ProfileImagePermissionDialog(hasProfileImage: hasProfileImage),
    );
    if (!mounted ||
        action == null ||
        action == _ProfileImageDialogAction.cancel) {
      return;
    }

    if (action == _ProfileImageDialogAction.remove) {
      await widget.displayNameStore.saveProfileImageData(null);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageData = null;
      });
      showTaskToast(context, message: 'Profile photo removed successfully.');
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) {
        return;
      }

      final imageData = base64Encode(await image.readAsBytes());
      await widget.displayNameStore.saveProfileImageData(imageData);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageData = imageData;
      });
      showTaskToast(context, message: 'Profile picture updated.');
    } on MissingPluginException catch (error) {
      debugPrint('Profile image picker plugin is unavailable: $error');
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Restart the app to enable profile picture uploads.',
        isError: true,
      );
    } on PlatformException catch (error) {
      debugPrint('Profile image picker platform error: $error');
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to access your photo library.',
        isError: true,
      );
    } catch (error) {
      debugPrint('Profile image update failed: $error');
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to update profile picture.',
        isError: true,
      );
    }
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
      onRecoveryReset: (resolution) async {
        final config = resolution.config;
        if (config == null) {
          return;
        }
        await repository.upsertTask(
          task.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
        );
        await _taskController?.load();
      },
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
    if (taskUnlockResult == VaultUnlockResult.lockedOut) {
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
        onRecoveryReset: (resolution) async {
          final config = resolution.config;
          if (config == null) {
            return;
          }
          await repository.upsertSpace(
            parentSpace.copyWith(
              vaultConfig: config,
              updatedAt: DateTime.now(),
            ),
          );
          await _taskController?.load();
        },
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
      if (spaceUnlockResult == VaultUnlockResult.lockedOut) {
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

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
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
    if (!mounted) {
      return;
    }
    if (result == TaskEditorScreen.deletedResult) {
      showTaskToast(context, message: 'Task deleted successfully.');
    } else if (result == TaskEditorScreen.archivedResult) {
      showTaskToast(context, message: 'Task archived successfully.');
    }
  }

  Future<void> _openArchives() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ArchivesScreen(
          repository: TaskRepositoryScope.of(context),
          reminderService: TaskReminderScope.of(context),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _taskController?.load();
  }

  Future<void> _toggleHomeTaskCompletion(TaskItem task) async {
    final controller = _taskController;
    if (controller == null) {
      return;
    }

    await controller.toggleTaskCompletion(task);
    if (!mounted) {
      return;
    }

    showTaskToast(
      context,
      message: task.isCompleted
          ? 'Task marked as pending.'
          : 'Task completed successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = TaskRepositoryScope.of(context);
    final taskController = _taskController!;

    return Scaffold(
      key: DashboardScreen.markerKey,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            KeyedSubtree(
              key: DashboardScreen.homeTabKey,
              child: AnimatedBuilder(
                animation: taskController,
                builder: (context, _) {
                  if (taskController.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return _DashboardHomeTab(
                    theme: theme,
                    displayName: _displayName,
                    clock: widget.clock,
                    controller: taskController,
                    isTodayExpanded: _isTodayExpanded,
                    isUpcomingExpanded: _isUpcomingExpanded,
                    isOverdueExpanded: _isOverdueExpanded,
                    isCompletedExpanded: _isCompletedExpanded,
                    onTaskToggled: _toggleHomeTaskCompletion,
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
            ),
            KeyedSubtree(
              key: DashboardScreen.tasksTabKey,
              child: TaskManagementScreen(
                repository: repository,
                controller: taskController,
              ),
            ),
            SpacesPage(
              repository: repository,
              reminderService: TaskReminderScope.of(context),
            ),
            KeyedSubtree(
              key: DashboardScreen.profileTabKey,
              child: AnimatedBuilder(
                animation: taskController,
                builder: (context, _) {
                  return _ProfileTab(
                    theme: theme,
                    displayName: _displayName,
                    profileImageData: _profileImageData,
                    stats: _ProfileStats.fromController(taskController),
                    onPickProfileImage: _pickProfileImage,
                    onEditProfile: _openProfileNameEditor,
                    onOpenArchives: _openArchives,
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    required this.clock,
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
  final DashboardClock clock;
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
    final now = clock();
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
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.four,
          AppSpacing.six,
          AppSpacing.four,
          120,
        ),
        children: [
          _HeaderRow(
            theme: theme,
            greeting: _buildDashboardGreeting(
              displayName: displayName,
              now: now,
            ),
            dateLabel: _formatDate(now),
          ),
          const SizedBox(height: AppSpacing.six),
          _ProgressCard(
            completedCount: completedTasks.length,
            totalCount: tasks.length,
            progressValue: progressValue,
          ),
          const SizedBox(height: AppSpacing.three),
          _SummaryGrid(
            totalCount: tasks.length,
            pendingCount: pendingTasks.length,
            completedCount: completedTasks.length,
            overdueCount: overdueTasks.length,
          ),
          const SizedBox(height: AppSpacing.three),
          _DashboardSection(
            title: 'Today\'s Tasks',
            subtitle: 'Active tasks for today',
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
          if (upcomingTasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.three),
            _DashboardSection(
              title: 'Upcoming Tasks',
              subtitle: 'Scheduled after today',
              headerKey: DashboardScreen.upcomingHeaderKey,
              isExpanded: isUpcomingExpanded,
              count: upcomingTasks.length,
              toneColor: AppColors.amber500,
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
          ],
          const SizedBox(height: AppSpacing.three),
          _DashboardSection(
            title: 'Overdue Tasks',
            subtitle: 'Tasks that need attention',
            headerKey: DashboardScreen.overdueHeaderKey,
            isExpanded: isOverdueExpanded,
            count: overdueTasks.length,
            toneColor: AppColors.rose500,
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
          const SizedBox(height: AppSpacing.three),
          _DashboardSection(
            title: 'Completed Tasks',
            subtitle: 'Finished tasks',
            headerKey: DashboardScreen.completedHeaderKey,
            isExpanded: isCompletedExpanded,
            count: completedTasks.length,
            toneColor: AppColors.teal500,
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

String _buildDashboardGreeting({
  required String? displayName,
  required DateTime now,
}) {
  final greeting = _resolveGreetingForHour(now.hour);
  final trimmedName = displayName?.trim();
  if (trimmedName == null || trimmedName.isEmpty) {
    return greeting;
  }
  return '$greeting, $trimmedName';
}

String _resolveGreetingForHour(int hour) {
  if (hour >= 12 && hour < 18) {
    return 'Good Afternoon';
  }
  if (hour >= 18) {
    return 'Good Evening';
  }
  return 'Good Morning';
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.theme,
    required this.greeting,
    required this.dateLabel,
  });

  final ThemeData theme;
  final String greeting;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.titleText,
            fontSize: AppTypography.sizeLg,
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
        const SizedBox(height: AppSpacing.one),
        Text(
          'Manage your tasks and stay on track.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.subHeaderText,
            fontSize: AppTypography.sizeBase,
            fontWeight: AppTypography.weightNormal,
          ),
        ),
        const SizedBox(height: AppSpacing.one),
        Text(
          dateLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.subHeaderText,
            fontSize: AppTypography.sizeSm,
            fontWeight: AppTypography.weightNormal,
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.eight,
        vertical: AppSpacing.six,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryButtonFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primaryButtonText,
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
          const SizedBox(height: AppSpacing.three),
          Text(
            '$completedCount / $totalCount tasks completed',
            key: DashboardScreen.progressLabelKey,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryButtonText.withValues(alpha: 0.8),
              fontSize: AppTypography.sizeBase,
              fontWeight: AppTypography.weightNormal,
            ),
          ),
          const SizedBox(height: AppSpacing.three),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: AppColors.blue100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryButtonText,
              ),
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
      mainAxisSpacing: AppSpacing.three,
      crossAxisSpacing: AppSpacing.two,
      childAspectRatio: 1.49,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          label: 'Completed',
          count: completedCount,
          icon: TablerIcons.circle_check,
          color: AppColors.teal500,
          fillColor: AppColors.teal100,
          denominator: totalCount,
        ),
        _SummaryCard(
          label: 'Pending',
          count: pendingCount,
          icon: TablerIcons.clock_hour_8,
          color: AppColors.amber500,
          fillColor: AppColors.amber100,
          denominator: totalCount,
        ),
        _SummaryCard(
          label: 'Overdue',
          count: overdueCount,
          icon: TablerIcons.alert_circle,
          color: AppColors.rose500,
          fillColor: AppColors.rose100,
          denominator: totalCount,
        ),
        _SummaryCard(
          label: 'Total',
          count: totalCount,
          icon: TablerIcons.circle_check,
          color: AppColors.blue500,
          fillColor: AppColors.blue100,
          denominator: totalCount,
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
    required this.fillColor,
    required this.denominator,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color fillColor;
  final int denominator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.five,
        vertical: AppSpacing.four,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.three),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subHeaderText,
                        fontSize: AppTypography.sizeSm,
                        fontWeight: AppTypography.weightNormal,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.one),
                    Text(
                      '$count',
                      key: DashboardScreen.summaryCountKey(label),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.titleText,
                        fontSize: AppTypography.sizeLg,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.three),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: denominator == 0 ? 0 : count / denominator,
              minHeight: AppSpacing.oneAndHalf,
              backgroundColor: fillColor.withValues(alpha: 0.42),
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.eight,
        vertical: AppSpacing.six,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: headerKey,
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(AppRadii.xl),
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
                              color: AppColors.titleText,
                              fontSize: AppTypography.sizeLg,
                              fontWeight: AppTypography.weightSemibold,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.one),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subHeaderText,
                          fontSize: AppTypography.sizeBase,
                          fontWeight: AppTypography.weightNormal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.three),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: toneColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: toneColor,
                      fontSize: AppTypography.sizeBase,
                      fontWeight: AppTypography.weightSemibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: AppSpacing.four),
            const Divider(height: 1, thickness: 1, color: AppColors.cardBorder),
            const SizedBox(height: AppSpacing.four),
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
            padding: const EdgeInsets.only(bottom: AppSpacing.two),
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
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.checkboxCardFill,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.checkboxCardBorder),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.five,
          vertical: AppSpacing.three,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                key: DashboardScreen.taskToggleKey(task.id),
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.blue500,
                checkColor: AppColors.blue50,
                side: const BorderSide(color: AppColors.blue200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.three),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.titleText,
                      fontSize: AppTypography.sizeBase,
                      fontWeight: AppTypography.weightSemibold,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.one),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.subHeaderText,
                      fontSize: AppTypography.sizeSm,
                      fontWeight: AppTypography.weightNormal,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.two,
        vertical: AppSpacing.two,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.titleText,
                fontSize: AppTypography.sizeLg,
                fontWeight: AppTypography.weightSemibold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.subHeaderText,
                fontSize: AppTypography.sizeBase,
                fontWeight: AppTypography.weightNormal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStats {
  const _ProfileStats({
    required this.completedCount,
    required this.pendingCount,
    required this.overdueCount,
  });

  factory _ProfileStats.fromController(TaskManagementController controller) {
    final tasks = controller.tasks;
    final now = DateTime.now();
    final completedCount = tasks.where((task) => task.isCompleted).length;
    final pendingCount = tasks
        .where((task) => task.statusAt(now) == TaskStatus.pending)
        .length;
    final overdueCount = tasks
        .where((task) => task.statusAt(now) == TaskStatus.overdue)
        .length;

    return _ProfileStats(
      completedCount: completedCount,
      pendingCount: pendingCount,
      overdueCount: overdueCount,
    );
  }

  final int completedCount;
  final int pendingCount;
  final int overdueCount;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.theme,
    required this.displayName,
    required this.profileImageData,
    required this.stats,
    required this.onPickProfileImage,
    required this.onEditProfile,
    required this.onOpenArchives,
  });

  final ThemeData theme;
  final String? displayName;
  final String? profileImageData;
  final _ProfileStats stats;
  final VoidCallback onPickProfileImage;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenArchives;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'Your Name';

    return ColoredBox(
      color: taskSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.four,
          AppSpacing.six,
          AppSpacing.four,
          112,
        ),
        children: [
          Center(
            child: Text(
              'My Profile',
              style: theme.textTheme.titleMedium?.copyWith(
                color: taskDarkText,
                fontWeight: AppTypography.weightSemibold,
                fontSize: AppTypography.sizeLg,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.six),
          _ProfileHero(
            name: name,
            profileImageData: profileImageData,
            onPickProfileImage: onPickProfileImage,
          ),
          const SizedBox(height: AppSpacing.five),
          _ProfileStatsRow(stats: stats),
          const SizedBox(height: AppSpacing.six),
          Text(
            'Manage Account',
            style: theme.textTheme.bodySmall?.copyWith(
              color: taskMutedText,
              fontSize: AppTypography.sizeBase,
              fontWeight: AppTypography.weightNormal,
            ),
          ),
          const SizedBox(height: AppSpacing.three),
          _ProfileAccountList(
            onEditProfile: onEditProfile,
            onOpenArchives: onOpenArchives,
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.profileImageData,
    required this.onPickProfileImage,
  });

  final String name;
  final String? profileImageData;
  final VoidCallback onPickProfileImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: DashboardScreen.profileIdentityKey,
      color: Colors.transparent,
      child: Column(
        children: [
          SizedBox(
            height: 118,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 84,
                  decoration: BoxDecoration(
                    color: taskPrimaryBlue,
                    borderRadius: BorderRadius.circular(AppRadii.threeXl),
                  ),
                ),
                Positioned(
                  top: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.neutral50,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppSizes.borderDefault * 4,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: taskAccentBlue,
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _ProfileAvatarImage(
                              imageData: profileImageData,
                              imageKey: DashboardScreen.profileAvatarImageKey,
                              fallbackIconSize: 36,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: DashboardScreen.profileImageButtonKey,
                            onTap: onPickProfileImage,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: taskPrimaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.cardFill,
                                  width: AppSizes.borderDefault * 2,
                                ),
                              ),
                              child: const Icon(
                                TablerIcons.camera,
                                color: AppColors.primaryButtonText,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.two),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.four,
              vertical: AppSpacing.one,
            ),
            decoration: BoxDecoration(
              color: AppColors.successBadgeFill,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              'Active',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.successBadgeText,
                fontSize: AppTypography.sizeXs,
                fontWeight: AppTypography.weightMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.two),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: taskDarkText,
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.stats});

  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(
            child: _ProfileStatTile(
              key: DashboardScreen.profileCompletedStatKey,
              value: stats.completedCount,
              label: 'Completed',
              backgroundColor: AppColors.successBadgeFill,
              foregroundColor: AppColors.successBadgeText,
            ),
          ),
          const _ProfileStatDivider(),
          Expanded(
            child: _ProfileStatTile(
              key: DashboardScreen.profilePendingStatKey,
              value: stats.pendingCount,
              label: 'Pending',
              backgroundColor: AppColors.warningBadgeFill,
              foregroundColor: AppColors.warningBadgeText,
            ),
          ),
          const _ProfileStatDivider(),
          Expanded(
            child: _ProfileStatTile(
              key: DashboardScreen.profileOverdueStatKey,
              value: stats.overdueCount,
              label: 'Overdue',
              backgroundColor: AppColors.dangerBadgeFill,
              foregroundColor: AppColors.dangerBadgeText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int value;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.5),
          ),
          child: Text(
            '$value',
            style: theme.textTheme.titleSmall?.copyWith(
              color: foregroundColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.neutral400,
            fontSize: AppTypography.sizeXs,
            fontWeight: AppTypography.weightNormal,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarImage extends StatelessWidget {
  const _ProfileAvatarImage({
    required this.imageData,
    required this.imageKey,
    required this.fallbackIconSize,
  });

  final String? imageData;
  final Key imageKey;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final data = imageData;
    if (data != null && data.isNotEmpty) {
      try {
        return Image.memory(
          key: imageKey,
          base64Decode(data),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _ProfileAvatarFallback(size: fallbackIconSize),
        );
      } catch (_) {
        return _ProfileAvatarFallback(size: fallbackIconSize);
      }
    }

    return _ProfileAvatarFallback(size: fallbackIconSize);
  }
}

class _ProfileAvatarFallback extends StatelessWidget {
  const _ProfileAvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(TablerIcons.user, color: taskPrimaryBlue, size: size);
  }
}

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30.4,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: taskMutedBorderColor,
    );
  }
}

class _ProfileAccountList extends StatelessWidget {
  const _ProfileAccountList({
    required this.onEditProfile,
    required this.onOpenArchives,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onOpenArchives;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.two),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        border: Border.all(color: taskBorderColor),
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
      ),
      child: Column(
        children: [
          _ProfileAccountRow(
            key: DashboardScreen.profileUserRowKey,
            icon: TablerIcons.user,
            label: 'User Profile',
            onTap: onEditProfile,
          ),
          _ProfileAccountRow(
            key: DashboardScreen.profileArchivesRowKey,
            icon: TablerIcons.archive,
            label: 'Archives',
            onTap: onOpenArchives,
          ),
        ],
      ),
    );
  }
}

class _ProfileAccountRow extends StatelessWidget {
  const _ProfileAccountRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.six,
            vertical: AppSpacing.four,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppTypography.size2xl, color: taskDarkText),
              const SizedBox(width: AppSpacing.five),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: taskDarkText,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: taskMutedText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNameSheet extends StatefulWidget {
  const _ProfileNameSheet({required this.initialName, required this.onSave});

  final String initialName;
  final Future<void> Function(String value) onSave;

  @override
  State<_ProfileNameSheet> createState() => _ProfileNameSheetState();
}

class _ProfileNameSheetState extends State<_ProfileNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final navigator = Navigator.of(context);
    final trimmed = _controller.text.trim();
    try {
      await widget.onSave(trimmed);
      if (mounted) {
        navigator.pop(trimmed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: taskMutedBorderColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Edit Profile Name',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This name appears on your profile and reminders.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: taskSecondaryText,
                ),
              ),
              const SizedBox(height: 18),
              const TaskFieldLabel('Display Name'),
              const SizedBox(height: 8),
              TextFormField(
                key: DashboardScreen.profileNameFieldKey,
                controller: _controller,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _isSaving ? null : _save(),
                decoration:
                    taskInputDecoration(
                      context: context,
                      hintText: 'Enter your name',
                    ).copyWith(
                      labelText: null,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: DashboardScreen.profileNameSaveButtonKey,
                  onPressed: _isSaving ? null : _save,
                  style: taskButtonStyle(
                    context,
                    role: TaskButtonRole.primary,
                    size: TaskButtonSize.large,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Name'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProfileImageDialogAction { cancel, upload, remove }

class _ProfileImagePermissionDialog extends StatelessWidget {
  const _ProfileImagePermissionDialog({required this.hasProfileImage});

  final bool hasProfileImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryLabel = hasProfileImage ? 'Remove' : 'Cancel';
    final primaryLabel = hasProfileImage ? 'Upload New' : 'Upload Profile';

    return Dialog(
      key: DashboardScreen.profileImagePermissionDialogKey,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.four,
        vertical: AppSpacing.six,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.threeXl),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.six,
          AppSpacing.eight,
          AppSpacing.six,
          AppSpacing.six,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                TablerIcons.photo,
                color: AppColors.blue500,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.six),
            Text(
              'Update Profile Photo',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.titleText,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.three),
            Text(
              'Adding a photo shows it on your profile you can remove it anytime.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.subHeaderText,
                fontWeight: AppTypography.weightNormal,
              ),
            ),
            const SizedBox(height: AppSpacing.six),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: DashboardScreen.profileImagePermissionSecondaryKey,
                    onPressed: () => Navigator.of(context).pop(
                      hasProfileImage
                          ? _ProfileImageDialogAction.remove
                          : _ProfileImageDialogAction.cancel,
                    ),
                    style: taskButtonStyle(
                      context,
                      role: TaskButtonRole.secondary,
                      size: TaskButtonSize.medium,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.three),
                Expanded(
                  child: FilledButton(
                    key: DashboardScreen.profileImagePermissionContinueKey,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_ProfileImageDialogAction.upload),
                    style: taskButtonStyle(
                      context,
                      role: TaskButtonRole.primary,
                      size: TaskButtonSize.medium,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
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

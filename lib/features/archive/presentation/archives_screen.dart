import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_reminder_service.dart';
import '../../spaces/presentation/spaces_controller.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/domain/task_repository.dart';
import '../../task_management/presentation/task_management_controller.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../../spaces/domain/task_space.dart';

enum _ArchiveFilter { all, spaces, tasks }

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({
    super.key,
    required this.repository,
    required this.reminderService,
  });

  final TaskRepository repository;
  final TaskReminderService reminderService;

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  late final TaskManagementController _taskController =
      TaskManagementController(
        widget.repository,
        reminderService: widget.reminderService,
      )..load();
  late final SpacesController _spacesController = SpacesController(
    widget.repository,
    reminderService: widget.reminderService,
  )..load();
  _ArchiveFilter _filter = _ArchiveFilter.all;

  @override
  void dispose() {
    _taskController.dispose();
    _spacesController.dispose();
    super.dispose();
  }

  Future<void> _restoreTask(TaskItem task) async {
    try {
      await _taskController.restoreTask(task);
      if (!mounted) {
        return;
      }
      showTaskToast(context, message: 'Task restored successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to restore the task right now.',
        isError: true,
      );
    }
  }

  Future<void> _restoreSpace(TaskSpace space) async {
    try {
      await _spacesController.restoreSpace(space);
      await _taskController.load();
      if (!mounted) {
        return;
      }
      showTaskToast(context, message: 'Space restored successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to restore the space right now.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: taskSurface,
      body: AnimatedBuilder(
        animation: Listenable.merge([_taskController, _spacesController]),
        builder: (context, _) {
          if (_taskController.isLoading || _spacesController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final archivedTasks = _taskController.archivedTasks();
          final archivedSpaces = _spacesController.archivedSpaces();
          final hiddenSpaceTasks = _spacesController
              .archivedTasksForArchivedSpaces();
          final visibleSpaces = _filter == _ArchiveFilter.tasks
              ? <TaskSpace>[]
              : archivedSpaces;
          final visibleTasks = _filter == _ArchiveFilter.spaces
              ? <TaskItem>[]
              : archivedTasks;
          final hasItems =
              archivedTasks.isNotEmpty || archivedSpaces.isNotEmpty;
          final hasVisibleItems =
              visibleSpaces.isNotEmpty || visibleTasks.isNotEmpty;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  sliver: SliverToBoxAdapter(child: const _ArchivesHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ArchiveFilterBar(
                      selectedFilter: _filter,
                      onChanged: (value) {
                        setState(() {
                          _filter = value;
                        });
                      },
                    ),
                  ),
                ),
                if (!hasItems)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ArchiveEmptyState(),
                  )
                else if (!hasVisibleItems)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
                    sliver: const SliverToBoxAdapter(
                      child: _ArchiveFilteredEmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        for (final space in visibleSpaces) ...[
                          _ArchiveRestoreCard(
                            title: space.name,
                            subtitle: _spaceSubtitle(space, hiddenSpaceTasks),
                            category: _spacesController.categoryFor(
                              space.categoryId,
                            ),
                            icon: TablerIcons.folder,
                            color: space.color,
                            archivedAt: space.archivedAt,
                            metaText: _spaceMeta(space, hiddenSpaceTasks),
                            taskCountBadge: _spaceTaskCount(
                              space,
                              hiddenSpaceTasks,
                            ),
                            isVaultProtected:
                                space.vaultConfig?.isEnabled == true,
                            onRestore: () => _restoreSpace(space),
                          ),
                          const SizedBox(height: 10),
                        ],
                        for (final task in visibleTasks) ...[
                          _ArchiveRestoreCard(
                            title: task.title,
                            subtitle: _taskSubtitle(task),
                            category: _taskController.categoryFor(
                              task.categoryId,
                            ),
                            icon: _taskIconFor(
                              task,
                              _taskController.categoryFor(task.categoryId),
                            ),
                            color:
                                _taskController
                                    .categoryFor(task.categoryId)
                                    ?.color ??
                                taskPrimaryBlue,
                            archivedAt: task.archivedAt,
                            metaText: _taskMeta(task),
                            taskCountBadge: 0,
                            isVaultProtected:
                                task.vaultConfig?.isEnabled == true ||
                                _taskController
                                        .spaceFor(task.spaceId)
                                        ?.vaultConfig
                                        ?.isEnabled ==
                                    true,
                            onRestore: () => _restoreTask(task),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static IconData _taskIconFor(TaskItem task, TaskCategory? category) {
    if (category != null) {
      return resolveTaskCategoryIcon(category.iconKey);
    }
    return resolveTaskCategoryIcon(task.categoryId);
  }

  static String _taskSubtitle(TaskItem task) {
    final description = task.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return 'Task short description';
  }

  static String _spaceSubtitle(TaskSpace space, List<TaskItem> hiddenTasks) {
    final description = space.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    final taskCount = _spaceTaskCount(space, hiddenTasks);
    if (taskCount == 1) {
      return '1 hidden task';
    }
    if (taskCount > 1) {
      return '$taskCount hidden tasks';
    }
    return 'Folder short description';
  }

  static int _spaceTaskCount(TaskSpace space, List<TaskItem> hiddenTasks) {
    return hiddenTasks.where((task) => task.spaceId == space.id).length;
  }

  static String _spaceMeta(TaskSpace space, List<TaskItem> hiddenTasks) {
    final taskCount = _spaceTaskCount(space, hiddenTasks);
    if (taskCount == 1) {
      return '1 task inside';
    }
    return '$taskCount tasks inside';
  }

  static String _taskMeta(TaskItem task) {
    if (task.isCompleted) {
      return 'Completed task';
    }
    return switch (task.priority) {
      TaskPriority.low => 'Low priority',
      TaskPriority.medium => 'Medium priority',
      TaskPriority.high => 'High priority',
      TaskPriority.urgent => 'Urgent priority',
    };
  }
}

class _ArchivesHeader extends StatelessWidget {
  const _ArchivesHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArchiveBackButton(onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Archives',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and restore your archived tasks and spaces.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: taskMutedText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArchiveBackButton extends StatelessWidget {
  const _ArchiveBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: taskBorderColor),
          ),
          child: const Icon(
            TablerIcons.arrow_left,
            color: taskDarkText,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ArchiveFilterBar extends StatelessWidget {
  const _ArchiveFilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _ArchiveFilter selectedFilter;
  final ValueChanged<_ArchiveFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArchiveFilterChip(
          label: 'All',
          icon: TablerIcons.archive,
          isSelected: selectedFilter == _ArchiveFilter.all,
          onTap: () => onChanged(_ArchiveFilter.all),
        ),
        const SizedBox(width: 8),
        _ArchiveFilterChip(
          label: 'Spaces',
          icon: TablerIcons.folder,
          isSelected: selectedFilter == _ArchiveFilter.spaces,
          onTap: () => onChanged(_ArchiveFilter.spaces),
        ),
        const SizedBox(width: 8),
        _ArchiveFilterChip(
          label: 'Tasks',
          icon: TablerIcons.checkbox,
          isSelected: selectedFilter == _ArchiveFilter.tasks,
          onTap: () => onChanged(_ArchiveFilter.tasks),
        ),
      ],
    );
  }
}

class _ArchiveFilterChip extends StatelessWidget {
  const _ArchiveFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: taskFilterControlHeight,
            maxHeight: taskFilterControlHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? taskPrimaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? taskPrimaryBlue : taskBorderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : taskMutedText,
                size: 13,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? Colors.white : taskSecondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveRestoreCard extends StatelessWidget {
  const _ArchiveRestoreCard({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    required this.archivedAt,
    required this.metaText,
    required this.taskCountBadge,
    required this.isVaultProtected,
    required this.onRestore,
  });

  final String title;
  final String subtitle;
  final TaskCategory? category;
  final IconData icon;
  final Color color;
  final DateTime? archivedAt;
  final String metaText;
  final int taskCountBadge;
  final bool isVaultProtected;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = this.category;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
        boxShadow: [
          BoxShadow(
            color: taskDarkText.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _softTone(color),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: color, size: 25),
                  ),
                  if (taskCountBadge > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: _ArchiveTaskCountBadge(count: taskCountBadge),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: taskDarkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(width: 8),
                          _ArchiveCategoryBadge(category: category),
                        ],
                        if (isVaultProtected) ...[
                          const SizedBox(width: 7),
                          const Icon(
                            TablerIcons.lock,
                            size: 13,
                            color: taskMutedText,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: taskSecondaryText,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _ArchiveSoftPill(
                  label: _archivedLabel(archivedAt, metaText),
                  color: taskSecondaryText,
                  icon: TablerIcons.clock,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onRestore,
                icon: const Icon(TablerIcons.refresh, size: 16),
                label: const Text('Restore'),
                style: FilledButton.styleFrom(
                  backgroundColor: taskPrimaryBlue,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _archivedLabel(DateTime? archivedAt, String fallback) {
    if (archivedAt == null) {
      return fallback;
    }
    final month = _monthLabel(archivedAt.month);
    return '$month ${archivedAt.day}';
  }

  static String _monthLabel(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
  }
}

class _ArchiveSoftPill extends StatelessWidget {
  const _ArchiveSoftPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _softTone(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveCategoryBadge extends StatelessWidget {
  const _ArchiveCategoryBadge({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _softTone(category.color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolveTaskCategoryIcon(category.iconKey),
            color: category.color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: category.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveTaskCountBadge extends StatelessWidget {
  const _ArchiveTaskCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: taskDangerText,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _ArchiveFilteredEmptyState extends StatelessWidget {
  const _ArchiveFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        children: [
          const Icon(TablerIcons.filter_off, color: taskMutedText, size: 28),
          const SizedBox(height: 10),
          Text(
            'Nothing in this view',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try a different archive filter.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: taskSecondaryText),
          ),
        ],
      ),
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: taskAccentBlue,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                TablerIcons.archive,
                color: taskPrimaryBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your archive is clear',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: taskDarkText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you archive spaces or tasks, they will wait here with a one-tap restore action.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: taskMutedText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _softTone(Color color) {
  if (color.toARGB32() == taskPrimaryBlue.toARGB32()) {
    return taskAccentBlue;
  }
  if (color.toARGB32() == taskSuccessText.toARGB32()) {
    return const Color(0xFFE6F6F1);
  }
  return color.withValues(alpha: 0.12);
}

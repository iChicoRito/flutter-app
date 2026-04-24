import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_data_refresh_scope.dart';
import '../../../core/services/task_reminder_service.dart';
import '../../../core/theme/app_design_tokens.dart';
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
      TaskDataRefreshScope.of(context).notifyDataChanged();
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
      TaskDataRefreshScope.of(context).notifyDataChanged();
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.four,
                    AppSpacing.one,
                    AppSpacing.four,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: const _ArchivesHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.four,
                    AppSpacing.five,
                    AppSpacing.four,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Filter',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: taskDarkText,
                        fontSize: AppTypography.sizeBase,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.four,
                    AppSpacing.four,
                    AppSpacing.four,
                    0,
                  ),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.four,
                      AppSpacing.ten,
                      AppSpacing.four,
                      AppSpacing.six,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _ArchiveFilteredEmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.four,
                      AppSpacing.six,
                      AppSpacing.four,
                      AppSpacing.six,
                    ),
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
                            taskCountBadge: _spaceTaskCount(
                              space,
                              hiddenSpaceTasks,
                            ),
                            isVaultProtected:
                                space.vaultConfig?.isEnabled == true,
                            onRestore: () => _restoreSpace(space),
                          ),
                          const SizedBox(height: AppSpacing.three),
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
                          const SizedBox(height: AppSpacing.three),
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
    return 'Restore to use this task';
  }

  static String _spaceSubtitle(TaskSpace space, List<TaskItem> hiddenTasks) {
    final description = space.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    final taskCount = _spaceTaskCount(space, hiddenTasks);
    if (taskCount == 1) {
      return '1 task inside space';
    }
    if (taskCount > 1) {
      return '$taskCount tasks inside space';
    }
    return 'No tasks inside space';
  }

  static int _spaceTaskCount(TaskSpace space, List<TaskItem> hiddenTasks) {
    return hiddenTasks.where((task) => task.spaceId == space.id).length;
  }
}

class _ArchivesHeader extends StatelessWidget {
  const _ArchivesHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ArchiveBackButton(onTap: () => Navigator.maybePop(context)),
        const SizedBox(width: AppSpacing.one),
        Expanded(
          child: Text(
            'My Archives',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
              color: AppColors.titleText,
            ),
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
    return IconButton(
      onPressed: onTap,
      icon: const Icon(
        TablerIcons.chevron_left,
        color: AppColors.subHeaderText,
        size: AppTypography.sizeLg,
      ),
      splashRadius: AppSpacing.five,
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.six,
        height: AppSpacing.six,
      ),
      padding: EdgeInsets.zero,
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
          isSelected: selectedFilter == _ArchiveFilter.all,
          onTap: () => onChanged(_ArchiveFilter.all),
        ),
        const SizedBox(width: AppSpacing.two),
        _ArchiveFilterChip(
          label: 'Tasks',
          isSelected: selectedFilter == _ArchiveFilter.tasks,
          onTap: () => onChanged(_ArchiveFilter.tasks),
        ),
        const SizedBox(width: AppSpacing.two),
        _ArchiveFilterChip(
          label: 'Spaces',
          isSelected: selectedFilter == _ArchiveFilter.spaces,
          onTap: () => onChanged(_ArchiveFilter.spaces),
        ),
      ],
    );
  }
}

class _ArchiveFilterChip extends StatelessWidget {
  const _ArchiveFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.eight,
            maxHeight: AppSpacing.eight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.three),
          decoration: BoxDecoration(
            color: isSelected ? taskPrimaryBlue : AppColors.cardFill,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isSelected ? taskPrimaryBlue : AppColors.neutral200,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? AppColors.primaryButtonText : taskMutedText,
                fontSize: AppTypography.sizeSm,
                fontWeight: AppTypography.weightNormal,
              ),
            ),
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
    required this.taskCountBadge,
    required this.isVaultProtected,
    required this.onRestore,
  });

  final String title;
  final String subtitle;
  final TaskCategory? category;
  final IconData icon;
  final Color color;
  final int taskCountBadge;
  final bool isVaultProtected;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = this.category;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.five,
        AppSpacing.five,
        AppSpacing.five,
        AppSpacing.four,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _softTone(color),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(icon, color: color, size: AppSpacing.six),
                  ),
                  if (taskCountBadge > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: _ArchiveTaskCountBadge(count: taskCountBadge),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.three),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: taskDarkText,
                        fontSize: AppTypography.sizeBase,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.one),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: taskSecondaryText,
                        fontSize: AppTypography.sizeSm,
                        fontWeight: AppTypography.weightNormal,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (category != null) ...[
                const SizedBox(width: AppSpacing.two),
                _ArchiveCategoryBadge(category: category),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.four),
          Row(
            children: [
              if (isVaultProtected)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        TablerIcons.lock,
                        color: taskMutedText,
                        size: AppTypography.sizeLg,
                      ),
                      const SizedBox(width: AppSpacing.two),
                      Flexible(
                        child: Text(
                          'Locked Content',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: taskMutedText,
                            fontSize: AppTypography.sizeSm,
                            fontWeight: AppTypography.weightNormal,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.three),
              FilledButton.icon(
                onPressed: onRestore,
                icon: const Icon(
                  TablerIcons.refresh,
                  size: AppTypography.sizeBase,
                ),
                label: const Text('Restore'),
                style: taskButtonStyle(
                  context,
                  role: TaskButtonRole.primary,
                  size: TaskButtonSize.small,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.four,
                    vertical: AppSpacing.two,
                  ),
                  minimumSize: const Size(104, 40),
                  shrinkTapTarget: true,
                ),
              ),
            ],
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
      constraints: const BoxConstraints(maxWidth: 92, minHeight: 26),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.twoAndHalf,
        vertical: AppSpacing.one,
      ),
      decoration: BoxDecoration(
        color: _softTone(category.color),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolveTaskCategoryIcon(category.iconKey),
            color: category.color,
            size: AppTypography.sizeXs,
          ),
          const SizedBox(width: AppSpacing.one),
          Flexible(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: category.color,
                fontSize: AppTypography.sizeXs,
                fontWeight: AppTypography.weightMedium,
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
                fontSize: AppTypography.sizeLg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you archive spaces or tasks, they will wait here with a one-tap restore action.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: taskMutedText,
                height: 1.5,
                fontSize: AppTypography.sizeSm,
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
    return AppColors.successBadgeFill;
  }
  return color.withValues(alpha: 0.12);
}

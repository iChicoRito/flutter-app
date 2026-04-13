import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_editor_screen.dart';
import 'task_management_controller.dart';
import 'task_management_ui.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key, required this.repository});

  static const Key markerKey = Key('task-management-screen');
  static const Key searchFieldKey = Key('task-management-search');
  static const Key addTaskFabKey = Key('task-management-add-task');
  static const Key emptyStateKey = Key('task-management-empty');
  static const Key retryButtonKey = Key('task-management-retry');
  static const Key categoryDropdownKey = Key(
    'task-management-category-dropdown',
  );
  static const Key priorityDropdownKey = Key(
    'task-management-priority-dropdown',
  );
  static const Key allCategoriesKey = Key('task-category-filter-all');

  static Key priorityFilterKey(String value) =>
      Key('task-priority-filter-$value');

  static Key categoryFilterKey(String id) => Key('task-category-filter-$id');

  static Key taskTileKey(String taskId) => Key('task-tile-$taskId');

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');

  static Key taskMenuButtonKey(String taskId) => Key('task-menu-$taskId');

  static Key taskMenuActionKey(String taskId, String action) =>
      Key('task-menu-$taskId-$action');

  final TaskRepository repository;

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  late final TaskManagementController _controller;
  final TextEditingController _searchController = TextEditingController();
  String? _revealedCheckboxTaskId;

  @override
  void initState() {
    super.initState();
    _controller = TaskManagementController(widget.repository);
    _controller.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor({TaskItem? task}) async {
    final result = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute<TaskItem>(
        builder: (context) => TaskEditorScreen(
          repository: widget.repository,
          categories: _controller.categories,
          initialTask: task,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _controller.saveTask(result);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            task == null ? 'Task added successfully.' : 'Task updated.',
          ),
        ),
      );
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _DeleteTaskDialog(taskTitle: task.title);
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _controller.deleteTask(task.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Task deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TaskManagementScreen.markerKey,
      backgroundColor: taskSurface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final filteredTasks = _controller.filteredTasks(DateTime.now());

            if (_controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_controller.errorMessage != null) {
              return _ErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.load,
              );
            }

            return RefreshIndicator(
              color: taskPrimaryBlue,
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: _controller.updateSearchQuery,
                  ),
                  const SizedBox(height: 16),
                  TaskSectionCard(
                    title: 'Filters',
                    subtitle: 'Narrow the task list by category or urgency.',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TaskCompactDropdown<String?>(
                                buttonKey:
                                    TaskManagementScreen.categoryDropdownKey,
                                menuKeyBuilder: (value) => Key(
                                  'task-category-dropdown-${value ?? 'all'}',
                                ),
                                currentValue: _controller.categoryFilterId,
                                currentLabel:
                                    _controller.categoryFilterId == null
                                    ? 'All Categories'
                                    : (_controller
                                              .categoryFor(
                                                _controller.categoryFilterId!,
                                              )
                                              ?.name ??
                                          'All Categories'),
                                onSelected: _controller.updateCategoryFilter,
                                items: [
                                  null,
                                  ..._controller.categories.map(
                                    (item) => item.id,
                                  ),
                                ],
                                labelBuilder: (value) => value == null
                                    ? 'All Categories'
                                    : (_controller.categoryFor(value)?.name ??
                                          'All Categories'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TaskCompactDropdown<TaskPriority?>(
                                buttonKey:
                                    TaskManagementScreen.priorityDropdownKey,
                                menuKeyBuilder: (value) =>
                                    TaskManagementScreen.priorityFilterKey(
                                      value?.name ?? 'all',
                                    ),
                                currentValue: _controller.priorityFilter,
                                currentLabel: _controller.priorityFilter == null
                                    ? 'Priority'
                                    : _priorityLabel(
                                        _controller.priorityFilter!,
                                      ),
                                onSelected: _controller.updatePriorityFilter,
                                items: [null, ...TaskPriority.values],
                                labelBuilder: (value) => value == null
                                    ? 'Priority'
                                    : _priorityLabel(value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _CategoryFilterRow(
                          categories: _controller.categories,
                          selectedCategoryId: _controller.categoryFilterId,
                          onSelected: _controller.updateCategoryFilter,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredTasks.isEmpty)
                    const _EmptyState()
                  else
                    ...filteredTasks.map((task) {
                      final category = _controller.categoryFor(task.categoryId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TaskCard(
                          task: task,
                          category: category,
                          showCheckbox: _revealedCheckboxTaskId == task.id,
                          onLongPress: () {
                            setState(() {
                              _revealedCheckboxTaskId =
                                  _revealedCheckboxTaskId == task.id
                                  ? null
                                  : task.id;
                            });
                          },
                          onToggle: () =>
                              _controller.toggleTaskCompletion(task),
                          onEdit: () => _openEditor(task: task),
                          onDelete: () => _confirmDelete(task),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: TaskManagementScreen.addTaskFabKey,
        onPressed: _controller.isSaving ? null : _openEditor,
        backgroundColor: taskPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(TablerIcons.plus, size: 18),
        label: const Text('Add Task'),
      ),
    );
  }

  static String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
      TaskPriority.urgent => 'Urgent',
    };
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: TaskManagementScreen.searchFieldKey,
      controller: controller,
      onChanged: onChanged,
      decoration: taskInputDecoration(
        context: context,
        hintText: 'Search tasks, notes, categories',
        prefixIcon: const Icon(
          TablerIcons.search,
          size: 18,
          color: taskMutedText,
        ),
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<TaskCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              chipKey: TaskManagementScreen.allCategoriesKey,
              label: 'All Categories',
              icon: TablerIcons.check,
              iconColor: selectedCategoryId == null
                  ? Colors.white
                  : taskMutedText,
              selected: selectedCategoryId == null,
              onTap: () => onSelected(null),
            ),
          ),
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                chipKey: TaskManagementScreen.categoryFilterKey(category.id),
                label: category.name,
                icon: resolveTaskCategoryIcon(category.iconKey),
                iconColor: selectedCategoryId == category.id
                    ? Colors.white
                    : taskMutedText,
                selected: selectedCategoryId == category.id,
                onTap: () {
                  onSelected(
                    selectedCategoryId == category.id ? null : category.id,
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.chipKey,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? taskPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? taskPrimaryBlue : taskBorderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : taskSecondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.category,
    required this.showCheckbox,
    required this.onLongPress,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TaskItem task;
  final TaskCategory? category;
  final bool showCheckbox;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  static const double _contentSpacing = 8;

  @override
  Widget build(BuildContext context) {
    final accentColor = category?.color ?? taskPrimaryBlue;
    final description = (task.description?.trim().isNotEmpty ?? false)
        ? task.description!.trim()
        : 'No additional notes yet.';
    final scheduleLabel = _scheduleLabel(task, context);
    final borderColor = showCheckbox ? taskPrimaryBlue : taskBorderColor;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        key: TaskManagementScreen.taskTileKey(task.id),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor, width: showCheckbox ? 1.6 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: showCheckbox
                  ? Padding(
                      key: ValueKey(task.id),
                      padding: const EdgeInsets.only(top: 6, right: 14),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          checkboxTheme: CheckboxThemeData(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: const BorderSide(
                              color: taskMutedText,
                              width: 1.6,
                            ),
                          ),
                        ),
                        child: Checkbox(
                          key: TaskManagementScreen.taskToggleKey(task.id),
                          value: task.isCompleted,
                          onChanged: (_) => onToggle(),
                          activeColor: accentColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('hidden-checkbox')),
            ),
            if (showCheckbox) const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: taskDarkText,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                      PopupMenuButton<_TaskCardAction>(
                        key: TaskManagementScreen.taskMenuButtonKey(task.id),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: EdgeInsets.zero,
                        position: PopupMenuPosition.under,
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            TablerIcons.dots_vertical,
                            size: 20,
                            color: taskMutedText,
                          ),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case _TaskCardAction.edit:
                              onEdit();
                            case _TaskCardAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem<_TaskCardAction>(
                              key: TaskManagementScreen.taskMenuActionKey(
                                task.id,
                                'edit',
                              ),
                              value: _TaskCardAction.edit,
                              child: const Text('Edit'),
                            ),
                            PopupMenuItem<_TaskCardAction>(
                              key: TaskManagementScreen.taskMenuActionKey(
                                task.id,
                                'delete',
                              ),
                              value: _TaskCardAction.delete,
                              child: const Text('Delete'),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  if (category != null) ...[
                    const SizedBox(height: _contentSpacing),
                    _CategoryBadge(category: category!),
                  ],
                  const SizedBox(height: _contentSpacing),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 60,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: taskMutedText,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      scheduleLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: taskMutedText,
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
    );
  }

  String _scheduleLabel(TaskItem task, BuildContext context) {
    final start = task.startDateTime;
    final end = task.endDateTime;
    if (start == null && end == null) {
      return 'No schedule';
    }

    if (start != null && end != null) {
      if (_isSameDate(start, end)) {
        return '${_formatDate(start)} • ${_formatTime(end, context)}';
      }
      return '${_formatDate(start)} - ${_formatDateTime(end, context)}';
    }

    if (start != null) {
      return 'Starts ${_formatDateTime(start, context)}';
    }

    return 'Ends ${_formatDateTime(end!, context)}';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year % 100}';
  }

  String _formatTime(DateTime value, BuildContext context) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: value.hour, minute: value.minute),
      alwaysUse24HourFormat: false,
    );
  }

  String _formatDateTime(DateTime value, BuildContext context) {
    return '${_formatDate(value)} • ${_formatTime(value, context)}';
  }
}

enum _TaskCardAction { edit, delete }

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            size: 12,
            color: category.color,
          ),
          const SizedBox(width: 6),
          Text(
            '${category.name} Category',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: category.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: TaskManagementScreen.emptyStateKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: taskAccentBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              TablerIcons.notes,
              size: 34,
              color: taskPrimaryBlue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first task to build your offline productivity hub.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: taskMutedText, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DeleteTaskDialog extends StatelessWidget {
  const _DeleteTaskDialog({required this.taskTitle});

  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Task',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: taskDarkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review the action before removing this task from your local list.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: taskSecondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(
                    TablerIcons.x,
                    size: 18,
                    color: taskMutedText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: taskBorderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: taskSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: taskBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: taskSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        taskTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: taskDarkText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'This action will permanently remove the task from your device.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: taskSecondaryText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: taskBorderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: taskSecondaryText,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: taskDangerText,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              TablerIcons.alert_circle,
              size: 36,
              color: taskDangerText,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: taskDarkText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: TaskManagementScreen.retryButtonKey,
              style: FilledButton.styleFrom(backgroundColor: taskPrimaryBlue),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

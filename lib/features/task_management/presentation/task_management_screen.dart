import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../data/task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_creation_sheet.dart';
import 'task_editor_screen.dart';
import 'task_management_controller.dart';
import 'task_management_ui.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({
    super.key,
    required this.repository,
    required this.controller,
  });

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
  static const Key createTitleFieldKey = Key('task-create-title-field');
  static const Key createDescriptionFieldKey = Key(
    'task-create-description-field',
  );
  static const Key createPriorityFieldKey = Key('task-create-priority-field');
  static const Key createCategoryFieldKey = Key('task-create-category-field');
  static const Key createSubmitButtonKey = Key('task-create-submit-button');

  static Key priorityFilterKey(String value) =>
      Key('task-priority-filter-$value');

  static Key categoryFilterKey(String id) => Key('task-category-filter-$id');

  static Key taskTileKey(String taskId) => Key('task-tile-$taskId');

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');

  static Key taskMenuButtonKey(String taskId) => Key('task-menu-$taskId');

  static Key taskMenuActionKey(String taskId, String action) =>
      Key('task-menu-$taskId-$action');

  final TaskRepository repository;
  final TaskManagementController controller;

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;

  TaskManagementController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_controller.tasks.isEmpty && _controller.categories.isEmpty) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSelectionMode() {
    if (!_isSelectionMode) {
      return;
    }
    setState(() {
      _isSelectionMode = false;
    });
  }

  Future<void> _openCreateFlow() async {
    if (_controller.categories.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Add a category first before creating a task.'),
          ),
        );
      return;
    }

    final request = await Navigator.of(context).push<TaskCreationRequest>(
      MaterialPageRoute<TaskCreationRequest>(
        builder: (context) => TaskCreationScreen(
          repository: widget.repository,
          categories: _controller.categories,
        ),
      ),
    );
    if (request == null) {
      return;
    }

    final task = await _controller.createTask(
      title: request.title,
      description: request.description,
      categoryId: request.categoryId,
      priority: request.priority,
      startDate: request.startDate,
      startMinutes: request.startMinutes,
      endDate: request.endDate,
      endMinutes: request.endMinutes,
    );
    if (!mounted) {
      return;
    }

    await _openEditor(task.id);
  }

  Future<void> _openEditor(String taskId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => TaskEditorScreen(
          repository: widget.repository,
          taskId: taskId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _controller.load();
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteTaskDialog(taskTitle: task.title),
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
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _clearSelectionMode();
        }
      },
      child: Scaffold(
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

              return GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: _isSelectionMode ? _clearSelectionMode : null,
                child: RefreshIndicator(
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
                        subtitle:
                            'Search across task titles, note previews, and categories.',
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
                                                    _controller
                                                        .categoryFilterId!,
                                                  )
                                                  ?.name ??
                                              'All Categories'),
                                    onSelected:
                                        _controller.updateCategoryFilter,
                                    items: [
                                      null,
                                      ..._controller.categories.map(
                                        (item) => item.id,
                                      ),
                                    ],
                                    labelBuilder: (value) => value == null
                                        ? 'All Categories'
                                        : (_controller
                                                  .categoryFor(value)
                                                  ?.name ??
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
                                    currentLabel:
                                        _controller.priorityFilter == null
                                        ? 'Priority'
                                        : _priorityLabel(
                                            _controller.priorityFilter!,
                                          ),
                                    onSelected:
                                        _controller.updatePriorityFilter,
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
                          final category = _controller.categoryFor(
                            task.categoryId,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _TaskCard(
                              task: task,
                              category: category,
                              showCheckbox: _isSelectionMode,
                              onTap: () => _isSelectionMode
                                  ? _controller.toggleTaskCompletion(task)
                                  : _openEditor(task.id),
                              onLongPress: () {
                                setState(() {
                                  _isSelectionMode = true;
                                });
                              },
                              onToggle: () =>
                                  _controller.toggleTaskCompletion(task),
                              onDelete: () => _confirmDelete(task),
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
        floatingActionButton: FloatingActionButton.extended(
          key: TaskManagementScreen.addTaskFabKey,
          onPressed: _controller.isSaving ? null : _openCreateFlow,
          backgroundColor: taskPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(TablerIcons.plus, size: 18),
          label: const Text('Add Task'),
        ),
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
              iconColor: selectedCategoryId == null ? Colors.white : taskMutedText,
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
                onTap: () => onSelected(
                  selectedCategoryId == category.id ? null : category.id,
                ),
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
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskItem task;
  final TaskCategory? category;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const trailingSlotWidth = 28.0;
    const cardStackSpacing = 12.0;
    final accentColor = category?.color ?? taskPrimaryBlue;
    final descriptionText = taskDescriptionPreview(task);
    final actualNotePreview = taskActualNotePreview(task);
    final noteText = actualNotePreview.isEmpty
        ? 'Open this task to start writing rich notes.'
        : actualNotePreview;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: TaskManagementScreen.taskTileKey(task.id),
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: showCheckbox
                ? taskAccentBlue.withValues(alpha: 0.32)
                : Colors.white,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: showCheckbox
                  ? taskPrimaryBlue.withValues(alpha: 0.42)
                  : taskBorderColor,
              width: showCheckbox ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showCheckbox
                    ? Padding(
                        key: ValueKey(task.id),
                        padding: const EdgeInsets.only(top: 10),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(
                                color: taskMutedText,
                                width: 1.3,
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
              if (showCheckbox) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: taskDarkText,
                                      fontWeight: FontWeight.w700,
                                      height: 0.98,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              if (descriptionText.isNotEmpty) ...[
                                const SizedBox(height: cardStackSpacing),
                                Text(
                                  descriptionText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: taskMutedText,
                                        fontWeight: FontWeight.w500,
                                        height: 1.1,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: trailingSlotWidth,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              key: TaskManagementScreen.taskMenuButtonKey(task.id),
                              onPressed: onDelete,
                              visualDensity: VisualDensity.compact,
                              splashRadius: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              icon: const Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: taskDangerText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: cardStackSpacing),
                    if (category != null) ...[
                      _CategoryBadge(category: category!),
                      const SizedBox(height: cardStackSpacing),
                    ],
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              noteText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: taskMutedText,
                                    height: 1.42,
                                    fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}

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
            category.name,
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
            'Create a task to start capturing notes, details, and schedules in one place.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: taskMutedText,
                  height: 1.5,
                ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete Task',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: taskDarkText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This removes the task and its notes from your device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: taskSecondaryText,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Delete',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: taskDangerText,
                          fontWeight: FontWeight.w700,
                        ),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: taskDarkText,
                  ),
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

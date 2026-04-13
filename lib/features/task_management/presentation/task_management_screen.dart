import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_editor_screen.dart';
import 'task_management_controller.dart';

const _primaryBlue = Color(0xFF1E88E5);
const _accentBlue = Color(0xFFE3F2FD);
const _badgeSecondaryText = Color(0xFF6B7280);
const _dangerText = Color(0xFFD63939);
const _darkText = Color(0xFF1F2937);
const _borderColor = Color(0xFFE5E8EC);

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
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('Remove "${task.title}" from your local task list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _dangerText),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
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
      backgroundColor: const Color(0xFFF8FAFC),
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
              color: _primaryBlue,
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: _controller.updateSearchQuery,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Filter',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF55585F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactDropdown<String?>(
                          buttonKey: TaskManagementScreen.categoryDropdownKey,
                          menuKeyBuilder: (value) =>
                              Key('task-category-dropdown-${value ?? 'all'}'),
                          currentValue: _controller.categoryFilterId,
                          currentLabel: _controller.categoryFilterId == null
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
                            ..._controller.categories.map((item) => item.id),
                          ],
                          labelBuilder: (value) => value == null
                              ? 'All Categories'
                              : (_controller.categoryFor(value)?.name ??
                                    'All Categories'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CompactDropdown<TaskPriority?>(
                          buttonKey: TaskManagementScreen.priorityDropdownKey,
                          menuKeyBuilder: (value) =>
                              TaskManagementScreen.priorityFilterKey(
                                value?.name ?? 'all',
                              ),
                          currentValue: _controller.priorityFilter,
                          currentLabel: _controller.priorityFilter == null
                              ? 'Priority'
                              : _priorityLabel(_controller.priorityFilter!),
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
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(TablerIcons.plus, size: 18),
        label: const Text('Add Task'),
      ),
    );
  }

  String _priorityLabel(TaskPriority priority) {
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
      decoration: InputDecoration(
        hintText: 'Search tasks, notes, categories',
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFB0B5BD)),
        prefixIcon: const Icon(
          TablerIcons.search,
          size: 18,
          color: Color(0xFFB0B5BD),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9DDE3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9DDE3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9DDE3)),
        ),
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.buttonKey,
    required this.menuKeyBuilder,
    required this.currentValue,
    required this.currentLabel,
    required this.onSelected,
    required this.items,
    required this.labelBuilder,
  });

  final Key buttonKey;
  final Key Function(T value) menuKeyBuilder;
  final T currentValue;
  final String currentLabel;
  final ValueChanged<T> onSelected;
  final List<T> items;
  final String Function(T value) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      key: buttonKey,
      initialValue: currentValue,
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<T>(
            key: menuKeyBuilder(item),
            value: item,
            child: Text(labelBuilder(item)),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1E5EA)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF55585F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              TablerIcons.chevron_down,
              size: 14,
              color: Color(0xFF9CA3AF),
            ),
          ],
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
                  : _badgeSecondaryText,
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
                    : _badgeSecondaryText,
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _primaryBlue : const Color(0xFFE7EBF0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : _badgeSecondaryText,
                fontWeight: FontWeight.w600,
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
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TaskItem task;
  final TaskCategory? category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accentColor = category?.color ?? _primaryBlue;
    final description = (task.description?.trim().isNotEmpty ?? false)
        ? task.description!.trim()
        : 'No additional notes yet.';

    return Container(
      key: TaskManagementScreen.taskTileKey(task.id),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(
                    color: _badgeSecondaryText,
                    width: 1.3,
                  ),
                ),
              ),
              child: Checkbox(
                key: TaskManagementScreen.taskToggleKey(task.id),
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
                activeColor: accentColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF5F636C),
                              fontWeight: FontWeight.w700,
                              height: 1,
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
                      icon: const Icon(
                        TablerIcons.dots_vertical,
                        size: 20,
                        color: Color(0xFF5F636C),
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
                const SizedBox(height: 0),
                if (category != null) _CategoryBadge(category: category!),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF8D939C),
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    task.dueDateTime != null
                        ? _dueLabel(task.dueDateTime!, context)
                        : 'No due date',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFB0B5BD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime value, BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(
      TimeOfDay(hour: value.hour, minute: value.minute),
      alwaysUse24HourFormat: false,
    );
    return '${value.month}/${value.day}/${value.year} - $time';
  }
}

enum _TaskCardAction { edit, delete }

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolveTaskCategoryIcon(category.iconKey),
            size: 11,
            color: category.color,
          ),
          const SizedBox(width: 5),
          Text(
            '${category.name} Category',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accentBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(TablerIcons.notes, size: 34, color: _primaryBlue),
          ),
          const SizedBox(height: 18),
          Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first task to build your offline productivity hub.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _badgeSecondaryText,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
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
            const Icon(TablerIcons.alert_circle, size: 36, color: _dangerText),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: _darkText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: TaskManagementScreen.retryButtonKey,
              style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

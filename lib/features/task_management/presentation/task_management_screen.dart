import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_reminder_scope.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_access.dart';
import '../../spaces/domain/task_space.dart';
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
    this.appBarTitle,
    this.lockedCategoryId,
    this.fixedSpaceId,
    this.fabLabel = 'Add Task',
    this.emptyTitle = 'No tasks yet',
    this.emptyMessage =
        'Create a task to start capturing notes, details, and schedules in one place.',
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
  static const Key statusDropdownKey = Key('task-management-status-dropdown');
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

  static Key statusFilterKey(String value) => Key('task-status-filter-$value');

  static Key categoryFilterKey(String id) => Key('task-category-filter-$id');

  static Key taskTileKey(String taskId) => Key('task-tile-$taskId');

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');

  static Key taskMenuButtonKey(String taskId) => Key('task-menu-$taskId');

  static Key taskMenuActionKey(String taskId, String action) =>
      Key('task-menu-$taskId-$action');

  final TaskRepository repository;
  final TaskManagementController controller;
  final String? appBarTitle;
  final String? lockedCategoryId;
  final String? fixedSpaceId;
  final String fabLabel;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  bool _isFiltersExpanded = true;

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
      showTaskToast(
        context,
        message: 'Add a category first before creating a task.',
        isError: true,
      );
      return;
    }

    final request = await Navigator.of(context).push<TaskCreationRequest>(
      MaterialPageRoute<TaskCreationRequest>(
        builder: (context) => TaskCreationScreen(
          repository: widget.repository,
          categories: _controller.categories,
          lockedCategoryId: widget.lockedCategoryId,
          spaceId: widget.fixedSpaceId,
          appBarTitle: widget.fixedSpaceId == null ? 'Add Task' : 'Add Space Task',
        ),
      ),
    );
    if (request == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      final vaultService = VaultServiceScope.of(context);
      final resolvedVaultConfig = await vaultService.resolveConfig(
        entityKey: 'task:create:${DateTime.now().microsecondsSinceEpoch}',
        draft: request.vaultDraft,
      );
      final task = await _controller.createTask(
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

      showTaskToast(context, message: 'Task created successfully.');
      await _openEditor(task.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to create the task right now.',
        isError: true,
      );
    }
  }

  Future<void> _openEditor(String taskId) async {
    final task = await widget.repository.getTaskById(taskId);
    if (!mounted || task == null) {
      return;
    }
    final vaultService = VaultServiceScope.of(context);
    final reminderService = TaskReminderScope.of(context);
    final parentSpace = _controller.spaceFor(task.spaceId);
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

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => TaskEditorScreen(
          repository: widget.repository,
          taskId: taskId,
          lockedCategoryId: widget.lockedCategoryId,
          fixedSpaceId: widget.fixedSpaceId,
          appBarTitle: widget.fixedSpaceId == null ? 'Task Notes' : 'Space Task',
          reminderService: reminderService,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _controller.load();
    if (!mounted) {
      return;
    }
    if (result == TaskEditorScreen.deletedResult) {
      showTaskToast(context, message: 'Task deleted successfully.');
    }
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final parentSpace = _controller.spaceFor(task.spaceId);
    if (!await _confirmVaultProtectedTaskAction(task, parentSpace: parentSpace)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteTaskDialog(taskTitle: task.title),
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await _controller.deleteTask(task.id);
      if (!mounted) {
        return;
      }

      showTaskToast(context, message: 'Task deleted successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to delete the task right now.',
        isError: true,
      );
    }
  }

  Future<bool> _confirmVaultProtectedTaskAction(
    TaskItem task, {
    TaskSpace? parentSpace,
  }) async {
    final vaultService = VaultServiceScope.of(context);

    if (task.vaultConfig != null) {
      final result = await ensureUnlocked(
        context: context,
        vaultService: vaultService,
        entityKey: taskVaultEntityKey(task.id),
        title: task.title,
        entityKind: VaultEntityKind.task,
        config: task.vaultConfig,
        forcePrompt: true,
      );
      if (!mounted) {
        return false;
      }
      if (result == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: taskDangerText,
        );
        return false;
      }
      if (result == VaultUnlockResult.cancelled) {
        return false;
      }
      if (result == VaultUnlockResult.unlocked) {
        showTaskToast(context, message: 'Unlocked successfully.');
      }
      return true;
    }

    if (parentSpace?.vaultConfig != null) {
      final result = await ensureUnlocked(
        context: context,
        vaultService: vaultService,
        entityKey: spaceVaultEntityKey(parentSpace!.id),
        title: parentSpace.name,
        entityKind: VaultEntityKind.space,
        config: parentSpace.vaultConfig,
        forcePrompt: true,
      );
      if (!mounted) {
        return false;
      }
      if (result == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: taskDangerText,
        );
        return false;
      }
      if (result == VaultUnlockResult.cancelled) {
        return false;
      }
      if (result == VaultUnlockResult.unlocked) {
        showTaskToast(context, message: 'Unlocked successfully.');
      }
    }

    return true;
  }

  Future<void> _moveTaskToSpace(TaskItem task) async {
    final spaces = await widget.repository.getSpaces();
    if (!mounted) {
      return;
    }

    final selectedSpaceId = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: taskMutedBorderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Move to Space',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: taskDarkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose where this task should live.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: taskSecondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                _SpaceDestinationTile(
                  title: 'No Space',
                  subtitle: 'Keep this task outside any space.',
                  isSelected: task.spaceId == null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                if (spaces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final space in spaces) ...[
                    _SpaceDestinationTile(
                      title: space.name,
                      subtitle: space.description.isEmpty
                          ? 'Category-based task space'
                          : space.description,
                      isSelected: task.spaceId == space.id,
                      accentColor: space.color,
                      onTap: () => Navigator.of(context).pop(space.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedSpaceId == null) {
      return;
    }

    TaskSpace? selectedSpace;
    if (selectedSpaceId.isNotEmpty) {
      for (final space in spaces) {
        if (space.id == selectedSpaceId) {
          selectedSpace = space;
          break;
        }
      }
    }

    try {
      await _controller.saveTask(
        task.copyWith(
          spaceId: selectedSpaceId.isEmpty ? null : selectedSpaceId,
          categoryId: selectedSpace?.categoryId ?? task.categoryId,
          clearSpaceId: selectedSpaceId.isEmpty,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) {
        return;
      }
      showTaskToast(context, message: 'Task moved successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to move the task right now.',
        isError: true,
      );
    }
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
        appBar: widget.appBarTitle == null
            ? null
            : AppBar(
                title: Text(widget.appBarTitle!),
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
              ),
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
                      _FiltersSection(
                        title: 'Filters',
                        subtitle:
                            'Search across task titles, note previews, and categories.',
                        isExpanded: _isFiltersExpanded,
                        onHeaderTap: () {
                          if (_isSelectionMode) {
                            _clearSelectionMode();
                            return;
                          }
                          setState(() {
                            _isFiltersExpanded = !_isFiltersExpanded;
                          });
                        },
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TaskCompactDropdown<TaskStatusFilter>(
                                    buttonKey: TaskManagementScreen
                                        .statusDropdownKey,
                                    menuKeyBuilder: (value) =>
                                        TaskManagementScreen.statusFilterKey(
                                          value.name,
                                        ),
                                    currentValue: _controller.statusFilter,
                                    currentLabel: _statusLabel(
                                      _controller.statusFilter,
                                    ),
                                    onSelected: _controller.updateStatusFilter,
                                    items: TaskStatusFilter.values,
                                    labelBuilder: _statusLabel,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TaskCompactDropdown<TaskPriorityFilter>(
                                    buttonKey: TaskManagementScreen
                                        .priorityDropdownKey,
                                    menuKeyBuilder: (value) =>
                                        TaskManagementScreen.priorityFilterKey(
                                          value.name,
                                        ),
                                    currentValue: _controller.priorityFilter,
                                    currentLabel: _priorityFilterLabel(
                                      _controller.priorityFilter,
                                    ),
                                    onSelected:
                                        _controller.updatePriorityFilter,
                                    items: TaskPriorityFilter.values,
                                    labelBuilder: _priorityFilterLabel,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.lockedCategoryId == null) ...[
                              const SizedBox(height: 12),
                              _CategoryFilterRow(
                                categories: _controller.categories,
                                selectedCategoryId: _controller.categoryFilterId,
                                onSelected: _controller.updateCategoryFilter,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (filteredTasks.isEmpty)
                        _EmptyState(
                          title: widget.emptyTitle,
                          message: widget.emptyMessage,
                        )
                      else
                        ...filteredTasks.map((task) {
                          final category = _controller.categoryFor(
                            task.categoryId,
                          );
                          final space = _controller.spaceFor(task.spaceId);
                          final previewProtected = isPreviewProtected(
                            vaultService: VaultServiceScope.of(context),
                            ownVault: task.vaultConfig,
                            ownEntityKey: taskVaultEntityKey(task.id),
                            inheritedVault: space?.vaultConfig,
                            inheritedEntityKey: space == null
                                ? null
                                : spaceVaultEntityKey(space.id),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _TaskCard(
                              task: task,
                              category: category,
                              space: space,
                              previewProtected: previewProtected,
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
                              onMenuSelected: (action) async {
                                switch (action) {
                                  case _TaskMenuAction.moveToSpace:
                                    await _moveTaskToSpace(task);
                                  case _TaskMenuAction.delete:
                                    await _confirmDelete(task);
                                }
                              },
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
          label: Text(widget.fabLabel),
        ),
      ),
    );
  }

  static String _priorityFilterLabel(TaskPriorityFilter filter) {
    return switch (filter) {
      TaskPriorityFilter.all => 'All Priority',
      TaskPriorityFilter.low => 'Low',
      TaskPriorityFilter.medium => 'Medium',
      TaskPriorityFilter.high => 'High',
      TaskPriorityFilter.urgent => 'Urgent',
    };
  }

  static String _statusLabel(TaskStatusFilter status) {
    return switch (status) {
      TaskStatusFilter.all => 'All Status',
      TaskStatusFilter.today => 'Today',
      TaskStatusFilter.upcoming => 'Upcoming',
      TaskStatusFilter.overdue => 'Overdue',
      TaskStatusFilter.completed => 'Completed',
    };
  }
}

enum _TaskMenuAction { moveToSpace, delete }

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
              icon: null,
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
  final IconData? icon;
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
        constraints: const BoxConstraints(
          minHeight: taskFilterControlHeight,
          maxHeight: taskFilterControlHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
            ],
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

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onHeaderTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool isExpanded;
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
                Icon(
                  isExpanded
                      ? TablerIcons.chevron_up
                      : TablerIcons.chevron_down,
                  size: 18,
                  color: taskMutedText,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.category,
    required this.space,
    required this.previewProtected,
    required this.showCheckbox,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
    required this.onMenuSelected,
  });

  final TaskItem task;
  final TaskCategory? category;
  final TaskSpace? space;
  final bool previewProtected;
  final bool showCheckbox;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final Future<void> Function(_TaskMenuAction action) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    const trailingSlotWidth = 28.0;
    const cardStackSpacing = 12.0;
    final accentColor = category?.color ?? taskPrimaryBlue;
    final descriptionText = previewProtected
        ? 'Protected content'
        : taskDescriptionPreview(task);
    final actualNotePreview = previewProtected ? '' : taskActualNotePreview(task);
    final noteText = actualNotePreview.isEmpty
        ? (previewProtected
              ? 'Protected content'
              : 'Open this task to start writing rich notes.')
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
                              if (task.vaultConfig?.isEnabled == true ||
                                  space?.vaultConfig?.isEnabled == true) ...[
                                const SizedBox(height: 6),
                                const Icon(
                                  TablerIcons.lock,
                                  size: 14,
                                  color: taskMutedText,
                                ),
                              ],
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
                            child: PopupMenuButton<_TaskMenuAction>(
                              key: TaskManagementScreen.taskMenuButtonKey(
                                task.id,
                              ),
                              color: Colors.white,
                              surfaceTintColor: Colors.white,
                              onSelected: (value) => onMenuSelected(value),
                              itemBuilder: (context) => [
                                const PopupMenuItem<_TaskMenuAction>(
                                  value: _TaskMenuAction.moveToSpace,
                                  child: Text('Move to Space'),
                                ),
                                PopupMenuItem<_TaskMenuAction>(
                                  value: _TaskMenuAction.delete,
                                  child: Text(
                                    'Delete',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: taskDangerText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              icon: const Icon(
                                TablerIcons.dots_vertical,
                                size: 18,
                                color: taskMutedText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: cardStackSpacing),
                    if (category != null || space != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (category != null) _CategoryBadge(category: category!),
                          if (space != null) _SpaceBadge(space: space!),
                        ],
                      ),
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

class _SpaceBadge extends StatelessWidget {
  const _SpaceBadge({required this.space});

  final TaskSpace space;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: space.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TablerIcons.folder,
            size: 12,
            color: space.color,
          ),
          const SizedBox(width: 6),
          Text(
            space.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: space.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceDestinationTile extends StatelessWidget {
  const _SpaceDestinationTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tone = accentColor ?? taskPrimaryBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? tone.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? tone : taskBorderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                TablerIcons.folder,
                color: tone,
                size: 18,
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: taskMutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                TablerIcons.check,
                color: tone,
                size: 18,
              ),
          ],
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
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

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
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: taskDangerText,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Task',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: taskDangerText,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Deleting "$taskTitle" will remove the task and its notes from your device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: taskSecondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFFF1F3F5),
                      foregroundColor: taskDarkText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: taskDangerText,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Delete Task'),
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

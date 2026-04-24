import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_data_refresh_scope.dart';
import '../../../core/services/task_reminder_scope.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/vault/vault_access.dart';
import '../../../shared/widgets/app_decision_dialog.dart';
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
    this.space,
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
  static const Key statusDropdownKey = Key('task-management-status-dropdown');
  static const Key allCategoriesKey = Key('task-category-filter-all');
  static const Key moveToSpaceCancelButtonKey = Key(
    'task-move-to-space-cancel',
  );
  static const Key moveToSpaceConfirmButtonKey = Key(
    'task-move-to-space-confirm',
  );
  static const Key moveToSpaceNoSpaceKey = Key('task-move-to-space-no-space');
  static const Key createTitleFieldKey = Key('task-create-title-field');
  static const Key createDescriptionFieldKey = Key(
    'task-create-description-field',
  );
  static const Key createPriorityFieldKey = Key('task-create-priority-field');
  static const Key createCategoryFieldKey = Key('task-create-category-field');
  static const Key createSubmitButtonKey = Key('task-create-submit-button');

  static Key statusFilterKey(String value) => Key('task-status-filter-$value');

  static Key categoryFilterKey(String id) => Key('task-category-filter-$id');

  static Key taskTileKey(String taskId) => Key('task-tile-$taskId');

  static Key taskToggleKey(String taskId) => Key('task-toggle-$taskId');

  static Key taskMenuButtonKey(String taskId) => Key('task-menu-$taskId');

  static Key taskMenuActionKey(String taskId, String action) =>
      Key('task-menu-$taskId-$action');

  static Key moveToSpaceOptionKey(String spaceId) =>
      Key('task-move-to-space-$spaceId');

  final TaskRepository repository;
  final TaskManagementController controller;
  final String? appBarTitle;
  final TaskSpace? space;
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
  TaskDataRefreshController? _taskDataRefreshController;

  TaskManagementController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_controller.tasks.isEmpty && _controller.categories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.load();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _searchController.dispose();
    super.dispose();
  }

  void _handleTaskDataRefresh() {
    if (!mounted || _controller.isLoading || _controller.isSaving) {
      return;
    }
    _controller.load();
  }

  void _clearSelectionMode() {
    if (!_isSelectionMode) {
      return;
    }
    setState(() {
      _isSelectionMode = false;
    });
  }

  bool get _isCurrentSpaceUnlocked {
    final currentSpace =
        widget.space ?? _controller.spaceFor(widget.fixedSpaceId);
    if (currentSpace?.vaultConfig?.isEnabled != true) {
      return false;
    }
    return VaultServiceScope.of(
      context,
    ).isUnlocked(spaceVaultEntityKey(currentSpace!.id));
  }

  Future<void> _toggleCurrentSpaceVault() async {
    final currentSpace =
        widget.space ?? _controller.spaceFor(widget.fixedSpaceId);
    if (currentSpace?.vaultConfig?.isEnabled != true) {
      return;
    }

    final vaultService = VaultServiceScope.of(context);
    final entityKey = spaceVaultEntityKey(currentSpace!.id);

    if (vaultService.isUnlocked(entityKey)) {
      vaultService.clearUnlocked(entityKey);
      if (!mounted) {
        return;
      }
      setState(() {});
      showTaskToast(context, message: 'Space locked again.');
      return;
    }

    final result = await ensureUnlocked(
      context: context,
      vaultService: vaultService,
      entityKey: entityKey,
      title: currentSpace.name,
      entityKind: VaultEntityKind.space,
      config: currentSpace.vaultConfig,
      onRecoveryReset: (resolution) async {
        final config = resolution.config;
        if (config == null) {
          return;
        }
        await widget.repository.upsertSpace(
          currentSpace.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
        );
        await _controller.load();
      },
    );
    if (!mounted) {
      return;
    }
    if (result == VaultUnlockResult.failed) {
      showTaskToast(
        context,
        message: 'Incorrect vault password or PIN.',
        backgroundColor: AppColors.rose100,
        foregroundColor: AppColors.rose500,
      );
      return;
    }
    if (result == VaultUnlockResult.lockedOut) {
      return;
    }
    if (result == VaultUnlockResult.cancelled) {
      return;
    }
    if (result == VaultUnlockResult.unlocked) {
      setState(() {});
      showTaskToast(context, message: 'Space unlocked successfully.');
    }
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
          appBarTitle: widget.fixedSpaceId == null
              ? 'Add Task'
              : 'Add Space Task',
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
      final vaultResolution = await vaultService.resolveConfig(
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
        vaultConfig: vaultResolution.config,
      );
      if (!mounted) {
        return;
      }

      showTaskToast(context, message: 'Task created successfully.');
      if (vaultResolution.recoveryKeys.isNotEmpty) {
        await showVaultRecoveryKeysDialog(
          context: context,
          recoveryKeys: vaultResolution.recoveryKeys,
        );
        if (!mounted) {
          return;
        }
      }
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
      onRecoveryReset: (resolution) async {
        final config = resolution.config;
        if (config == null) {
          return;
        }
        await widget.repository.upsertTask(
          task.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
        );
        await _controller.load();
      },
    );
    if (!mounted) {
      return;
    }
    if (taskUnlockResult == VaultUnlockResult.failed) {
      showTaskToast(
        context,
        message: 'Incorrect vault password or PIN.',
        backgroundColor: AppColors.rose100,
        foregroundColor: AppColors.rose500,
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
          await widget.repository.upsertSpace(
            parentSpace.copyWith(
              vaultConfig: config,
              updatedAt: DateTime.now(),
            ),
          );
          await _controller.load();
        },
      );
      if (!mounted) {
        return;
      }
      if (spaceUnlockResult == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: AppColors.rose100,
          foregroundColor: AppColors.rose500,
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
          repository: widget.repository,
          taskId: taskId,
          lockedCategoryId: widget.lockedCategoryId,
          fixedSpaceId: widget.fixedSpaceId,
          appBarTitle: widget.fixedSpaceId == null
              ? 'Task Notes'
              : 'Space Task',
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
    } else if (result == TaskEditorScreen.archivedResult) {
      showTaskToast(context, message: 'Task archived successfully.');
    }
  }

  Future<void> _confirmDelete(TaskItem task) async {
    final parentSpace = _controller.spaceFor(task.spaceId);
    if (!await _confirmVaultProtectedTaskAction(
      task,
      parentSpace: parentSpace,
    )) {
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

  Future<void> _archiveTask(TaskItem task) async {
    final parentSpace = _controller.spaceFor(task.spaceId);
    if (!await _confirmVaultProtectedTaskAction(
      task,
      parentSpace: parentSpace,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final shouldArchive = await showArchiveConfirmationDialog(
      context: context,
      itemLabel: 'Task',
      itemName: task.title,
    );
    if (!shouldArchive) {
      return;
    }

    try {
      await _controller.archiveTask(task);
      if (!mounted) {
        return;
      }
      TaskDataRefreshScope.of(context).notifyDataChanged();
      showTaskToast(context, message: 'Task archived successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to archive the task right now.',
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
        onRecoveryReset: (resolution) async {
          final config = resolution.config;
          if (config == null) {
            return;
          }
          await widget.repository.upsertTask(
            task.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
          );
          await _controller.load();
        },
      );
      if (!mounted) {
        return false;
      }
      if (result == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: AppColors.rose100,
          foregroundColor: AppColors.rose500,
        );
        return false;
      }
      if (result == VaultUnlockResult.lockedOut) {
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
        onRecoveryReset: (resolution) async {
          final config = resolution.config;
          if (config == null) {
            return;
          }
          await widget.repository.upsertSpace(
            parentSpace.copyWith(
              vaultConfig: config,
              updatedAt: DateTime.now(),
            ),
          );
          await _controller.load();
        },
      );
      if (!mounted) {
        return false;
      }
      if (result == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: AppColors.rose100,
          foregroundColor: AppColors.rose500,
        );
        return false;
      }
      if (result == VaultUnlockResult.lockedOut) {
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
    final currentSpace = _controller.spaceFor(task.spaceId);
    if (!await _confirmVaultProtectedTaskAction(
      task,
      parentSpace: currentSpace,
    )) {
      return;
    }

    final spaces = (await widget.repository.getSpaces())
        .where((space) => !space.isArchived)
        .toList();
    if (!mounted) {
      return;
    }

    final selectedSpaceId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.threeXl),
        ),
      ),
      builder: (context) => _MoveTaskToSpaceSheet(
        task: task,
        spaces: spaces,
        categoryFor: _controller.categoryFor,
      ),
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

    if (selectedSpace != null &&
        selectedSpace.categoryId != task.categoryId &&
        !await _confirmCategoryChangeForMove(task, selectedSpace)) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (selectedSpace?.vaultConfig != null) {
      final destinationSpace = selectedSpace!;
      final result = await ensureUnlocked(
        context: context,
        vaultService: VaultServiceScope.of(context),
        entityKey: spaceVaultEntityKey(destinationSpace.id),
        title: destinationSpace.name,
        entityKind: VaultEntityKind.space,
        config: destinationSpace.vaultConfig,
        forcePrompt: true,
        onRecoveryReset: (resolution) async {
          final config = resolution.config;
          if (config == null) {
            return;
          }
          await widget.repository.upsertSpace(
            destinationSpace.copyWith(
              vaultConfig: config,
              updatedAt: DateTime.now(),
            ),
          );
          await _controller.load();
        },
      );
      if (!mounted) {
        return;
      }
      if (result == VaultUnlockResult.failed) {
        showTaskToast(
          context,
          message: 'Incorrect vault password or PIN.',
          backgroundColor: AppColors.rose100,
          foregroundColor: AppColors.rose500,
        );
        return;
      }
      if (result == VaultUnlockResult.lockedOut ||
          result == VaultUnlockResult.cancelled) {
        return;
      }
      if (result == VaultUnlockResult.unlocked) {
        showTaskToast(context, message: 'Unlocked successfully.');
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

  Future<bool> _confirmCategoryChangeForMove(
    TaskItem task,
    TaskSpace destinationSpace,
  ) async {
    final currentCategory =
        _controller.categoryFor(task.categoryId)?.name ?? 'Current category';
    final destinationCategory =
        _controller.categoryFor(destinationSpace.categoryId)?.name ??
        'Destination category';
    final shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) => _MoveCategoryChangeDialog(
        taskTitle: task.title,
        spaceName: destinationSpace.name,
        currentCategory: currentCategory,
        destinationCategory: destinationCategory,
      ),
    );
    return shouldMove == true;
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
        backgroundColor: AppColors.background,
        appBar: widget.appBarTitle == null
            ? null
            : AppBar(
                title: Text(widget.appBarTitle!),
                backgroundColor: AppColors.cardFill,
                surfaceTintColor: AppColors.cardFill,
                actions: [
                  if ((widget.space ??
                              _controller.spaceFor(widget.fixedSpaceId))
                          ?.vaultConfig
                          ?.isEnabled ==
                      true)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Material(
                        color: _isCurrentSpaceUnlocked
                            ? AppColors.blue100
                            : AppColors.rose100,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          onTap: _toggleCurrentSpaceVault,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _isCurrentSpaceUnlocked
                                  ? TablerIcons.lock_open
                                  : TablerIcons.lock,
                              size: 18,
                              color: _isCurrentSpaceUnlocked
                                  ? AppColors.blue500
                                  : AppColors.rose500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
                  color: AppColors.blue500,
                  onRefresh: _controller.load,
                  child: CustomScrollView(
                    slivers: [
                      if (filteredTasks.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.four,
                            AppSpacing.six,
                            AppSpacing.four,
                            AppSpacing.zero,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _TaskPageHeader(),
                                const SizedBox(height: AppSpacing.six),
                                _SearchField(
                                  controller: _searchController,
                                  onChanged: _controller.updateSearchQuery,
                                ),
                                if (widget.lockedCategoryId == null) ...[
                                  const SizedBox(height: AppSpacing.three),
                                  _CategoryFilterRow(
                                    categories: _controller.categories,
                                    selectedCategoryId:
                                        _controller.categoryFilterId,
                                    onSelected:
                                        _controller.updateCategoryFilter,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.four,
                            AppSpacing.six,
                            AppSpacing.four,
                            120,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index == 0) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _TaskPageHeader(),
                                    const SizedBox(height: AppSpacing.six),
                                    _SearchField(
                                      controller: _searchController,
                                      onChanged: _controller.updateSearchQuery,
                                    ),
                                    if (widget.lockedCategoryId == null) ...[
                                      const SizedBox(height: AppSpacing.three),
                                      _CategoryFilterRow(
                                        categories: _controller.categories,
                                        selectedCategoryId:
                                            _controller.categoryFilterId,
                                        onSelected:
                                            _controller.updateCategoryFilter,
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.six),
                                  ],
                                );
                              }

                              final task = filteredTasks[index - 1];
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
                                padding: EdgeInsets.only(
                                  bottom: index == filteredTasks.length
                                      ? AppSpacing.zero
                                      : AppSpacing.four,
                                ),
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
                                      case _TaskMenuAction.archive:
                                        await _archiveTask(task);
                                      case _TaskMenuAction.delete:
                                        await _confirmDelete(task);
                                    }
                                  },
                                ),
                              );
                            }, childCount: filteredTasks.length + 1),
                          ),
                        ),
                      if (filteredTasks.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.four,
                              AppSpacing.zero,
                              AppSpacing.four,
                              120,
                            ),
                            child: Center(
                              child: _EmptyState(
                                title: widget.emptyTitle,
                                message: widget.emptyMessage,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: TaskManagementScreen.addTaskFabKey,
          heroTag: 'task-management-add-task-fab',
          onPressed: _controller.isSaving ? null : _openCreateFlow,
          backgroundColor: AppColors.primaryButtonFill,
          foregroundColor: AppColors.primaryButtonText,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          disabledElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              taskButtonRadius(TaskButtonSize.large),
            ),
          ),
          extendedPadding: taskButtonPadding(TaskButtonSize.large),
          extendedTextStyle: taskButtonTextStyle(context, TaskButtonSize.large),
          icon: const Icon(TablerIcons.plus, size: 18),
          label: Text(widget.fabLabel),
        ),
      ),
    );
  }
}

enum _TaskMenuAction { moveToSpace, archive, delete }

class _MoveTaskToSpaceSheet extends StatefulWidget {
  const _MoveTaskToSpaceSheet({
    required this.task,
    required this.spaces,
    required this.categoryFor,
  });

  final TaskItem task;
  final List<TaskSpace> spaces;
  final TaskCategory? Function(String categoryId) categoryFor;

  @override
  State<_MoveTaskToSpaceSheet> createState() => _MoveTaskToSpaceSheetState();
}

class _MoveTaskToSpaceSheetState extends State<_MoveTaskToSpaceSheet> {
  String? _selectedSpaceId;

  @override
  void initState() {
    super.initState();
    _selectedSpaceId = widget.task.spaceId;
  }

  void _selectSpace(String? spaceId) {
    setState(() {
      _selectedSpaceId = spaceId;
    });
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selectedSpaceId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinationCount = widget.spaces.length + 1;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final needsScroll = destinationCount > 6;

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: taskMutedBorderColor,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.five),
        Text(
          'Move to Space',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.titleText,
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
        const SizedBox(height: AppSpacing.oneAndHalf),
        Text(
          'Choose where this task should live.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.subHeaderText,
          ),
        ),
        const SizedBox(height: AppSpacing.four),
      ],
    );

    final footer = Row(
      children: [
        Expanded(
          child: FilledButton(
            key: TaskManagementScreen.moveToSpaceCancelButtonKey,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.secondary,
              size: TaskButtonSize.medium,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.five,
                vertical: AppSpacing.three,
              ),
              shrinkTapTarget: true,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.three),
        Expanded(
          child: FilledButton(
            key: TaskManagementScreen.moveToSpaceConfirmButtonKey,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.medium,
              minimumSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.five,
                vertical: AppSpacing.three,
              ),
              shrinkTapTarget: true,
            ),
            onPressed: _confirmSelection,
            child: const Text('Move to space'),
          ),
        ),
      ],
    );

    final list = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: destinationCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SpaceDestinationTile(
            key: TaskManagementScreen.moveToSpaceNoSpaceKey,
            title: 'No Space',
            subtitle: 'Keep this task outside any space.',
            isSelected: _selectedSpaceId == null,
            onTap: () => _selectSpace(null),
            accentColor: AppColors.neutral400,
            isNeutral: true,
          );
        }

        final space = widget.spaces[index - 1];
        final category = widget.categoryFor(space.categoryId);
        return _SpaceDestinationTile(
          key: TaskManagementScreen.moveToSpaceOptionKey(space.id),
          title: space.name,
          pillLabel: category?.name ?? 'Badge',
          isSelected: _selectedSpaceId == space.id,
          accentColor: space.color,
          onTap: () => _selectSpace(space.id),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.twoAndHalf),
    );

    final scrollableList = ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      itemCount: destinationCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SpaceDestinationTile(
            key: TaskManagementScreen.moveToSpaceNoSpaceKey,
            title: 'No Space',
            subtitle: 'Keep this task outside any space.',
            isSelected: _selectedSpaceId == null,
            onTap: () => _selectSpace(null),
            accentColor: AppColors.neutral400,
            isNeutral: true,
          );
        }

        final space = widget.spaces[index - 1];
        final category = widget.categoryFor(space.categoryId);
        return _SpaceDestinationTile(
          key: TaskManagementScreen.moveToSpaceOptionKey(space.id),
          title: space.name,
          pillLabel: category?.name ?? 'Badge',
          isSelected: _selectedSpaceId == space.id,
          accentColor: space.color,
          onTap: () => _selectSpace(space.id),
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.twoAndHalf),
    );

    final shortSheet = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.five,
        AppSpacing.four,
        AppSpacing.five,
        AppSpacing.five,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          list,
          const SizedBox(height: AppSpacing.four),
          footer,
        ],
      ),
    );

    final tallSheet = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.five,
          AppSpacing.four,
          AppSpacing.five,
          AppSpacing.five,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(child: scrollableList),
              const SizedBox(height: AppSpacing.four),
              footer,
            ],
          ),
        ),
      ),
    );

    return needsScroll ? tallSheet : shortSheet;
  }
}

class _TaskPageHeader extends StatelessWidget {
  const _TaskPageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.one),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Tasks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.titleText,
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
          const SizedBox(height: AppSpacing.one),
          Text(
            'Organize and manage your tasks',
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
        hintText: 'Search your tasks',
        prefixIcon: const Icon(
          TablerIcons.search,
          size: 18,
          color: AppColors.subHeaderText,
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
                  ? AppColors.primaryButtonText
                  : AppColors.subHeaderText,
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
                icon: null,
                iconColor: selectedCategoryId == category.id
                    ? AppColors.primaryButtonText
                    : AppColors.subHeaderText,
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
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.three,
          vertical: AppSpacing.two,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryButtonFill : AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: selected
                ? AppColors.primaryButtonFill
                : AppColors.neutral200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: AppSpacing.oneAndHalf),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? AppColors.primaryButtonText
                    : AppColors.subHeaderText,
                fontSize: AppTypography.sizeSm,
                fontWeight: AppTypography.weightNormal,
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
    final descriptionText = previewProtected
        ? 'Locked Content'
        : taskDescriptionPreview(task);
    final actualNotePreview = previewProtected
        ? ''
        : taskActualNotePreview(task);
    final previewText = descriptionText.isEmpty
        ? (previewProtected
              ? 'Locked Content'
              : 'Open this task to start writing rich notes.')
        : descriptionText;
    final shouldShowNotePreview =
        !previewProtected &&
        actualNotePreview.isNotEmpty &&
        actualNotePreview != descriptionText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: TaskManagementScreen.taskTileKey(task.id),
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.eight,
            vertical: AppSpacing.six,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardFill,
            borderRadius: BorderRadius.circular(AppRadii.threeXl),
            border: Border.all(
              color: AppColors.cardBorder,
              width: AppSizes.borderDefault,
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
                        padding: const EdgeInsets.only(top: AppSpacing.two),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.defaultRadius,
                                ),
                              ),
                              side: const BorderSide(
                                color: AppColors.blue200,
                                width: AppSizes.borderDefault,
                              ),
                              fillColor: WidgetStatePropertyAll(
                                AppColors.blue500,
                              ),
                              checkColor: WidgetStatePropertyAll(
                                AppColors.blue50,
                              ),
                            ),
                          ),
                          child: Checkbox(
                            key: TaskManagementScreen.taskToggleKey(task.id),
                            value: task.isCompleted,
                            onChanged: (_) => onToggle(),
                            activeColor: AppColors.blue500,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('hidden-checkbox')),
              ),
              if (showCheckbox) const SizedBox(width: AppSpacing.three),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.titleText,
                                      fontSize: AppTypography.sizeLg,
                                      fontWeight: AppTypography.weightSemibold,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.one),
                              _TaskPreviewLine(
                                text: previewText,
                                isLocked: previewProtected,
                              ),
                              if (shouldShowNotePreview) ...[
                                const SizedBox(height: AppSpacing.one),
                                Text(
                                  actualNotePreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.subHeaderText,
                                        fontSize: AppTypography.sizeBase,
                                        fontWeight: AppTypography.weightNormal,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.three),
                        SizedBox(
                          width: trailingSlotWidth,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: PopupMenuButton<_TaskMenuAction>(
                              key: TaskManagementScreen.taskMenuButtonKey(
                                task.id,
                              ),
                              color: AppColors.cardFill,
                              surfaceTintColor: AppColors.cardFill,
                              onSelected: (value) => onMenuSelected(value),
                              itemBuilder: (context) => [
                                PopupMenuItem<_TaskMenuAction>(
                                  key: TaskManagementScreen.taskMenuActionKey(
                                    task.id,
                                    'move-to-space',
                                  ),
                                  value: _TaskMenuAction.moveToSpace,
                                  child: const TaskMenuEntry(
                                    icon: TablerIcons.folder,
                                    label: 'Move to Space',
                                  ),
                                ),
                                PopupMenuItem<_TaskMenuAction>(
                                  key: TaskManagementScreen.taskMenuActionKey(
                                    task.id,
                                    'archive',
                                  ),
                                  value: _TaskMenuAction.archive,
                                  child: const TaskMenuEntry(
                                    icon: TablerIcons.archive,
                                    label: 'Archive',
                                  ),
                                ),
                                PopupMenuItem<_TaskMenuAction>(
                                  key: TaskManagementScreen.taskMenuActionKey(
                                    task.id,
                                    'delete',
                                  ),
                                  value: _TaskMenuAction.delete,
                                  child: const TaskMenuEntry(
                                    icon: TablerIcons.trash,
                                    label: 'Delete',
                                    color: AppColors.rose500,
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
                                color: AppColors.subHeaderText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.three),
                    if (category != null || space != null) ...[
                      Wrap(
                        spacing: AppSpacing.two,
                        runSpacing: AppSpacing.two,
                        children: [
                          if (task.vaultConfig?.isEnabled == true ||
                              space?.vaultConfig?.isEnabled == true)
                            const _LockedBadge(),
                          if (category != null)
                            _CategoryBadge(category: category!),
                          if (space != null) _SpaceBadge(space: space!),
                        ],
                      ),
                    ],
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

class _TaskPreviewLine extends StatelessWidget {
  const _TaskPreviewLine({required this.text, required this.isLocked});

  final String text;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.subHeaderText,
      fontSize: AppTypography.sizeBase,
      fontWeight: AppTypography.weightNormal,
    );

    if (!isLocked) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    return Row(
      children: [
        const Icon(TablerIcons.lock, size: 18, color: AppColors.subHeaderText),
        const SizedBox(width: AppSpacing.two),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

class _SpaceBadge extends StatelessWidget {
  const _SpaceBadge({required this.space});

  final TaskSpace space;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.twoAndHalf,
        vertical: AppSpacing.oneAndHalf,
      ),
      decoration: BoxDecoration(
        color: space.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.folder, size: 12, color: space.color),
          const SizedBox(width: AppSpacing.oneAndHalf),
          Text(
            space.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: space.color,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.twoAndHalf,
        vertical: AppSpacing.oneAndHalf,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            TablerIcons.lock,
            size: 12,
            color: AppColors.subHeaderText,
          ),
          const SizedBox(width: AppSpacing.oneAndHalf),
          Text(
            'Locked',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.subHeaderText,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceDestinationTile extends StatelessWidget {
  const _SpaceDestinationTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
    this.subtitle,
    this.pillLabel,
    this.isNeutral = false,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? subtitle;
  final String? pillLabel;
  final bool isNeutral;

  @override
  Widget build(BuildContext context) {
    final tone = accentColor ?? taskPrimaryBlue;
    final badgeTone = isNeutral ? AppColors.neutral400 : tone;
    final badgeFill = isNeutral
        ? AppColors.neutral100
        : tone.withValues(alpha: 0.12);
    final borderColor = isSelected ? tone : AppColors.checkboxCardBorder;
    final backgroundColor = isSelected
        ? tone.withValues(alpha: isNeutral ? 0.08 : 0.12)
        : AppColors.cardFill;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.three),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadii.twoXl),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: badgeFill,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(TablerIcons.folder, color: badgeTone, size: 18),
              ),
              const SizedBox(width: AppSpacing.three),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.titleText,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    if (pillLabel != null) ...[
                      const SizedBox(height: AppSpacing.one),
                      _SpaceBadgePill(label: pillLabel!, tone: tone),
                    ] else if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.one),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subHeaderText,
                        ),
                      ),
                    ],
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

class _SpaceBadgePill extends StatelessWidget {
  const _SpaceBadgePill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.twoAndHalf,
        vertical: AppSpacing.one,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.home_2, size: 12, color: tone),
          const SizedBox(width: AppSpacing.oneAndHalf),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.twoAndHalf,
        vertical: AppSpacing.oneAndHalf,
      ),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolveTaskCategoryIcon(category.iconKey),
            size: 12,
            color: category.color,
          ),
          const SizedBox(width: AppSpacing.oneAndHalf),
          Text(
            category.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: category.color,
              fontWeight: AppTypography.weightSemibold,
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
    return Column(
      key: TaskManagementScreen.emptyStateKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: taskAccentBlue,
            borderRadius: BorderRadius.circular(AppRadii.threeXl),
          ),
          child: const Icon(
            TablerIcons.notes,
            size: 34,
            color: taskPrimaryBlue,
          ),
        ),
        const SizedBox(height: AppSpacing.five),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.titleText,
            fontWeight: AppTypography.weightSemibold,
          ),
        ),
        const SizedBox(height: AppSpacing.two),
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.subHeaderText),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DeleteTaskDialog extends StatelessWidget {
  const _DeleteTaskDialog({required this.taskTitle});

  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    return AppDecisionDialog(
      tone: AppDecisionTone.danger,
      icon: TablerIcons.alert_triangle,
      title: 'Delete Task?',
      message:
          'Are you sure you want to delete this task? This action cannot be undone.',
      secondaryLabel: 'Cancel',
      primaryLabel: 'Yes, Delete',
      onSecondaryPressed: () => Navigator.of(context).pop(false),
      onPrimaryPressed: () => Navigator.of(context).pop(true),
    );
  }
}

class _MoveCategoryChangeDialog extends StatelessWidget {
  const _MoveCategoryChangeDialog({
    required this.taskTitle,
    required this.spaceName,
    required this.currentCategory,
    required this.destinationCategory,
  });

  final String taskTitle;
  final String spaceName;
  final String currentCategory;
  final String destinationCategory;

  @override
  Widget build(BuildContext context) {
    return AppDecisionDialog(
      tone: AppDecisionTone.primary,
      icon: Icons.drive_file_move_rounded,
      title: 'Move Task?',
      message:
          'This task will be moved to another space. You can still access and edit it there.',
      secondaryLabel: 'Cancel',
      primaryLabel: 'Yes, Move',
      onSecondaryPressed: () => Navigator.of(context).pop(false),
      onPrimaryPressed: () => Navigator.of(context).pop(true),
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
              style: taskButtonStyle(
                context,
                role: TaskButtonRole.primary,
                size: TaskButtonSize.medium,
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

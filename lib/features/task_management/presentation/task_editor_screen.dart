import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/task_reminder_service.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_access.dart';
import '../../../core/vault/vault_models.dart';
import '../data/task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import '../../spaces/domain/task_space.dart';
import 'task_management_ui.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.repository,
    required this.taskId,
    this.lockedCategoryId,
    this.fixedSpaceId,
    this.appBarTitle = 'Task Notes',
    TaskReminderService? reminderService,
  }) : reminderService = reminderService ?? const NoopTaskReminderService();

  static const String deletedResult = 'deleted';
  static const String archivedResult = 'archived';
  static const Key markerKey = Key('task-editor-screen');
  static const Key titleFieldKey = Key('task-editor-title-field');
  static const Key descriptionFieldKey = Key('task-editor-body');
  static const Key editorBodyKey = Key('task-editor-body');
  static const Key dateRangeButtonKey = Key('task-editor-date-range-button');
  static const Key timeRangeButtonKey = Key('task-editor-time-range-button');
  static const Key categoryFieldKey = Key('task-editor-category-field');
  static const Key priorityFieldKey = Key('task-editor-priority-field');
  static const Key addCategoryButtonKey = Key('task-editor-add-category');
  static const Key saveButtonKey = Key('task-editor-save-button');
  static const Key autosaveStatusKey = Key('task-editor-autosave-status');
  static const Key metadataCardKey = Key('task-editor-metadata-card');
  static const Key viewDetailsButtonKey = Key('task-editor-view-details');
  static const Key editDetailsButtonKey = Key('task-editor-edit-details');
  static const Key deleteButtonKey = Key('task-editor-delete');
  static const Key archiveButtonKey = Key('task-editor-archive');

  final TaskRepository repository;
  final String taskId;
  final String? lockedCategoryId;
  final String? fixedSpaceId;
  final String appBarTitle;
  final TaskReminderService reminderService;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

enum _EditorMenuAction { viewDetails, edit, archive, delete }

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _titleController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  quill.QuillController? _noteController;
  TaskItem? _task;
  TaskSpace? _parentSpace;
  List<TaskCategory> _categories = [];
  Timer? _autosaveTimer;
  bool _isLoading = true;
  bool _isHydrating = false;
  bool _isPersisting = false;
  bool _hasPendingChanges = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleAutosave);
    _loadEditorState();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController
      ..removeListener(_scheduleAutosave)
      ..dispose();
    _noteController?.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEditorState() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final task = await widget.repository.getTaskById(widget.taskId);
      final categories = await widget.repository.getCategories();
      if (!mounted) {
        return;
      }

      if (task == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'This task could not be found.';
        });
        return;
      }

      final parentSpace = task.spaceId == null
          ? null
          : await widget.repository.getSpaceById(task.spaceId!);
      if (!mounted) {
        return;
      }

      _bindTask(task: task, categories: categories, parentSpace: parentSpace);
      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to open this task right now.';
      });
    }
  }

  void _bindTask({
    required TaskItem task,
    required List<TaskCategory> categories,
    required TaskSpace? parentSpace,
  }) {
    _isHydrating = true;
    _noteController?.removeListener(_scheduleAutosave);
    _noteController?.dispose();

    _task = task;
    _parentSpace = parentSpace;
    _categories = categories;

    final document = quill.Document.fromJson(
      jsonDecode(
            normalizeNoteDocumentJson(
              task.noteDocumentJson,
              fallbackText: task.description,
            ),
          )
          as List,
    );
    final noteController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    noteController.addListener(_scheduleAutosave);
    _noteController = noteController;
    _isHydrating = false;
  }

  void _scheduleAutosave() {
    if (_isHydrating || _task == null) {
      return;
    }

    _hasPendingChanges = true;

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 800),
      _persistPendingChanges,
    );
  }

  Future<bool> _persistPendingChanges() async {
    if (_task == null) {
      return false;
    }

    _autosaveTimer?.cancel();
    if (_isPersisting) {
      return true;
    }
    if (!_hasPendingChanges) {
      return true;
    }

    final noteController = _noteController;
    if (noteController == null) {
      return false;
    }

    _isPersisting = true;
    _hasPendingChanges = false;

    final documentJson = jsonEncode(noteController.document.toDelta().toJson());
    final previousTask = _task!;
    final draft = previousTask.copyWith(
      noteDocumentJson: documentJson,
      notePlainText: extractPlainTextFromNoteDocumentJson(documentJson),
      updatedAt: DateTime.now(),
    );

    try {
      await widget.repository.upsertTask(draft);
      await widget.reminderService.syncTaskIfSchedulingChanged(
        previous: previousTask,
        next: draft,
      );
      final latest = await widget.repository.getTaskById(draft.id) ?? draft;
      if (!mounted) {
        return true;
      }

      setState(() {
        _task = latest;
      });
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      _hasPendingChanges = true;
      return false;
    } finally {
      _isPersisting = false;
      if (_hasPendingChanges) {
        _scheduleAutosave();
      }
    }
  }

  Future<bool> _flushBeforeExit() async {
    final success = await _persistPendingChanges();
    if (!success && mounted) {
      showTaskToast(
        context,
        message: 'The latest note changes could not be saved yet.',
        isError: true,
      );
    }
    return success;
  }

  Future<bool> _handleWillPop() async {
    if (_isLoading) {
      return false;
    }
    return _flushBeforeExit();
  }

  Future<void> _openDetailsSheet() async {
    final task = _task;
    if (task == null) {
      return;
    }
    if (!await _confirmVaultProtectedAction(task)) {
      return;
    }
    if (!mounted) {
      return;
    }

    final result = await Navigator.of(context).push<_TaskDetailsResult>(
      MaterialPageRoute<_TaskDetailsResult>(
        builder: (context) => _TaskDetailsSheet(
          repository: widget.repository,
          task: task,
          categories: _categories,
          lockedCategoryId: widget.lockedCategoryId,
          fixedSpaceId: widget.fixedSpaceId,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      VaultConfig? nextVaultConfig = task.vaultConfig;
      List<String> recoveryKeys = const [];
      if (!result.vaultDraft.preserveExistingConfig) {
        final vaultService = VaultServiceScope.of(context);
        final vaultResolution = await vaultService.resolveConfig(
          entityKey: 'task:${result.task.id}',
          draft: result.vaultDraft,
          existingConfig: task.vaultConfig,
        );
        nextVaultConfig = vaultResolution.config;
        recoveryKeys = vaultResolution.recoveryKeys;
      }
      final updatedTask = result.task.copyWith(
        vaultConfig: nextVaultConfig,
        clearVaultConfig:
            !result.vaultDraft.preserveExistingConfig &&
            nextVaultConfig == null,
      );
      await widget.repository.upsertTask(updatedTask);
      await widget.reminderService.syncTask(updatedTask);
      final latest = await widget.repository.getTaskById(updatedTask.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _task = latest ?? updatedTask;
        _categories = result.categories;
      });
      showTaskToast(context, message: 'Task updated successfully.');
      if (recoveryKeys.isNotEmpty) {
        await showVaultRecoveryKeysDialog(
          context: context,
          recoveryKeys: recoveryKeys,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to update the task right now.',
        isError: true,
      );
    }
  }

  Future<void> _showDetailsDialog() async {
    final task = _task;
    if (task == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _TaskDetailsDialog(
        task: task,
        category: _categoryFor(task.categoryId),
      ),
    );
  }

  Future<void> _deleteTask() async {
    final task = _task;
    if (task == null) {
      return;
    }
    if (!await _confirmVaultProtectedAction(task)) {
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
      await widget.repository.deleteTask(task.id);
      await widget.reminderService.cancelTask(task.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TaskEditorScreen.deletedResult);
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

  Future<void> _archiveTask() async {
    final task = _task;
    if (task == null) {
      return;
    }
    if (!await _confirmVaultProtectedAction(task)) {
      return;
    }

    try {
      final archivedTask = task.copyWith(
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await widget.repository.upsertTask(archivedTask);
      await widget.reminderService.cancelTask(task.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TaskEditorScreen.archivedResult);
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

  void _relockTask() {
    final task = _task;
    if (task == null) {
      return;
    }

    final vaultService = VaultServiceScope.of(context);
    final hasTaskVault = task.vaultConfig?.isEnabled == true;
    final hasSpaceVault = _parentSpace?.vaultConfig?.isEnabled == true;
    if (!hasTaskVault && !hasSpaceVault) {
      return;
    }

    if (hasTaskVault) {
      vaultService.clearUnlocked(taskVaultEntityKey(task.id));
    }
    if (hasSpaceVault && _parentSpace != null) {
      vaultService.clearUnlocked(spaceVaultEntityKey(_parentSpace!.id));
    }

    if (!mounted) {
      return;
    }

    setState(() {});

    final message = hasTaskVault && hasSpaceVault
        ? 'Task and space locked again.'
        : hasTaskVault
        ? 'Task locked again.'
        : 'Space locked again.';
    showTaskToast(context, message: message);
  }

  bool get _hasVaultProtection {
    final task = _task;
    if (task == null) {
      return false;
    }
    return task.vaultConfig?.isEnabled == true ||
        _parentSpace?.vaultConfig?.isEnabled == true;
  }

  bool get _isVaultCurrentlyUnlocked {
    final task = _task;
    if (task == null) {
      return false;
    }

    final vaultService = VaultServiceScope.of(context);
    final taskUnlocked =
        task.vaultConfig?.isEnabled == true &&
        vaultService.isUnlocked(taskVaultEntityKey(task.id));
    if (taskUnlocked) {
      return true;
    }

    final parentSpace = _parentSpace;
    return parentSpace?.vaultConfig?.isEnabled == true &&
        vaultService.isUnlocked(spaceVaultEntityKey(parentSpace!.id));
  }

  TaskCategory? _categoryFor(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  Future<bool> _confirmVaultProtectedAction(TaskItem task) async {
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
          final updatedTask = task.copyWith(
            vaultConfig: config,
            updatedAt: DateTime.now(),
          );
          await widget.repository.upsertTask(updatedTask);
          if (mounted) {
            setState(() {
              _task = updatedTask;
            });
          }
        },
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

    final parentSpaceId = task.spaceId;
    if (parentSpaceId == null) {
      return true;
    }
    final parentSpace = await widget.repository.getSpaceById(parentSpaceId);
    if (!mounted || parentSpace?.vaultConfig == null) {
      return mounted;
    }
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
          parentSpace.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final noteController = _noteController;
    final task = _task;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (await _handleWillPop() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        key: TaskEditorScreen.markerKey,
        backgroundColor: taskSurface,
        appBar: AppBar(
          toolbarHeight: 86,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            onPressed: () async {
              if (await _flushBeforeExit() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.appBarTitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: taskMutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task?.title ?? 'Task Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
          actions: [
            if (_hasVaultProtection)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Material(
                  color: _isVaultCurrentlyUnlocked
                      ? const Color(0xFFEAF3FE)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _relockTask,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _isVaultCurrentlyUnlocked
                            ? TablerIcons.lock_open
                            : TablerIcons.lock,
                        size: 18,
                        color: _isVaultCurrentlyUnlocked
                            ? taskPrimaryBlue
                            : taskDangerText,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<_EditorMenuAction>(
                key: TaskEditorScreen.autosaveStatusKey,
                enabled: task != null,
                color: Colors.white,
                surfaceTintColor: Colors.white,
                icon: const Icon(
                  TablerIcons.dots_vertical,
                  size: 20,
                  color: taskMutedText,
                ),
                onSelected: (value) {
                  switch (value) {
                    case _EditorMenuAction.viewDetails:
                      _showDetailsDialog();
                    case _EditorMenuAction.edit:
                      _openDetailsSheet();
                    case _EditorMenuAction.archive:
                      _archiveTask();
                    case _EditorMenuAction.delete:
                      _deleteTask();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.viewDetailsButtonKey,
                    value: _EditorMenuAction.viewDetails,
                    child: TaskMenuEntry(
                      icon: TablerIcons.eye,
                      label: 'View Details',
                    ),
                  ),
                  const PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.editDetailsButtonKey,
                    value: _EditorMenuAction.edit,
                    child: TaskMenuEntry(icon: TablerIcons.edit, label: 'Edit'),
                  ),
                  const PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.archiveButtonKey,
                    value: _EditorMenuAction.archive,
                    child: TaskMenuEntry(
                      icon: TablerIcons.archive,
                      label: 'Archive',
                    ),
                  ),
                  const PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.deleteButtonKey,
                    value: _EditorMenuAction.delete,
                    child: TaskMenuEntry(
                      icon: TablerIcons.trash,
                      label: 'Delete',
                      color: taskDangerText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: _buildBody(
            context,
            task: task,
            noteController: noteController,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required TaskItem? task,
    required quill.QuillController? noteController,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _EditorErrorState(message: _loadError!, onRetry: _loadEditorState);
    }
    if (task == null || noteController == null) {
      return _EditorErrorState(
        message: 'This task could not be loaded.',
        onRetry: _loadEditorState,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: quill.QuillEditor.basic(
              key: TaskEditorScreen.editorBodyKey,
              controller: noteController,
              focusNode: _editorFocusNode,
              scrollController: _editorScrollController,
              config: const quill.QuillEditorConfig(
                placeholder: 'Start writing your notes...',
                padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
              ),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: taskBorderColor)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: quill.QuillSimpleToolbar(
                controller: noteController,
                config: const quill.QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  toolbarSize: 30,
                  showDividers: true,
                  showFontFamily: false,
                  showFontSize: false,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: false,
                  showInlineCode: false,
                  showColorButton: false,
                  showBackgroundColorButton: false,
                  showClearFormat: true,
                  showAlignmentButtons: false,
                  showHeaderStyle: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: false,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: true,
                  showUndo: false,
                  showRedo: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskDetailsDialog extends StatelessWidget {
  const _TaskDetailsDialog({required this.task, required this.category});

  final TaskItem task;
  final TaskCategory? category;

  @override
  Widget build(BuildContext context) {
    final description = task.description?.trim().isNotEmpty == true
        ? task.description!.trim()
        : 'No short description added yet.';
    final detailChips = <Widget>[
      _InfoPill(
        icon: TablerIcons.calendar_event,
        label: 'Created ${_formatDateTime(task.createdAt)}',
      ),
      _InfoPill(
        icon: TablerIcons.clock_edit,
        label: 'Updated ${_formatDateTime(task.updatedAt)}',
      ),
      _InfoPill(icon: TablerIcons.flag_3, label: _priorityLabel(task.priority)),
      _InfoPill(icon: TablerIcons.calendar_due, label: _scheduleLabel(task)),
    ];

    return Dialog(
      key: TaskEditorScreen.metadataCardKey,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: taskDarkText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    TablerIcons.x,
                    size: 18,
                    color: taskMutedText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: taskDarkText,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(width: 10),
                  _TaskDetailsBadge(category: category!),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: taskMutedText,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Wrap(spacing: 10, runSpacing: 12, children: detailChips),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: const Color(0xFFDCE7F6),
                  foregroundColor: taskPrimaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low priority',
      TaskPriority.medium => 'Medium priority',
      TaskPriority.high => 'High priority',
      TaskPriority.urgent => 'Urgent priority',
    };
  }

  static String _scheduleLabel(TaskItem task) {
    final start = task.startDateTime;
    final end = task.endDateTime;
    if (end == null) {
      return 'No schedule';
    }
    if (start != null) {
      if (_isSameDay(start, end)) {
        return '${_shortDate(start)} • ${_shortTime(end)}';
      }
      return '${_shortDate(start)} - ${_shortDate(end)}';
    }
    if (start != null) {
      return 'Starts ${_shortDate(start)}';
    }
    return 'Due ${_shortDate(end)} at ${_shortTime(end)}';
  }

  static String _formatDateTime(DateTime value) {
    return '${_shortDate(value)} • ${_shortTime(value)}';
  }

  static String _shortDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  static String _shortTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _TaskDetailsBadge extends StatelessWidget {
  const _TaskDetailsBadge({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: category.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolveTaskCategoryIcon(category.iconKey),
            size: 11,
            color: category.color,
          ),
          const SizedBox(width: 4),
          Text(
            category.name,
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, minHeight: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: taskPrimaryBlue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorErrorState extends StatelessWidget {
  const _EditorErrorState({required this.message, required this.onRetry});

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
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: taskPrimaryBlue),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDetailsResult {
  const _TaskDetailsResult({
    required this.task,
    required this.categories,
    required this.vaultDraft,
  });

  final TaskItem task;
  final List<TaskCategory> categories;
  final VaultDraft vaultDraft;
}

class _TaskDetailsSheet extends StatefulWidget {
  const _TaskDetailsSheet({
    required this.repository,
    required this.task,
    required this.categories,
    this.lockedCategoryId,
    this.fixedSpaceId,
  });

  final TaskRepository repository;
  final TaskItem task;
  final List<TaskCategory> categories;
  final String? lockedCategoryId;
  final String? fixedSpaceId;

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pickerFocusNode = FocusNode();
  final _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _vaultSecretController;
  late List<TaskCategory> _categories;
  late TaskPriority _priority;
  late String _selectedCategoryId;
  DateTime? _targetDate;
  TimeOfDay? _targetTime;
  bool _vaultEnabled = false;
  VaultMethod _vaultMethod = VaultMethod.password;
  bool _changeVault = false;
  bool? _isDeviceSecurityAvailable;
  bool _didLoadDeviceSecurityAvailability = false;

  bool get _hasExistingSecretVault =>
      widget.task.vaultConfig?.secretKeyRef != null &&
      (widget.task.vaultConfig?.usesSecret ?? false);

  bool get _shouldPreserveExistingVault =>
      _hasExistingSecretVault && !_changeVault;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _vaultSecretController = TextEditingController();
    _categories = [...widget.categories];
    _priority = widget.task.priority;
    _selectedCategoryId = widget.lockedCategoryId ?? widget.task.categoryId;
    _targetDate = widget.task.endDate;
    _targetTime = _toTimeOfDay(widget.task.endMinutes);
    if (widget.task.vaultConfig case final vaultConfig?) {
      _vaultEnabled = vaultConfig.isEnabled;
      _vaultMethod = vaultConfig.method;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadDeviceSecurityAvailability) {
      return;
    }
    _didLoadDeviceSecurityAvailability = true;
    _loadDeviceSecurityAvailability();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _vaultSecretController.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceSecurityAvailability() async {
    final available = await VaultServiceScope.of(
      context,
    ).isDeviceSecurityAvailable();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDeviceSecurityAvailable = available;
    });
  }

  void _parkFocus() {
    if (!mounted) {
      return;
    }
    FocusScope.of(context).requestFocus(_pickerFocusNode);
  }

  TimeOfDay? _toTimeOfDay(int? minutes) {
    if (minutes == null) {
      return null;
    }
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  String? _scheduleValidationMessage() {
    if (_targetTime != null && _targetDate == null) {
      return 'Choose a target date before setting the task time.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    _parkFocus();
    final now = DateTime.now();
    final initialDate = _targetDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      ),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: buildTaskPickerTheme(Theme.of(context)),
          child: child!,
        );
      },
    );

    if (picked == null) {
      _parkFocus();
      return;
    }

    setState(() {
      _targetDate = DateTime(picked.year, picked.month, picked.day);
    });
    _parkFocus();
  }

  Future<void> _pickTime({
    required TimeOfDay? initialValue,
    required ValueChanged<TimeOfDay> onSelected,
    required String helpText,
  }) async {
    _parkFocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialValue ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: helpText,
      builder: (context, child) {
        return Theme(
          data: buildTaskPickerTheme(Theme.of(context)),
          child: child!,
        );
      },
    );

    if (picked == null) {
      _parkFocus();
      return;
    }

    onSelected(picked);
    _parkFocus();
  }

  Future<void> _pickTargetTime() async {
    TimeOfDay? pickedTime;
    await _pickTime(
      initialValue: _targetTime ?? TimeOfDay.now(),
      helpText: 'Target Time',
      onSelected: (value) {
        pickedTime = value;
      },
    );
    if (pickedTime == null) {
      return;
    }

    setState(() {
      _targetTime = pickedTime;
    });
  }

  Future<void> _addCategory() async {
    final category = await showDialog<TaskCategory>(
      context: context,
      builder: (context) {
        return _CategoryDialog(
          existingNames: _categories.map((item) => item.name).toSet(),
          uuid: _uuid,
        );
      },
    );
    if (category == null) {
      return;
    }

    await widget.repository.upsertCategory(category);
    setState(() {
      _categories = [..._categories, category]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedCategoryId = category.id;
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final scheduleValidationMessage = _scheduleValidationMessage();
    if (scheduleValidationMessage != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(scheduleValidationMessage)));
      return;
    }

    if (!_shouldPreserveExistingVault &&
        _vaultEnabled &&
        _vaultMethod == VaultMethod.deviceSecurity &&
        _isDeviceSecurityAvailable == false) {
      showTaskToast(
        context,
        message: 'Device security is not available on this device.',
        isError: true,
      );
      return;
    }

    final trimmedTitle = _titleController.text.trim();
    final trimmedDescription = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _TaskDetailsResult(
        task: widget.task.copyWith(
          title: trimmedTitle,
          description: trimmedDescription,
          priority: _priority,
          categoryId: widget.lockedCategoryId ?? _selectedCategoryId,
          spaceId: widget.fixedSpaceId ?? widget.task.spaceId,
          startDate: null,
          startMinutes: null,
          clearStartDate: true,
          clearStartMinutes: true,
          endDate: _targetDate,
          endMinutes: _targetTime == null
              ? null
              : (_targetTime!.hour * 60) + _targetTime!.minute,
          clearEndDate: _targetDate == null,
          clearEndMinutes: _targetTime == null,
          updatedAt: DateTime.now(),
        ),
        categories: _categories,
        vaultDraft: VaultDraft(
          isEnabled: _vaultEnabled,
          method: _vaultEnabled ? _vaultMethod : null,
          secret: _vaultSecretController.text.trim(),
          preserveExistingConfig: _shouldPreserveExistingVault,
          keepExistingSecret:
              !_shouldPreserveExistingVault &&
              widget.task.vaultConfig?.secretKeyRef != null &&
              _vaultSecretController.text.trim().isEmpty &&
              _vaultMethod == widget.task.vaultConfig?.method,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleValidationMessage = _scheduleValidationMessage();

    return Scaffold(
      backgroundColor: taskSurface,
      appBar: AppBar(
        title: const Text('Edit Task Details'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskSectionCard(
                  title: 'Task Details',
                  subtitle: 'Add the core information people will scan first.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TaskFieldLabel('Task Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: TaskEditorScreen.titleFieldKey,
                        controller: _titleController,
                        decoration: taskInputDecoration(
                          context: context,
                          hintText: 'Enter task title',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Task title is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const TaskFieldLabel('Short Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('task-editor-description-field'),
                        controller: _descriptionController,
                        decoration: taskInputDecoration(
                          context: context,
                          hintText: 'Short preview for the task card',
                        ).copyWith(counterText: ''),
                        maxLength: 30,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.length > 30) {
                            return 'Description must be 30 characters or fewer.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Optional, maximum of 30 characters',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: taskMutedText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TaskSectionCard(
                  title: 'Task Settings',
                  subtitle:
                      'Set the category, urgency, and timing before writing notes.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TaskFieldLabel('Priority'),
                      const SizedBox(height: 8),
                      TaskCompactDropdown<TaskPriority>(
                        buttonKey: TaskEditorScreen.priorityFieldKey,
                        menuKeyBuilder: (value) =>
                            Key('task-editor-priority-${value.name}'),
                        currentValue: _priority,
                        currentLabel: _priorityLabel(_priority),
                        onSelected: (value) {
                          setState(() {
                            _priority = value;
                          });
                        },
                        items: TaskPriority.values,
                        labelBuilder: _priorityLabel,
                      ),
                      const SizedBox(height: 16),
                      const TaskFieldLabel('Category'),
                      const SizedBox(height: 8),
                      if (widget.lockedCategoryId != null)
                        _LockedCategoryField(
                          category: _categoryById(widget.lockedCategoryId!),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TaskCompactDropdown<String>(
                                buttonKey: TaskEditorScreen.categoryFieldKey,
                                menuKeyBuilder: (value) =>
                                    Key('task-editor-category-$value'),
                                currentValue: _selectedCategoryId,
                                currentLabel:
                                    _categoryLabel(_selectedCategoryId) ??
                                    'Category',
                                onSelected: (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                                items: _categories
                                    .map((item) => item.id)
                                    .toList(),
                                labelBuilder: (value) =>
                                    _categoryLabel(value) ?? 'Category',
                                leadingBuilder: (value) {
                                  final category = _categoryById(value);
                                  if (category == null) {
                                    return null;
                                  }
                                  return Icon(
                                    resolveTaskCategoryIcon(category.iconKey),
                                    color: category.color,
                                    size: 18,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                key: TaskEditorScreen.addCategoryButtonKey,
                                onPressed: _addCategory,
                                icon: const Icon(TablerIcons.plus, size: 18),
                                label: const Text('New'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: taskPrimaryBlue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  side: const BorderSide(
                                    color: taskBorderColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TaskSectionCard(
                  title: 'Schedule',
                  subtitle: 'Set the target date and time for this task.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TaskPickerButton(
                        buttonKey: TaskEditorScreen.dateRangeButtonKey,
                        title: 'Target Date',
                        value: _formatDateValue(_targetDate),
                        icon: TablerIcons.calendar_event,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      TaskPickerButton(
                        buttonKey: TaskEditorScreen.timeRangeButtonKey,
                        title: 'Target Time',
                        value: _formatTimeValue(context, _targetTime),
                        icon: TablerIcons.clock_hour_8,
                        onTap: _pickTargetTime,
                      ),
                      if (scheduleValidationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          scheduleValidationMessage,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: taskDangerText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                VaultSettingsFields(
                  enabled: _vaultEnabled,
                  method: _vaultMethod,
                  secretController: _vaultSecretController,
                  hasExistingSecret:
                      widget.task.vaultConfig?.secretKeyRef != null,
                  isEditing: true,
                  changeVault: _changeVault,
                  isDeviceSecurityAvailable: _isDeviceSecurityAvailable,
                  onEnabledChanged: (value) {
                    setState(() {
                      _vaultEnabled = value;
                      if (!value) {
                        _vaultSecretController.clear();
                      }
                    });
                  },
                  onChangeVaultChanged: (value) {
                    setState(() {
                      _changeVault = value;
                      if (!value) {
                        _vaultSecretController.clear();
                      }
                    });
                  },
                  onMethodChanged: (value) async {
                    bool? available = _isDeviceSecurityAvailable;
                    if (value == VaultMethod.deviceSecurity &&
                        available == null) {
                      available = await VaultServiceScope.of(
                        context,
                      ).isDeviceSecurityAvailable();
                    }
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _vaultMethod = value;
                      _isDeviceSecurityAvailable = available;
                      if (value == VaultMethod.deviceSecurity) {
                        _vaultSecretController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FilledButton(
            key: TaskEditorScreen.saveButtonKey,
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: taskPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Apply Details'),
          ),
        ),
      ),
    );
  }

  TaskCategory? _categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  String? _categoryLabel(String id) => _categoryById(id)?.name;

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
      TaskPriority.urgent => 'Urgent',
    };
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateValue(DateTime? value) {
    if (value == null) {
      return 'Select target date';
    }
    return _formatDate(value);
  }

  String _formatTimeValue(BuildContext context, TimeOfDay? value) {
    if (value == null) {
      return 'Select target time';
    }
    return value.format(context);
  }
}

class _LockedCategoryField extends StatelessWidget {
  const _LockedCategoryField({required this.category});

  final TaskCategory? category;

  @override
  Widget build(BuildContext context) {
    final resolvedCategory = category;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: taskFilterControlHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: taskSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: taskBorderColor),
      ),
      child: Row(
        children: [
          if (resolvedCategory != null) ...[
            Icon(
              resolveTaskCategoryIcon(resolvedCategory.iconKey),
              color: resolvedCategory.color,
              size: 18,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              resolvedCategory?.name ?? 'Locked category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: taskDarkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Locked',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: taskMutedText,
              fontWeight: FontWeight.w700,
            ),
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.existingNames, required this.uuid});

  final Set<String> existingNames;
  final Uuid uuid;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedIconKey = taskCategoryIconOptions.first.key;
  Color _selectedColor = taskCategoryColorOptions.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      TaskCategory(
        id: widget.uuid.v4(),
        name: _nameController.text.trim(),
        iconKey: _selectedIconKey,
        colorValue: _selectedColor.toARGB32(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Form(
        key: _formKey,
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
                          'Create Category',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: taskDarkText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a category with a focused icon and theme-safe color.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: taskSecondaryText, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Category Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Enter a category name',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Category name is required.';
                        }
                        if (widget.existingNames.any(
                          (name) => name.toLowerCase() == trimmed.toLowerCase(),
                        )) {
                          return 'Choose a unique category name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const TaskFieldLabel('Icon'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: taskCategoryIconOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final option = taskCategoryIconOptions[index];
                        final selected = _selectedIconKey == option.key;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIconKey = option.key;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: selected ? taskPrimaryBlue : taskSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? taskPrimaryBlue
                                    : taskBorderColor,
                              ),
                            ),
                            child: Icon(
                              option.icon,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : taskSecondaryText,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const TaskFieldLabel('Color Selection'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: taskCategoryColorOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final color = taskCategoryColorOptions[index];
                        final selected = color == _selectedColor;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? taskDarkText
                                    : taskMutedBorderColor,
                                width: selected ? 3 : 1.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: taskPrimaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create'),
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

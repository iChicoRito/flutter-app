import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/task_reminder_service.dart';
import '../data/task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_management_ui.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.repository,
    required this.taskId,
    TaskReminderService? reminderService,
  }) : reminderService = reminderService ?? const NoopTaskReminderService();

  static const String deletedResult = 'deleted';
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
  static const Key editDetailsButtonKey = Key('task-editor-edit-details');
  static const Key deleteButtonKey = Key('task-editor-delete');

  final TaskRepository repository;
  final String taskId;
  final TaskReminderService reminderService;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

enum _EditorMenuAction { edit, delete }

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _titleController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  quill.QuillController? _noteController;
  TaskItem? _task;
  List<TaskCategory> _categories = [];
  Timer? _autosaveTimer;
  bool _isLoading = true;
  bool _isHydrating = false;
  bool _isPersisting = false;
  bool _hasPendingChanges = false;
  bool _isTaskDetailsExpanded = false;
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

      _bindTask(task: task, categories: categories);
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
  }) {
    _isHydrating = true;
    _noteController?.removeListener(_scheduleAutosave);
    _noteController?.dispose();

    _task = task;
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

    final result = await Navigator.of(context).push<_TaskDetailsResult>(
      MaterialPageRoute<_TaskDetailsResult>(
        builder: (context) => _TaskDetailsSheet(
          repository: widget.repository,
          task: task,
          categories: _categories,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await widget.repository.upsertTask(result.task);
      await widget.reminderService.syncTask(result.task);
      final latest = await widget.repository.getTaskById(result.task.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _task = latest ?? result.task;
        _categories = result.categories;
      });
      showTaskToast(context, message: 'Task updated successfully.');
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

  Future<void> _deleteTask() async {
    final task = _task;
    if (task == null) {
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

  TaskCategory? _categoryFor(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
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
                'Task Notes',
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
                    case _EditorMenuAction.edit:
                      _openDetailsSheet();
                    case _EditorMenuAction.delete:
                      _deleteTask();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.editDetailsButtonKey,
                    value: _EditorMenuAction.edit,
                    child: const Text('Edit'),
                  ),
                  PopupMenuItem<_EditorMenuAction>(
                    key: TaskEditorScreen.deleteButtonKey,
                    value: _EditorMenuAction.delete,
                    child: Text(
                      'Delete',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: taskDangerText,
                        fontWeight: FontWeight.w600,
                      ),
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

    final viewInsets = MediaQuery.viewInsetsOf(context);

    final isWritingMode = viewInsets.bottom > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !isWritingMode
                ? Padding(
                    key: const ValueKey('details-visible'),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _MetadataCard(
                      key: TaskEditorScreen.metadataCardKey,
                      task: task,
                      category: _categoryFor(task.categoryId),
                      isExpanded: _isTaskDetailsExpanded,
                      onHeaderTap: () {
                        setState(() {
                          _isTaskDetailsExpanded = !_isTaskDetailsExpanded;
                        });
                      },
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('details-hidden')),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: taskBorderColor),
              ),
              child: Column(
                children: [
                  quill.QuillSimpleToolbar(
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
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: taskBorderColor,
                  ),
                  Expanded(
                    child: quill.QuillEditor.basic(
                      key: TaskEditorScreen.editorBodyKey,
                      controller: noteController,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: const quill.QuillEditorConfig(
                        placeholder: 'Start writing your notes...',
                        padding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    super.key,
    required this.task,
    required this.category,
    required this.isExpanded,
    required this.onHeaderTap,
  });

  final TaskItem task;
  final TaskCategory? category;
  final bool isExpanded;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onHeaderTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Keep the note attached to the right category, priority, and target schedule.',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: taskMutedText,
                                      height: 1.45,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            isExpanded
                                ? TablerIcons.chevron_up
                                : TablerIcons.chevron_down,
                            size: 18,
                            color: taskMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                _InfoPill(
                  icon: TablerIcons.calendar_event,
                  label: 'Created ${_formatDateTime(task.createdAt)}',
                ),
                _InfoPill(
                  icon: TablerIcons.clock_edit,
                  label: 'Updated ${_formatDateTime(task.updatedAt)}',
                ),
                if (category != null)
                  _InfoPill(
                    icon: resolveTaskCategoryIcon(category!.iconKey),
                    label: category!.name,
                    iconColor: category!.color,
                  ),
                _InfoPill(
                  icon: TablerIcons.flag_3,
                  label: _priorityLabel(task.priority),
                ),
                _InfoPill(
                  icon: TablerIcons.calendar_due,
                  label: _scheduleLabel(task),
                ),
              ],
            ),
          ],
        ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

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
            Icon(icon, size: 13, color: iconColor ?? taskPrimaryBlue),
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
  const _TaskDetailsResult({required this.task, required this.categories});

  final TaskItem task;
  final List<TaskCategory> categories;
}

class _TaskDetailsSheet extends StatefulWidget {
  const _TaskDetailsSheet({
    required this.repository,
    required this.task,
    required this.categories,
  });

  final TaskRepository repository;
  final TaskItem task;
  final List<TaskCategory> categories;

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pickerFocusNode = FocusNode();
  final _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late List<TaskCategory> _categories;
  late TaskPriority _priority;
  late String _selectedCategoryId;
  DateTime? _targetDate;
  TimeOfDay? _targetTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _categories = [...widget.categories];
    _priority = widget.task.priority;
    _selectedCategoryId = widget.task.categoryId;
    _targetDate = widget.task.endDate;
    _targetTime = _toTimeOfDay(widget.task.endMinutes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
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

    final trimmedTitle = _titleController.text.trim();
    final trimmedDescription = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _TaskDetailsResult(
        task: widget.task.copyWith(
          title: trimmedTitle,
          description: trimmedDescription,
          priority: _priority,
          categoryId: _selectedCategoryId,
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
                          if (trimmed.isEmpty) {
                            return 'Short description is required.';
                          }
                          if (trimmed.length > 30) {
                            return 'Description must be 30 characters or fewer.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Maximum of 30 characters',
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
                                side: const BorderSide(color: taskBorderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
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

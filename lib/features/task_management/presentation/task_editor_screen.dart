import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_management_ui.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.repository,
    required this.categories,
    this.initialTask,
  });

  static const Key titleFieldKey = Key('task-editor-title-field');
  static const Key descriptionFieldKey = Key('task-editor-description-field');
  static const Key startDateButtonKey = Key('task-editor-start-date-button');
  static const Key endDateButtonKey = Key('task-editor-end-date-button');
  static const Key startTimeButtonKey = Key('task-editor-start-time-button');
  static const Key endTimeButtonKey = Key('task-editor-end-time-button');
  static const Key saveButtonKey = Key('task-editor-save-button');
  static const Key categoryFieldKey = Key('task-editor-category-field');
  static const Key priorityFieldKey = Key('task-editor-priority-field');
  static const Key addCategoryButtonKey = Key('task-editor-add-category');

  final TaskRepository repository;
  final List<TaskCategory> categories;
  final TaskItem? initialTask;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();

  late List<TaskCategory> _categories;
  late TaskPriority _priority;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _categories = [...widget.categories];
    _titleController.text = task?.title ?? '';
    _descriptionController.text = task?.description ?? '';
    _priority = task?.priority ?? TaskPriority.medium;
    _selectedCategoryId =
        task?.categoryId ??
        (_categories.isNotEmpty ? _categories.first.id : null);
    _startDate = task?.startDate;
    _endDate = task?.endDate;
    _startTime = _toTimeOfDay(task?.startMinutes);
    _endTime = _toTimeOfDay(task?.endMinutes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  TimeOfDay? _toTimeOfDay(int? minutes) {
    if (minutes == null) {
      return null;
    }
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null) {
      return null;
    }

    final value = time ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(date.year, date.month, date.day, value.hour, value.minute);
  }

  String? _scheduleValidationMessage() {
    final start = _combineDateAndTime(_startDate, _startTime);
    final end = _combineDateAndTime(_endDate, _endTime);

    if (start != null && _endDate == null) {
      return 'Choose an end date to complete the schedule range.';
    }

    if (end != null && _startDate == null) {
      return 'Choose a start date before setting an end schedule.';
    }

    if (start != null && end != null && end.isBefore(start)) {
      return 'End schedule must be later than or equal to the start schedule.';
    }

    return null;
  }

  Future<void> _pickDate({
    required DateTime? initialValue,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialValue ?? now,
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
      return;
    }

    onSelected(DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime({
    required TimeOfDay? initialValue,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialValue ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: buildTaskPickerTheme(Theme.of(context)),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    onSelected(picked);
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

  Future<void> _save() async {
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

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Choose a category before saving.')),
        );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final initialTask = widget.initialTask;
    final task = TaskItem(
      id: initialTask?.id ?? _uuid.v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: _startDate,
      startMinutes: _startTime == null
          ? null
          : (_startTime!.hour * 60) + _startTime!.minute,
      endDate: _endDate,
      endMinutes: _endTime == null
          ? null
          : (_endTime!.hour * 60) + _endTime!.minute,
      priority: _priority,
      categoryId: _selectedCategoryId!,
      isCompleted: initialTask?.isCompleted ?? false,
      createdAt: initialTask?.createdAt ?? now,
      updatedAt: now,
      completedAt: initialTask?.completedAt,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleValidationMessage = _scheduleValidationMessage();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'Add Task')),
      backgroundColor: taskSurface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
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
                        hintText: 'What needs to get done?',
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
                    const TaskFieldLabel('Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: TaskEditorScreen.descriptionFieldKey,
                      controller: _descriptionController,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Add notes or context for this task',
                      ),
                      minLines: 5,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TaskSectionCard(
                title: 'Task Settings',
                subtitle:
                    'Keep categorization and urgency aligned with filters.',
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
                            currentValue: _selectedCategoryId!,
                            currentLabel:
                                _categoryLabel(_selectedCategoryId!) ??
                                'Category',
                            onSelected: (value) {
                              setState(() {
                                _selectedCategoryId = value;
                              });
                            },
                            items: _categories.map((item) => item.id).toList(),
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
                          height: 50,
                          child: OutlinedButton.icon(
                            key: TaskEditorScreen.addCategoryButtonKey,
                            onPressed: _isSaving ? null : _addCategory,
                            icon: const Icon(TablerIcons.plus, size: 18),
                            label: const Text('New'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: taskPrimaryBlue,
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
              const SizedBox(height: 16),
              TaskSectionCard(
                title: 'Schedule',
                subtitle:
                    'Set a full task window so the list can show a clearer timeline.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskPickerButton(
                      buttonKey: TaskEditorScreen.startDateButtonKey,
                      title: 'Start Date',
                      value: _startDate == null
                          ? 'Select start date'
                          : _formatDate(_startDate!),
                      icon: TablerIcons.calendar_event,
                      onTap: _isSaving
                          ? null
                          : () => _pickDate(
                              initialValue: _startDate,
                              onSelected: (value) {
                                setState(() {
                                  _startDate = value;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    TaskPickerButton(
                      buttonKey: TaskEditorScreen.endDateButtonKey,
                      title: 'End Date',
                      value: _endDate == null
                          ? 'Select end date'
                          : _formatDate(_endDate!),
                      icon: TablerIcons.calendar_due,
                      onTap: _isSaving
                          ? null
                          : () => _pickDate(
                              initialValue: _endDate ?? _startDate,
                              onSelected: (value) {
                                setState(() {
                                  _endDate = value;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    TaskPickerButton(
                      buttonKey: TaskEditorScreen.startTimeButtonKey,
                      title: 'Start Time',
                      value: _startTime == null
                          ? 'Select start time'
                          : _startTime!.format(context),
                      icon: TablerIcons.clock_hour_8,
                      onTap: _isSaving
                          ? null
                          : () => _pickTime(
                              initialValue: _startTime,
                              onSelected: (value) {
                                setState(() {
                                  _startTime = value;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    TaskPickerButton(
                      buttonKey: TaskEditorScreen.endTimeButtonKey,
                      title: 'End Time',
                      value: _endTime == null
                          ? 'Select end time'
                          : _endTime!.format(context),
                      icon: TablerIcons.clock_play,
                      onTap: _isSaving
                          ? null
                          : () => _pickTime(
                              initialValue: _endTime,
                              onSelected: (value) {
                                setState(() {
                                  _endTime = value;
                                });
                              },
                            ),
                    ),
                    if (scheduleValidationMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        scheduleValidationMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FilledButton(
            key: TaskEditorScreen.saveButtonKey,
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: taskPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Save Task'),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 4;
                        const spacing = 10.0;
                        final itemSize =
                            (constraints.maxWidth -
                                (spacing * (crossAxisCount - 1))) /
                            crossAxisCount;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: taskCategoryIconOptions.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
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
                                width: itemSize,
                                height: itemSize,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? taskPrimaryBlue
                                      : taskSurface,
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
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const TaskFieldLabel('Color Selection'),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 5;
                        const spacing = 12.0;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: taskCategoryColorOptions.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
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
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: constraints.maxWidth / 5 - spacing,
                                  height: constraints.maxWidth / 5 - spacing,
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
                                              color: color.withValues(
                                                alpha: 0.28,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
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
                      style: TextButton.styleFrom(
                        foregroundColor: taskSecondaryText,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: taskPrimaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _submit,
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

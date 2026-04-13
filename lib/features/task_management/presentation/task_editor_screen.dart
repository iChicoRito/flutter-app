import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

const _primaryBlue = Color(0xFF1E88E5);
const _darkText = Color(0xFF1F2937);
const _borderColor = Color(0xFFE5E8EC);

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.repository,
    required this.categories,
    this.initialTask,
  });

  static const Key titleFieldKey = Key('task-editor-title-field');
  static const Key descriptionFieldKey = Key('task-editor-description-field');
  static const Key dueDateButtonKey = Key('task-editor-due-date-button');
  static const Key dueTimeButtonKey = Key('task-editor-due-time-button');
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
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
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
    _dueDate = task?.dueDate;
    if (task?.dueMinutes != null) {
      final minutes = task!.dueMinutes!;
      _dueTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dueDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dueTime = picked;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
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
      dueDate: _dueDate,
      dueMinutes: _dueTime == null
          ? null
          : (_dueTime!.hour * 60) + _dueTime!.minute,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'Add Task')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              TextFormField(
                key: TaskEditorScreen.titleFieldKey,
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task title',
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
              TextFormField(
                key: TaskEditorScreen.descriptionFieldKey,
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add notes or context',
                ),
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                key: TaskEditorScreen.priorityFieldKey,
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem<TaskPriority>(
                    value: priority,
                    child: Text(_priorityLabel(priority)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _priority = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: TaskEditorScreen.categoryFieldKey,
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                resolveTaskCategoryIcon(category.iconKey),
                                color: category.color,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    key: TaskEditorScreen.addCategoryButtonKey,
                    onPressed: _isSaving ? null : _addCategory,
                    icon: const Icon(TablerIcons.plus, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Schedule',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  children: [
                    FilledButton.tonalIcon(
                      key: TaskEditorScreen.dueDateButtonKey,
                      onPressed: _isSaving ? null : _pickDate,
                      icon: const Icon(TablerIcons.calendar_due),
                      label: Text(
                        _dueDate == null
                            ? 'Set due date'
                            : _formatDate(_dueDate!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      key: TaskEditorScreen.dueTimeButtonKey,
                      onPressed: _isSaving ? null : _pickTime,
                      icon: const Icon(TablerIcons.clock_hour_8),
                      label: Text(
                        _dueTime == null
                            ? 'Set due time'
                            : _dueTime!.format(context),
                      ),
                    ),
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
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Save Task'),
          ),
        ),
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Category name'),
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
                const SizedBox(height: 16),
                Text(
                  'Icon',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: taskCategoryIconOptions.map((option) {
                    final selected = _selectedIconKey == option.key;
                    return ChoiceChip(
                      label: Text(option.label),
                      avatar: Icon(
                        option.icon,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedIconKey = option.key;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Color',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: taskCategoryColorOptions.map((color) {
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
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? _darkText
                                : color.withValues(alpha: 0.2),
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _primaryBlue),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

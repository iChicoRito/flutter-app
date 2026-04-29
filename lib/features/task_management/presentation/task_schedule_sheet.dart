import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import 'task_management_ui.dart';

class TaskQuickScheduleRequest {
  const TaskQuickScheduleRequest({
    required this.title,
    required this.description,
    required this.category,
    required this.targetDate,
    required this.startMinutes,
    required this.endMinutes,
    this.taskId,
    this.isEditMode = false,
  });

  final String title;
  final String description;
  final TaskCategory category;
  final DateTime targetDate;
  final int startMinutes;
  final int endMinutes;
  final String? taskId;
  final bool isEditMode;
}

class TaskScheduleSheet extends StatefulWidget {
  const TaskScheduleSheet({
    super.key,
    required this.categories,
    required this.initialDate,
    required this.sheetKey,
    required this.titleFieldKey,
    required this.descriptionFieldKey,
    required this.categoryFieldKey,
    required this.categoryOptionKeyBuilder,
    required this.targetDateButtonKey,
    required this.targetTimeButtonKey,
    required this.submitButtonKey,
    this.existingTask,
    this.sheetTitle,
    this.sheetSubtitle,
    this.submitLabel,
    this.onSubmittedForTest,
  });

  final List<TaskCategory> categories;
  final DateTime initialDate;
  final Key sheetKey;
  final Key titleFieldKey;
  final Key descriptionFieldKey;
  final Key categoryFieldKey;
  final Key Function(String value) categoryOptionKeyBuilder;
  final Key targetDateButtonKey;
  final Key targetTimeButtonKey;
  final Key submitButtonKey;
  final TaskItem? existingTask;
  final String? sheetTitle;
  final String? sheetSubtitle;
  final String? submitLabel;
  final ValueChanged<TaskQuickScheduleRequest>? onSubmittedForTest;

  @override
  State<TaskScheduleSheet> createState() => _TaskScheduleSheetState();
}

class _TaskScheduleSheetState extends State<TaskScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late List<TaskCategory> _categories;
  late String _selectedCategoryId;
  late Color _selectedCategoryColor;
  late DateTime _targetDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  String? _rangeError;
  bool _hasManualColorSelection = false;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
    final existingTask = widget.existingTask;
    final initialCategoryId = existingTask?.categoryId;
    TaskCategory? initialCategory;
    if (initialCategoryId != null) {
      for (final category in _categories) {
        if (category.id == initialCategoryId) {
          initialCategory = category;
          break;
        }
      }
    }
    _selectedCategoryId = initialCategory?.id ?? _categories.first.id;
    _selectedCategoryColor = initialCategory?.color ?? _categories.first.color;
    _titleController.text = existingTask?.title ?? '';
    _descriptionController.text = existingTask?.description ?? '';
    final initialDate = existingTask?.startDate ?? existingTask?.endDate;
    _targetDate = DateTime(
      (initialDate ?? widget.initialDate).year,
      (initialDate ?? widget.initialDate).month,
      (initialDate ?? widget.initialDate).day,
    );
    final startMinutes = existingTask?.startMinutes;
    final endMinutes = existingTask?.endMinutes;
    if (startMinutes != null) {
      _startTime = _timeOfDayFromMinutes(startMinutes);
    }
    if (endMinutes != null) {
      _endTime = _timeOfDayFromMinutes(endMinutes);
    }
    _validateRange();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(_targetDate.year - 1),
      lastDate: DateTime(_targetDate.year + 5),
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
    setState(() {
      _targetDate = DateTime(picked.year, picked.month, picked.day);
    });
    _validateRange();
  }

  Future<TimeOfDay?> _showTaskTimePicker({
    required TimeOfDay initialTime,
    required String helpText,
  }) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      builder: (context, child) {
        return Theme(
          data: buildTaskPickerTheme(Theme.of(context)),
          child: child!,
        );
      },
    );
  }

  Future<void> _pickTimeRange() async {
    final pickedStart = await _showTaskTimePicker(
      initialTime: _startTime,
      helpText: 'Start Time',
    );
    if (pickedStart == null || !mounted) {
      return;
    }
    setState(() {
      _startTime = pickedStart;
    });

    final pickedEnd = await _showTaskTimePicker(
      initialTime: _endTime,
      helpText: 'End Time',
    );
    if (pickedEnd == null || !mounted) {
      _validateRange();
      return;
    }
    setState(() {
      _endTime = pickedEnd;
    });
    _validateRange();
  }

  void _validateRange() {
    final start = DateTime(
      _targetDate.year,
      _targetDate.month,
      _targetDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _targetDate.year,
      _targetDate.month,
      _targetDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    setState(() {
      _rangeError = end.isAfter(start)
          ? null
          : 'End time must be after start time.';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _validateRange();
    if (_rangeError != null) {
      return;
    }

    final request = TaskQuickScheduleRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categories
          .firstWhere((category) => category.id == _selectedCategoryId)
          .copyWith(colorValue: _selectedCategoryColor.toARGB32()),
      targetDate: _targetDate,
      startMinutes: (_startTime.hour * 60) + _startTime.minute,
      endMinutes: (_endTime.hour * 60) + _endTime.minute,
      taskId: widget.existingTask?.id,
      isEditMode: widget.existingTask != null,
    );
    widget.onSubmittedForTest?.call(request);
    Navigator.of(context).pop(request);
  }

  bool get _isEditMode => widget.existingTask != null;

  String get _sheetTitle =>
      widget.sheetTitle ?? (_isEditMode ? 'Edit Task' : 'Schedule Task');

  String get _sheetSubtitle =>
      widget.sheetSubtitle ??
      (_isEditMode
          ? 'Update your scheduled task'
          : 'Add and schedule your tasks');

  String get _submitLabel =>
      widget.submitLabel ?? (_isEditMode ? 'Save Changes' : 'Schedule Task');

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Container(
            key: widget.sheetKey,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.five,
              AppSpacing.four,
              AppSpacing.five,
              AppSpacing.five,
            ),
            decoration: const BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.threeXl),
              ),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.neutral200,
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.six),
                    Text(
                      _sheetTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.titleText,
                        fontSize: AppTypography.sizeLg,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.oneAndHalf),
                    Text(
                      _sheetSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.subHeaderText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.five),
                    const TaskFieldLabel('Task Title'),
                    const SizedBox(height: AppSpacing.two),
                    TextFormField(
                      key: widget.titleFieldKey,
                      controller: _titleController,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'What needs to get done?',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Task title is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.four),
                    const TaskFieldLabel('Short Description'),
                    const SizedBox(height: AppSpacing.two),
                    TextFormField(
                      key: widget.descriptionFieldKey,
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText:
                            'Add relevant notes, links, or instructions here...',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.length > 100) {
                          return 'Description must be 100 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.oneAndHalf),
                    Text(
                      'Maximum of 100 characters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subHeaderText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.four),
                    const TaskFieldLabel('Category'),
                    const SizedBox(height: AppSpacing.two),
                    TaskCompactDropdown<String>(
                      buttonKey: widget.categoryFieldKey,
                      menuKeyBuilder: widget.categoryOptionKeyBuilder,
                      currentValue: _selectedCategoryId,
                      currentLabel: _categories
                          .firstWhere((item) => item.id == _selectedCategoryId)
                          .name,
                      onSelected: (value) {
                        final categoryColor = _categories
                            .firstWhere((item) => item.id == value)
                            .color;
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedCategoryColor = _hasManualColorSelection
                              ? _selectedCategoryColor
                              : categoryColor;
                          if (_hasManualColorSelection) {
                            _categories = [
                              for (final category in _categories)
                                if (category.id == value)
                                  category.copyWith(
                                    colorValue: _selectedCategoryColor
                                        .toARGB32(),
                                  )
                                else
                                  category,
                            ];
                          }
                        });
                      },
                      items: _categories.map((item) => item.id).toList(),
                      labelBuilder: (value) => _categories
                          .firstWhere((item) => item.id == value)
                          .name,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    const TaskFieldLabel('Color Selection'),
                    const SizedBox(height: AppSpacing.three),
                    TaskCategoryColorSelector(
                      scope: 'task-calendar-sheet',
                      selectedColor: _selectedCategoryColor,
                      onSelected: (color) {
                        setState(() {
                          _hasManualColorSelection = true;
                          _selectedCategoryColor = color;
                          _categories = [
                            for (final category in _categories)
                              if (category.id == _selectedCategoryId)
                                category.copyWith(colorValue: color.toARGB32())
                              else
                                category,
                          ];
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.five),
                    const TaskFieldLabel('Schedules'),
                    const SizedBox(height: AppSpacing.oneAndHalf),
                    Text(
                      'Set the target date and time for tasks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.subHeaderText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.three),
                    TaskPickerButton(
                      buttonKey: widget.targetDateButtonKey,
                      title: 'Target Date',
                      value: _formatDate(_targetDate),
                      icon: TablerIcons.calendar_event,
                      onTap: _pickTargetDate,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    TaskPickerButton(
                      buttonKey: widget.targetTimeButtonKey,
                      title: 'Target Time',
                      value:
                          '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                      icon: TablerIcons.clock,
                      onTap: _pickTimeRange,
                    ),
                    if (_rangeError != null) ...[
                      const SizedBox(height: AppSpacing.three),
                      Text(
                        _rangeError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.rose500,
                          fontWeight: AppTypography.weightSemibold,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.five),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: taskButtonStyle(
                              context,
                              role: TaskButtonRole.secondary,
                              size: TaskButtonSize.large,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.three),
                        Expanded(
                          child: FilledButton(
                            key: widget.submitButtonKey,
                            onPressed: _submit,
                            style: taskButtonStyle(
                              context,
                              role: TaskButtonRole.primary,
                              size: TaskButtonSize.large,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: Text(_submitLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TimeOfDay _timeOfDayFromMinutes(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String _formatDate(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}';
}

String _formatTimeOfDay(TimeOfDay value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour12 = switch (value.hour % 12) {
    0 => 12,
    _ => value.hour % 12,
  };
  return '${hour12.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
}

import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../domain/task_category.dart';
import 'task_management_ui.dart';

class TaskQuickScheduleRequest {
  const TaskQuickScheduleRequest({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.targetDate,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String title;
  final String description;
  final String categoryId;
  final DateTime targetDate;
  final int startMinutes;
  final int endMinutes;
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

  @override
  State<TaskScheduleSheet> createState() => _TaskScheduleSheetState();
}

class _TaskScheduleSheetState extends State<TaskScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedCategoryId;
  late DateTime _targetDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categories.first.id;
    _targetDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
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

    Navigator.of(context).pop(
      TaskQuickScheduleRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        targetDate: _targetDate,
        startMinutes: (_startTime.hour * 60) + _startTime.minute,
        endMinutes: (_endTime.hour * 60) + _endTime.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
                    'Schedule Task',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.titleText,
                      fontSize: AppTypography.sizeLg,
                      fontWeight: AppTypography.weightSemibold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.oneAndHalf),
                  Text(
                    'Add and schedule your tasks',
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
                    currentLabel: widget.categories
                        .firstWhere((item) => item.id == _selectedCategoryId)
                        .name,
                    onSelected: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    items: widget.categories.map((item) => item.id).toList(),
                    labelBuilder: (value) => widget.categories
                        .firstWhere((item) => item.id == value)
                        .name,
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
                        '${_startTime.format(context)} - ${_endTime.format(context)}',
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
                          child: const Text('Schedule Task'),
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
    );
  }
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

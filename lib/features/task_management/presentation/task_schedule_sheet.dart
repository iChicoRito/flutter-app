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
    required this.startDate,
    required this.startMinutes,
    required this.endDate,
    required this.endMinutes,
  });

  final String title;
  final String description;
  final String categoryId;
  final DateTime startDate;
  final int startMinutes;
  final DateTime endDate;
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
    required this.swapButtonKey,
    required this.startDateButtonKey,
    required this.endDateButtonKey,
    required this.startTimeButtonKey,
    required this.endTimeButtonKey,
    required this.submitButtonKey,
  });

  final List<TaskCategory> categories;
  final DateTime initialDate;
  final Key sheetKey;
  final Key titleFieldKey;
  final Key descriptionFieldKey;
  final Key categoryFieldKey;
  final Key Function(String value) categoryOptionKeyBuilder;
  final Key swapButtonKey;
  final Key startDateButtonKey;
  final Key endDateButtonKey;
  final Key startTimeButtonKey;
  final Key endTimeButtonKey;
  final Key submitButtonKey;

  @override
  State<TaskScheduleSheet> createState() => _TaskScheduleSheetState();
}

class _TaskScheduleSheetState extends State<TaskScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedCategoryId;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categories.first.id;
    _startDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _endDate = _startDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 1),
      lastDate: DateTime(initialDate.year + 5),
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
    _validateRange();
  }

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onSelected,
    required String helpText,
  }) async {
    final picked = await showTimePicker(
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
    if (picked == null) {
      return;
    }
    onSelected(picked);
    _validateRange();
  }

  void _swapSchedule() {
    setState(() {
      final previousStartDate = _startDate;
      final previousStartTime = _startTime;
      _startDate = _endDate;
      _startTime = _endTime;
      _endDate = previousStartDate;
      _endTime = previousStartTime;
    });
    _validateRange();
  }

  void _validateRange() {
    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
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
        startDate: _startDate,
        startMinutes: (_startTime.hour * 60) + _startTime.minute,
        endDate: _endDate,
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
                    decoration: taskInputDecoration(
                      context: context,
                      hintText: 'Enter Task Title',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.length > 20) {
                        return 'Description must be 20 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.oneAndHalf),
                  Text(
                    'Maximum of 20 characters',
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
                  Row(
                    children: [
                      Expanded(
                        child: TaskPickerButton(
                          buttonKey: widget.startDateButtonKey,
                          title: 'Start Date',
                          value: _formatDate(_startDate),
                          icon: TablerIcons.calendar_event,
                          onTap: () => _pickDate(
                            initialDate: _startDate,
                            onSelected: (value) => setState(() {
                              _startDate = value;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.two),
                      IconButton(
                        key: widget.swapButtonKey,
                        onPressed: _swapSchedule,
                        icon: const Icon(
                          TablerIcons.arrows_exchange,
                          color: AppColors.subHeaderText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.two),
                      Expanded(
                        child: TaskPickerButton(
                          buttonKey: widget.endDateButtonKey,
                          title: 'End Date',
                          value: _formatDate(_endDate),
                          icon: TablerIcons.calendar_event,
                          onTap: () => _pickDate(
                            initialDate: _endDate,
                            onSelected: (value) => setState(() {
                              _endDate = value;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.three),
                  Row(
                    children: [
                      Expanded(
                        child: TaskPickerButton(
                          buttonKey: widget.startTimeButtonKey,
                          title: 'Start Time',
                          value: _startTime.format(context),
                          icon: TablerIcons.clock,
                          onTap: () => _pickTime(
                            initialTime: _startTime,
                            helpText: 'Start Time',
                            onSelected: (value) => setState(() {
                              _startTime = value;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                      Expanded(
                        child: TaskPickerButton(
                          buttonKey: widget.endTimeButtonKey,
                          title: 'End Time',
                          value: _endTime.format(context),
                          icon: TablerIcons.clock,
                          onTap: () => _pickTime(
                            initialTime: _endTime,
                            helpText: 'End Time',
                            onSelected: (value) => setState(() {
                              _endTime = value;
                            }),
                          ),
                        ),
                      ),
                    ],
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

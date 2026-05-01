import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/vault_service_scope.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/vault/vault_models.dart';
import '../../../shared/widgets/custom_category_sheet.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_management_ui.dart';

class TaskDetailsResult {
  const TaskDetailsResult({
    required this.task,
    required this.categories,
    required this.vaultDraft,
  });

  final TaskItem task;
  final List<TaskCategory> categories;
  final VaultDraft vaultDraft;
}

class TaskDetailsFormScreen extends StatefulWidget {
  const TaskDetailsFormScreen({
    super.key,
    required this.repository,
    required this.task,
    required this.categories,
    this.lockedCategoryId,
    this.fixedSpaceId,
    this.titleFieldKey,
    this.descriptionFieldKey,
    this.priorityFieldKey,
    this.categoryFieldKey,
    this.addCategoryButtonKey,
    this.categoryColorSelectionKey,
    this.categoryCurrentIconKey,
    this.saveButtonKey,
    this.dateButtonKey,
    this.dueTimeButtonKey,
    this.timeRangeButtonKey,
  });

  final TaskRepository repository;
  final TaskItem task;
  final List<TaskCategory> categories;
  final String? lockedCategoryId;
  final String? fixedSpaceId;
  final Key? titleFieldKey;
  final Key? descriptionFieldKey;
  final Key? priorityFieldKey;
  final Key? categoryFieldKey;
  final Key? addCategoryButtonKey;
  final Key? categoryColorSelectionKey;
  final Key? categoryCurrentIconKey;
  final Key? saveButtonKey;
  final Key? dateButtonKey;
  final Key? dueTimeButtonKey;
  final Key? timeRangeButtonKey;

  @override
  State<TaskDetailsFormScreen> createState() => _TaskDetailsFormScreenState();
}

class _TaskDetailsFormScreenState extends State<TaskDetailsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickerFocusNode = FocusNode();
  final _uuid = const Uuid();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _vaultSecretController;
  late List<TaskCategory> _categories;
  late TaskPriority _priority;
  late String _selectedCategoryId;
  late Color _selectedCategoryColor;
  late TaskScheduleType _scheduleType;
  DateTime? _targetDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _showScheduleValidation = false;
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
    _selectedCategoryColor =
        _colorForCategory(_selectedCategoryId) ?? taskCategoryColorOptions.first;
    _scheduleType = widget.task.scheduleType;
    _targetDate = widget.task.endDate ?? widget.task.startDate;
    _dueTime = _toTimeOfDay(widget.task.endMinutes);
    _startTime = _toTimeOfDay(widget.task.startMinutes);
    _endTime = _toTimeOfDay(widget.task.endMinutes);
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
    return switch (_scheduleType) {
      TaskScheduleType.noTime => null,
      TaskScheduleType.dueTime =>
        _targetDate == null || _dueTime == null
            ? 'Choose a target date and time for this reminder.'
            : null,
      TaskScheduleType.timeRange => _timeRangeValidationMessage(),
    };
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
      _showScheduleValidation = false;
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

  Future<void> _pickDueTime() async {
    TimeOfDay? pickedTime;
    await _pickTime(
      initialValue: _dueTime ?? TimeOfDay.now(),
      helpText: 'Target Time',
      onSelected: (value) {
        pickedTime = value;
      },
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _dueTime = pickedTime;
      _showScheduleValidation = false;
    });
  }

  Future<void> _pickTimeRange() async {
    TimeOfDay? pickedStart;
    await _pickTime(
      initialValue: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Start Time',
      onSelected: (value) {
        pickedStart = value;
      },
    );
    if (pickedStart == null || !mounted) {
      return;
    }

    setState(() {
      _startTime = pickedStart;
      _showScheduleValidation = false;
    });

    TimeOfDay? pickedEnd;
    await _pickTime(
      initialValue: _endTime ?? const TimeOfDay(hour: 11, minute: 0),
      helpText: 'End Time',
      onSelected: (value) {
        pickedEnd = value;
      },
    );
    if (pickedEnd == null || !mounted) {
      return;
    }

    setState(() {
      _endTime = pickedEnd;
      _showScheduleValidation = false;
    });
  }

  Future<void> _addCategory() async {
    final category = await showCustomCategorySheet(
      context: context,
      existingNames: _categories.map((item) => item.name).toSet(),
      uuid: _uuid,
      initialColor: _selectedCategoryColor,
      showColorSelection: true,
    );
    if (category == null) {
      return;
    }

    await widget.repository.upsertCategory(category);
    setState(() {
      _categories = [..._categories, category]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedCategoryId = category.id;
      _selectedCategoryColor = category.color;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final scheduleValidationMessage = _scheduleValidationMessage();
    if (scheduleValidationMessage != null) {
      setState(() {
        _showScheduleValidation = true;
      });
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

    final selectedCategory = _categoryById(_selectedCategoryId);
    if (selectedCategory != null) {
      await widget.repository.upsertCategory(selectedCategory);
    }

    final trimmedTitle = _titleController.text.trim();
    final trimmedDescription = _descriptionController.text.trim();
    final scheduleFields = switch (_scheduleType) {
      TaskScheduleType.noTime => (null, null, null, null),
      TaskScheduleType.dueTime => (
        null,
        null,
        _targetDate,
        _dueTime == null ? null : (_dueTime!.hour * 60) + _dueTime!.minute,
      ),
      TaskScheduleType.timeRange => (
        _targetDate,
        _startTime == null ? null : (_startTime!.hour * 60) + _startTime!.minute,
        _targetDate,
        _endTime == null ? null : (_endTime!.hour * 60) + _endTime!.minute,
      ),
    };

    Navigator.of(context).pop(
      TaskDetailsResult(
        task: widget.task.copyWith(
          title: trimmedTitle,
          description: trimmedDescription.isEmpty ? null : trimmedDescription,
          priority: _priority,
          categoryId: widget.lockedCategoryId ?? _selectedCategoryId,
          standaloneCategoryId: widget.fixedSpaceId == null
              ? _selectedCategoryId
              : widget.task.standaloneCategoryId,
          spaceId: widget.fixedSpaceId ?? widget.task.spaceId,
          startDate: scheduleFields.$1,
          startMinutes: scheduleFields.$2,
          clearStartDate: scheduleFields.$1 == null,
          clearStartMinutes: scheduleFields.$2 == null,
          endDate: scheduleFields.$3,
          endMinutes: scheduleFields.$4,
          clearEndDate: scheduleFields.$3 == null,
          clearEndMinutes: scheduleFields.$4 == null,
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.four,
              AppSpacing.five,
              AppSpacing.four,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TaskFormPageHeader(title: 'Edit Tasks'),
                const SizedBox(height: AppSpacing.five),
                TaskSectionCard(
                  title: 'Tasks Details',
                  subtitle: 'Add the core information of tasks',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TaskFieldLabel('Task Title'),
                      const SizedBox(height: AppSpacing.two),
                      TextFormField(
                        key: widget.titleFieldKey,
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
                      const SizedBox(height: AppSpacing.four),
                      const TaskFieldLabel('Short Description'),
                      const SizedBox(height: AppSpacing.two),
                      TextFormField(
                        key: widget.descriptionFieldKey,
                        controller: _descriptionController,
                        decoration: taskInputDecoration(
                          context: context,
                          hintText: 'Brief description of the task',
                        ).copyWith(counterText: ''),
                        maxLength: 20,
                        textInputAction: TextInputAction.next,
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
                          color: taskMutedText,
                          fontSize: AppTypography.sizeSm,
                          fontWeight: AppTypography.weightNormal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.four),
                TaskSectionCard(
                  title: 'Tasks Settings',
                  subtitle: 'Set category, urgency, and timing of the tasks',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TaskFieldLabel('Priority'),
                      const SizedBox(height: AppSpacing.two),
                      TaskCompactDropdown<TaskPriority>(
                        buttonKey:
                            widget.priorityFieldKey ?? const Key('task-priority'),
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
                      const SizedBox(height: AppSpacing.four),
                      const TaskFieldLabel('Category'),
                      const SizedBox(height: AppSpacing.two),
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
                                buttonKey:
                                    widget.categoryFieldKey ??
                                    const Key('task-category'),
                                menuKeyBuilder: (value) =>
                                    Key('task-editor-category-$value'),
                                currentValue: _selectedCategoryId,
                                currentLabel:
                                    _categoryLabel(_selectedCategoryId) ??
                                    'Category',
                                onSelected: (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                    _selectedCategoryColor =
                                        _colorForCategory(value) ??
                                        _selectedCategoryColor;
                                  });
                                },
                                items: _categories
                                    .map((item) => item.id)
                                    .toList(),
                                labelBuilder: (value) =>
                                    _categoryLabel(value) ?? 'Category',
                                currentLeading: _buildCategoryIcon(
                                  _categoryById(_selectedCategoryId),
                                  key: widget.categoryCurrentIconKey,
                                ),
                                leadingBuilder: (value) =>
                                    _buildCategoryIcon(_categoryById(value)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.two),
                            SizedBox(
                              width: 120,
                              height: 44,
                              child: FilledButton(
                                key: widget.addCategoryButtonKey,
                                onPressed: _addCategory,
                                style: taskButtonStyle(
                                  context,
                                  role: TaskButtonRole.primary,
                                  size: TaskButtonSize.medium,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.four,
                                    vertical: AppSpacing.three,
                                  ),
                                  minimumSize: const Size(120, 44),
                                  shrinkTapTarget: true,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        TablerIcons.plus,
                                        size: 18,
                                        color: AppColors.primaryButtonText,
                                      ),
                                      const SizedBox(width: AppSpacing.two),
                                      Text(
                                        'Create',
                                        style:
                                            taskButtonTextStyle(
                                              context,
                                              TaskButtonSize.medium,
                                            )?.copyWith(
                                              color:
                                                  AppColors.primaryButtonText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (widget.lockedCategoryId == null) ...[
                        const SizedBox(height: AppSpacing.three),
                        TaskFieldLabel(
                          'Color Selection',
                          key: widget.categoryColorSelectionKey,
                        ),
                        const SizedBox(height: AppSpacing.three),
                        TaskCategoryColorSelector(
                          scope: 'task-editor',
                          selectedColor: _selectedCategoryColor,
                          onSelected: (color) {
                            setState(() {
                              _selectedCategoryColor = color;
                              _syncSelectedCategoryColor(color);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.four),
                TaskFlexibleScheduleSection(
                  scheduleType: _scheduleType,
                  onScheduleTypeChanged: (value) {
                    setState(() {
                      _scheduleType = value;
                      _showScheduleValidation = false;
                    });
                  },
                  targetDateValue: _formatDateValue(_targetDate),
                  onPickDate: _pickDate,
                  targetTimeValue: _formatTimeValue(context, _dueTime),
                  onPickDueTime: _pickDueTime,
                  timeRangeValue: _formatTimeRangeValue(context),
                  onPickTimeRange: _pickTimeRange,
                  validationMessage: _showScheduleValidation
                      ? scheduleValidationMessage
                      : null,
                  dateButtonKey: widget.dateButtonKey,
                  dueTimeButtonKey: widget.dueTimeButtonKey,
                  timeRangeButtonKey: widget.timeRangeButtonKey,
                ),
                const SizedBox(height: AppSpacing.four),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.four,
            AppSpacing.three,
            AppSpacing.four,
            AppSpacing.four,
          ),
          child: FilledButton(
            key: widget.saveButtonKey,
            onPressed: _submit,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.large,
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('Save Changes'),
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

  Color? _colorForCategory(String? id) =>
      id == null ? null : _categoryById(id)?.color;

  Widget? _buildCategoryIcon(TaskCategory? category, {Key? key}) {
    if (category == null) {
      return null;
    }

    final iconColor = category.id == _selectedCategoryId
        ? _selectedCategoryColor
        : category.color;
    return Icon(
      key: key,
      resolveTaskCategoryIcon(category.iconKey),
      color: iconColor,
      size: 18,
    );
  }

  void _syncSelectedCategoryColor(Color color) {
    _categories = [
      for (final category in _categories)
        if (category.id == _selectedCategoryId)
          category.copyWith(colorValue: color.toARGB32())
        else
          category,
    ];
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
    return '${months[date.month - 1]} ${date.day}';
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

  String _formatTimeRangeValue(BuildContext context) {
    if (_startTime == null || _endTime == null) {
      return 'Select target time';
    }
    return '${_formatCompactTime(context, _startTime!)} - ${_formatCompactTime(context, _endTime!)}';
  }

  String? _timeRangeValidationMessage() {
    if (_targetDate == null || _startTime == null || _endTime == null) {
      return 'Choose a target date and start/end time for this schedule.';
    }

    final startMinutes = (_startTime!.hour * 60) + _startTime!.minute;
    final endMinutes = (_endTime!.hour * 60) + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      return 'End time must be after start time.';
    }
    return null;
  }

  String _formatCompactTime(BuildContext context, TimeOfDay value) {
    final label = value.format(context);
    return label.replaceAll(' ', '');
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.four,
        vertical: AppSpacing.three,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.neutral200),
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
                fontSize: AppTypography.sizeBase,
                fontWeight: AppTypography.weightNormal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Locked',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: taskMutedText,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ],
      ),
    );
  }
}

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

const createTitleFieldKey = Key('task-create-title-field');
const createDescriptionFieldKey = Key('task-create-description-field');
const createPriorityFieldKey = Key('task-create-priority-field');
const createCategoryFieldKey = Key('task-create-category-field');
const createSubmitButtonKey = Key('task-create-submit-button');
const createDateRangeButtonKey = Key('task-create-date-range-button');
const createTimeRangeButtonKey = Key('task-create-time-range-button');
const createAddCategoryButtonKey = Key('task-create-add-category');
const createCategoryColorSelectionKey = Key('task-create-category-color-label');
const createCategoryCurrentIconKey = Key('task-create-category-current-icon');

class TaskCreationRequest {
  const TaskCreationRequest({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.priority,
    required this.vaultDraft,
    this.spaceId,
    this.startDate,
    this.startMinutes,
    this.endDate,
    this.endMinutes,
  });

  final String title;
  final String description;
  final String categoryId;
  final TaskPriority priority;
  final VaultDraft vaultDraft;
  final String? spaceId;
  final DateTime? startDate;
  final int? startMinutes;
  final DateTime? endDate;
  final int? endMinutes;
}

class TaskCreationScreen extends StatefulWidget {
  const TaskCreationScreen({
    super.key,
    required this.repository,
    required this.categories,
    this.lockedCategoryId,
    this.spaceId,
    this.appBarTitle = 'Add Task',
  });

  final TaskRepository repository;
  final List<TaskCategory> categories;
  final String? lockedCategoryId;
  final String? spaceId;
  final String appBarTitle;

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vaultSecretController = TextEditingController();
  final _pickerFocusNode = FocusNode();
  final _uuid = const Uuid();

  late List<TaskCategory> _categories;
  late TaskPriority _priority;
  String? _selectedCategoryId;
  late Color _selectedCategoryColor;
  DateTime? _targetDate;
  TimeOfDay? _targetTime;
  bool _vaultEnabled = false;
  VaultMethod _vaultMethod = VaultMethod.password;
  bool? _isDeviceSecurityAvailable;
  bool _didLoadDeviceSecurityAvailability = false;

  String get _pageTitle =>
      widget.appBarTitle == 'Add Task' ? 'Create Tasks' : widget.appBarTitle;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
    _priority = TaskPriority.medium;
    _selectedCategoryId =
        widget.lockedCategoryId ??
        (_categories.isNotEmpty ? _categories.first.id : null);
    _selectedCategoryColor =
        _colorForCategory(_selectedCategoryId) ??
        taskCategoryColorOptions.first;
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

  void _parkFocus() {
    if (!mounted) {
      return;
    }
    FocusScope.of(context).requestFocus(_pickerFocusNode);
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

    if (_vaultEnabled &&
        _vaultMethod == VaultMethod.deviceSecurity &&
        _isDeviceSecurityAvailable == false) {
      showTaskToast(
        context,
        message: 'Device security is not available on this device.',
        isError: true,
      );
      return;
    }

    final selectedCategory = _categoryById(_selectedCategoryId!);
    if (selectedCategory != null) {
      await widget.repository.upsertCategory(selectedCategory);
    }

    Navigator.of(context).pop(
      TaskCreationRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId!,
        priority: _priority,
        vaultDraft: VaultDraft(
          isEnabled: _vaultEnabled,
          method: _vaultEnabled ? _vaultMethod : null,
          secret: _vaultSecretController.text.trim(),
        ),
        spaceId: widget.spaceId,
        startDate: null,
        startMinutes: null,
        endDate: _targetDate,
        endMinutes: _targetTime == null
            ? null
            : (_targetTime!.hour * 60) + _targetTime!.minute,
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.four,
              AppSpacing.five,
              AppSpacing.four,
              120,
            ),
            children: [
              TaskFormPageHeader(title: _pageTitle),
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
                      key: createTitleFieldKey,
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
                      key: createDescriptionFieldKey,
                      controller: _descriptionController,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Enter Task Title',
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
                      buttonKey: createPriorityFieldKey,
                      menuKeyBuilder: (value) =>
                          Key('task-create-priority-${value.name}'),
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
                              buttonKey: createCategoryFieldKey,
                              menuKeyBuilder: (value) =>
                                  Key('task-create-category-$value'),
                              currentValue: _selectedCategoryId!,
                              currentLabel:
                                  _categoryLabel(_selectedCategoryId!) ??
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
                                _categoryById(_selectedCategoryId!),
                                key: createCategoryCurrentIconKey,
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
                              key: createAddCategoryButtonKey,
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
                                            color: AppColors.primaryButtonText,
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
                      const TaskFieldLabel(
                        'Color Selection',
                        key: createCategoryColorSelectionKey,
                      ),
                      const SizedBox(height: AppSpacing.three),
                      TaskCategoryColorSelector(
                        scope: 'task-create',
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
              TaskSectionCard(
                title: 'Schedules',
                subtitle: 'Set the target date and time for tasks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskPickerButton(
                      buttonKey: createDateRangeButtonKey,
                      title: 'Target Date',
                      value: _formatDateValue(_targetDate),
                      icon: TablerIcons.calendar,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.three),
                    TaskPickerButton(
                      buttonKey: createTimeRangeButtonKey,
                      title: 'Target Time',
                      value: _formatTimeValue(context, _targetTime),
                      icon: TablerIcons.clock,
                      onTap: _pickTargetTime,
                    ),
                    if (scheduleValidationMessage != null) ...[
                      const SizedBox(height: AppSpacing.three),
                      Text(
                        scheduleValidationMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: taskDangerText,
                          fontSize: AppTypography.sizeSm,
                          fontWeight: AppTypography.weightSemibold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.four),
              VaultSettingsFields(
                enabled: _vaultEnabled,
                method: _vaultMethod,
                secretController: _vaultSecretController,
                hasExistingSecret: false,
                isDeviceSecurityAvailable: _isDeviceSecurityAvailable,
                onEnabledChanged: (value) async {
                  final vaultService = VaultServiceScope.of(context);
                  bool? available = _isDeviceSecurityAvailable;
                  available ??= await vaultService.isDeviceSecurityAvailable();
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _isDeviceSecurityAvailable = available;
                    _vaultEnabled = value;
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
            key: createSubmitButtonKey,
            onPressed: _submit,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.large,
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('Create Tasks'),
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
    final selectedCategoryId = _selectedCategoryId;
    if (selectedCategoryId == null) {
      return;
    }

    _categories = [
      for (final category in _categories)
        if (category.id == selectedCategoryId)
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

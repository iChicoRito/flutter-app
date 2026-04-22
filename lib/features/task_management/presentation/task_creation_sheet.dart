import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_models.dart';
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

class TaskCreationRequest {
  const TaskCreationRequest({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.priority,
    required this.vaultDraft,
    this.spaceId,
    this.endDate,
    this.endMinutes,
  });

  final String title;
  final String description;
  final String categoryId;
  final TaskPriority priority;
  final VaultDraft vaultDraft;
  final String? spaceId;
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
  DateTime? _targetDate;
  TimeOfDay? _targetTime;
  bool _vaultEnabled = false;
  VaultMethod _vaultMethod = VaultMethod.password;
  bool? _isDeviceSecurityAvailable;
  bool _didLoadDeviceSecurityAvailability = false;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
    _priority = TaskPriority.medium;
    _selectedCategoryId =
        widget.lockedCategoryId ??
        (_categories.isNotEmpty ? _categories.first.id : null);
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
      appBar: AppBar(title: Text(widget.appBarTitle)),
      backgroundColor: taskSurface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    const SizedBox(height: 16),
                    const TaskFieldLabel('Short Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: createDescriptionFieldKey,
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
                              key: createAddCategoryButtonKey,
                              onPressed: _addCategory,
                              icon: const Icon(TablerIcons.plus, size: 18),
                              label: const Text('New'),
                              style: taskButtonStyle(
                                context,
                                role: TaskButtonRole.secondary,
                                size: TaskButtonSize.medium,
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
                subtitle: 'Set the target date and time for this task.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskPickerButton(
                      buttonKey: createDateRangeButtonKey,
                      title: 'Target Date',
                      value: _formatDateValue(_targetDate),
                      icon: TablerIcons.calendar_event,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    TaskPickerButton(
                      buttonKey: createTimeRangeButtonKey,
                      title: 'Target Time',
                      value: _formatTimeValue(context, _targetTime),
                      icon: TablerIcons.clock_hour_8,
                      onTap: _pickTargetTime,
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
              const SizedBox(height: 16),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FilledButton(
            key: createSubmitButtonKey,
            onPressed: _submit,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.large,
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('Create Task'),
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
                      style: taskButtonStyle(
                        context,
                        role: TaskButtonRole.secondary,
                        size: TaskButtonSize.small,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: taskButtonStyle(
                        context,
                        role: TaskButtonRole.primary,
                        size: TaskButtonSize.small,
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

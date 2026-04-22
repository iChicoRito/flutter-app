import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_models.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../domain/task_space.dart';

class SpaceFormResult {
  const SpaceFormResult({
    this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.colorValue,
    required this.vaultDraft,
    this.createdCategories = const [],
  });

  final String? id;
  final String name;
  final String description;
  final String categoryId;
  final int colorValue;
  final VaultDraft vaultDraft;
  final List<TaskCategory> createdCategories;
}

class SpaceFormScreen extends StatefulWidget {
  const SpaceFormScreen({
    super.key,
    required this.categories,
    this.initialSpace,
  });

  final List<TaskCategory> categories;
  final TaskSpace? initialSpace;

  @override
  State<SpaceFormScreen> createState() => _SpaceFormScreenState();
}

class _SpaceFormScreenState extends State<SpaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _vaultSecretController;
  late List<TaskCategory> _categories;
  late String _selectedCategoryId;
  late Color _selectedColor;
  final List<TaskCategory> _createdCategories = [];
  bool _vaultEnabled = false;
  VaultMethod _vaultMethod = VaultMethod.password;
  bool _changeVault = false;
  bool? _isDeviceSecurityAvailable;
  bool _didLoadDeviceSecurityAvailability = false;

  bool get _isEditing => widget.initialSpace != null;

  bool get _hasExistingSecretVault =>
      widget.initialSpace?.vaultConfig?.secretKeyRef != null &&
      (widget.initialSpace?.vaultConfig?.usesSecret ?? false);

  bool get _shouldPreserveExistingVault =>
      _hasExistingSecretVault && !_changeVault;

  @override
  void initState() {
    super.initState();
    final initialSpace = widget.initialSpace;
    _nameController = TextEditingController(text: initialSpace?.name ?? '');
    _descriptionController = TextEditingController(
      text: initialSpace?.description ?? '',
    );
    _vaultSecretController = TextEditingController();
    _categories = [...widget.categories];
    _selectedCategoryId =
        initialSpace?.categoryId ??
        (_categories.isNotEmpty ? _categories.first.id : '');
    _selectedColor =
        initialSpace?.color ??
        _categoryById(_selectedCategoryId)?.color ??
        taskPrimaryBlue;
    if (initialSpace?.vaultConfig case final vaultConfig?) {
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
    _nameController.dispose();
    _descriptionController.dispose();
    _vaultSecretController.dispose();
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

  TaskCategory? _categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  Future<void> _addCategory() async {
    final category = await showDialog<TaskCategory>(
      context: context,
      builder: (context) {
        return _SpaceCategoryDialog(
          existingNames: _categories.map((item) => item.name).toSet(),
          uuid: _uuid,
        );
      },
    );

    if (category == null) {
      return;
    }

    setState(() {
      _createdCategories.add(category);
      _categories = [..._categories, category]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedCategoryId = category.id;
      _selectedColor = category.color;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
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

    Navigator.of(context).pop(
      SpaceFormResult(
        id: widget.initialSpace?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        colorValue: _selectedColor.toARGB32(),
        createdCategories: List<TaskCategory>.unmodifiable(_createdCategories),
        vaultDraft: VaultDraft(
          isEnabled: _vaultEnabled,
          method: _vaultEnabled ? _vaultMethod : null,
          secret: _vaultSecretController.text.trim(),
          preserveExistingConfig: _shouldPreserveExistingVault,
          keepExistingSecret:
              !_shouldPreserveExistingVault &&
              widget.initialSpace?.vaultConfig?.secretKeyRef != null &&
              _vaultSecretController.text.trim().isEmpty &&
              _vaultMethod == widget.initialSpace?.vaultConfig?.method,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: taskSurface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Space' : 'Create Space'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              TaskSectionCard(
                title: 'Space Details',
                subtitle: 'Define the space name and the short preview text.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Space Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      maxLength: 16,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Enter space name',
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Space name is required.';
                        }
                        if (trimmed.length > 16) {
                          return 'Space name must be 16 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Maximum of 16 characters',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: taskMutedText),
                    ),
                    const SizedBox(height: 16),
                    const TaskFieldLabel('Short Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 50,
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Folder short description',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Maximum of 50 characters',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: taskMutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TaskSectionCard(
                title: 'Space Settings',
                subtitle:
                    'Choose the category and visual color for this space.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Category'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TaskCompactDropdown<String>(
                            buttonKey: const Key('space-form-category'),
                            menuKeyBuilder: (value) =>
                                Key('space-form-category-$value'),
                            currentValue: _selectedCategoryId,
                            currentLabel:
                                _categoryById(_selectedCategoryId)?.name ??
                                'Category',
                            currentLeading:
                                _categoryById(_selectedCategoryId) == null
                                ? null
                                : Icon(
                                    resolveTaskCategoryIcon(
                                      _categoryById(
                                        _selectedCategoryId,
                                      )!.iconKey,
                                    ),
                                    color: _categoryById(
                                      _selectedCategoryId,
                                    )!.color,
                                    size: 18,
                                  ),
                            onSelected: (value) {
                              setState(() {
                                _selectedCategoryId = value;
                                _selectedColor =
                                    _categoryById(value)?.color ??
                                    _selectedColor;
                              });
                            },
                            items: _categories.map((item) => item.id).toList(),
                            labelBuilder: (value) =>
                                _categoryById(value)?.name ?? 'Category',
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
                    const SizedBox(height: 16),
                    const TaskFieldLabel('Space Color'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final color in taskCategoryColorOptions)
                          _ColorOptionChip(
                            color: color,
                            isSelected:
                                color.toARGB32() == _selectedColor.toARGB32(),
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              VaultSettingsFields(
                enabled: _vaultEnabled,
                method: _vaultMethod,
                secretController: _vaultSecretController,
                hasExistingSecret:
                    widget.initialSpace?.vaultConfig?.secretKeyRef != null,
                isEditing: _isEditing,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FilledButton(
            onPressed: _submit,
            style: taskButtonStyle(
              context,
              role: TaskButtonRole.primary,
              size: TaskButtonSize.large,
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_isEditing ? 'Save Space' : 'Create Space'),
          ),
        ),
      ),
    );
  }
}

class _ColorOptionChip extends StatelessWidget {
  const _ColorOptionChip({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? taskDarkText : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class _SpaceCategoryDialog extends StatefulWidget {
  const _SpaceCategoryDialog({required this.existingNames, required this.uuid});

  final Set<String> existingNames;
  final Uuid uuid;

  @override
  State<_SpaceCategoryDialog> createState() => _SpaceCategoryDialogState();
}

class _SpaceCategoryDialogState extends State<_SpaceCategoryDialog> {
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

import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/vault_service_scope.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/vault/vault_models.dart';
import '../../../shared/widgets/custom_category_sheet.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../domain/task_space.dart';

const spaceFormCategoryFieldKey = Key('space-form-category');
const spaceFormCategoryCurrentIconKey = Key('space-form-category-current-icon');

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

  String get _pageTitle => _isEditing ? 'Edit Space' : 'Create Space';

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
    final category = await showCustomCategorySheet(
      context: context,
      existingNames: _categories.map((item) => item.name).toSet(),
      uuid: _uuid,
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
        description: '',
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
                title: 'Space Details',
                subtitle: 'Add the core information of spaces',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Space Name'),
                    const SizedBox(height: AppSpacing.two),
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
                    const SizedBox(height: AppSpacing.one + 2),
                    Text(
                      'Maximum of 16 characters',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: taskMutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.four),
              TaskSectionCard(
                title: 'Space Settings',
                subtitle: 'Set category and color of the spaces',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Category'),
                    const SizedBox(height: AppSpacing.two),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TaskCompactDropdown<String>(
                            buttonKey: spaceFormCategoryFieldKey,
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
                                    key: spaceFormCategoryCurrentIconKey,
                                    resolveTaskCategoryIcon(
                                      _categoryById(
                                        _selectedCategoryId,
                                      )!.iconKey,
                                    ),
                                    color: _selectedColor,
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
                        const SizedBox(width: AppSpacing.three),
                        SizedBox(
                          width: 120,
                          height: 44,
                          child: FilledButton(
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
                    const SizedBox(height: AppSpacing.four),
                    const TaskFieldLabel('Space Color'),
                    const SizedBox(height: AppSpacing.three - 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final color in taskCategoryColorOptions)
                          _ColorOptionChip(
                            chipKey: taskCategoryColorChoiceKey(
                              'space-form',
                              color,
                            ),
                            selectedCheckKey: taskCategorySelectedColorCheckKey(
                              'space-form',
                              color,
                            ),
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
              const SizedBox(height: AppSpacing.four),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.four,
            AppSpacing.three,
            AppSpacing.four,
            AppSpacing.four,
          ),
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
    required this.chipKey,
    required this.selectedCheckKey,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Key chipKey;
  final Key selectedCheckKey;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: isSelected
            ? Icon(
                key: selectedCheckKey,
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              )
            : null,
      ),
    );
  }
}

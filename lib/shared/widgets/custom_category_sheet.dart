import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_design_tokens.dart';
import '../../features/task_management/domain/task_category.dart';
import '../../features/task_management/presentation/task_management_ui.dart';

const customCategoryNameFieldKey = Key('custom-category-name-field');
const customCategoryCancelButtonKey = Key('custom-category-cancel-button');
const customCategoryCreateButtonKey = Key('custom-category-create-button');

Future<TaskCategory?> showCustomCategorySheet({
  required BuildContext context,
  required Set<String> existingNames,
  required Uuid uuid,
}) {
  return showModalBottomSheet<TaskCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _CustomCategorySheet(existingNames: existingNames, uuid: uuid);
    },
  );
}

class _CustomCategorySheet extends StatefulWidget {
  const _CustomCategorySheet({required this.existingNames, required this.uuid});

  final Set<String> existingNames;
  final Uuid uuid;

  @override
  State<_CustomCategorySheet> createState() => _CustomCategorySheetState();
}

class _CustomCategorySheetState extends State<_CustomCategorySheet> {
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final sheetHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.72,
      560.0,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.threeXl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.three),
                Container(
                  width: 96,
                  height: AppSpacing.oneAndHalf,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                ),
                const SizedBox(height: AppSpacing.six),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.eight,
                      0,
                      AppSpacing.eight,
                      AppSpacing.six,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Category',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.titleText,
                                fontSize: AppTypography.sizeLg,
                                fontWeight: AppTypography.weightSemibold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.two),
                        Text(
                          'Create your own customized category',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.subHeaderText,
                                fontSize: AppTypography.sizeBase,
                                fontWeight: AppTypography.weightNormal,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.six),
                        const TaskFieldLabel('Category Name'),
                        const SizedBox(height: AppSpacing.three),
                        TextFormField(
                          key: customCategoryNameFieldKey,
                          controller: _nameController,
                          decoration: taskInputDecoration(
                            context: context,
                            hintText: 'Enter category name',
                          ),
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return 'Category name is required.';
                            }
                            if (trimmed.length > 10) {
                              return 'Category name must be 10 characters or fewer.';
                            }
                            if (widget.existingNames.any(
                              (name) =>
                                  name.toLowerCase() == trimmed.toLowerCase(),
                            )) {
                              return 'Choose a unique category name.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.two),
                        Text(
                          'Maximum of 10 characters',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.subHeaderText,
                                fontSize: AppTypography.sizeSm,
                                fontWeight: AppTypography.weightNormal,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.six),
                        const TaskFieldLabel('Icons'),
                        const SizedBox(height: AppSpacing.four),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const columns = 6;
                            const spacing = AppSpacing.two;
                            final itemSize =
                                (constraints.maxWidth -
                                    (spacing * (columns - 1))) /
                                columns;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                for (final option in taskCategoryIconOptions)
                                  SizedBox(
                                    width: itemSize,
                                    height: itemSize,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedIconKey = option.key;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.twoXl,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedIconKey == option.key
                                              ? AppColors.primaryButtonFill
                                              : AppColors.neutral100,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.twoXl,
                                          ),
                                          border: Border.all(
                                            color:
                                                _selectedIconKey == option.key
                                                ? AppColors.primaryButtonFill
                                                : AppColors.neutral200,
                                          ),
                                        ),
                                        child: Icon(
                                          option.icon,
                                          size: 22,
                                          color: _selectedIconKey == option.key
                                              ? AppColors.primaryButtonText
                                              : AppColors.neutral400,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.six),
                        const TaskFieldLabel('Color Selection'),
                        const SizedBox(height: AppSpacing.four),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final color in taskCategoryColorOptions)
                              _ColorChoiceChip(
                                color: color,
                                selected:
                                    _selectedColor.toARGB32() ==
                                    color.toARGB32(),
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.eight,
                    0,
                    AppSpacing.eight,
                    AppSpacing.six,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: customCategoryCancelButtonKey,
                          onPressed: () => Navigator.of(context).pop(),
                          style: taskButtonStyle(
                            context,
                            role: TaskButtonRole.secondary,
                            size: TaskButtonSize.large,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.three),
                      Expanded(
                        child: FilledButton(
                          key: customCategoryCreateButtonKey,
                          onPressed: _submit,
                          style: taskButtonStyle(
                            context,
                            role: TaskButtonRole.primary,
                            size: TaskButtonSize.large,
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
        ),
      ),
    );
  }
}

class _ColorChoiceChip extends StatelessWidget {
  const _ColorChoiceChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.blue100 : AppColors.cardFill,
            width: 2,
          ),
        ),
      ),
    );
  }
}

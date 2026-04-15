import 'package:flutter/material.dart';

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
  });

  final String? id;
  final String name;
  final String description;
  final String categoryId;
  final int colorValue;
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
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _selectedCategoryId;
  late Color _selectedColor;

  bool get _isEditing => widget.initialSpace != null;

  @override
  void initState() {
    super.initState();
    final initialSpace = widget.initialSpace;
    _nameController = TextEditingController(text: initialSpace?.name ?? '');
    _descriptionController = TextEditingController(
      text: initialSpace?.description ?? '',
    );
    _selectedCategoryId =
        initialSpace?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : '');
    _selectedColor = initialSpace?.color ?? taskPrimaryBlue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  TaskCategory? _categoryById(String id) {
    for (final category in widget.categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      SpaceFormResult(
        id: widget.initialSpace?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        colorValue: _selectedColor.toARGB32(),
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
                      decoration: taskInputDecoration(
                        context: context,
                        hintText: 'Enter space name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Space name is required.';
                        }
                        return null;
                      },
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
                subtitle: 'Choose the category and visual color for this space.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaskFieldLabel('Category'),
                    const SizedBox(height: 8),
                    TaskCompactDropdown<String>(
                      buttonKey: const Key('space-form-category'),
                      menuKeyBuilder: (value) => Key('space-form-category-$value'),
                      currentValue: _selectedCategoryId,
                      currentLabel:
                          _categoryById(_selectedCategoryId)?.name ?? 'Category',
                      currentLeading: _categoryById(_selectedCategoryId) == null
                          ? null
                          : Icon(
                              resolveTaskCategoryIcon(
                                _categoryById(_selectedCategoryId)!.iconKey,
                              ),
                              color: _selectedColor,
                              size: 18,
                            ),
                      onSelected: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      items: widget.categories.map((item) => item.id).toList(),
                      labelBuilder: (value) =>
                          _categoryById(value)?.name ?? 'Category',
                      leadingBuilder: (value) {
                        final category = _categoryById(value);
                        if (category == null) {
                          return null;
                        }
                        return Icon(
                          resolveTaskCategoryIcon(category.iconKey),
                          color: _selectedColor,
                          size: 18,
                        );
                      },
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
                            isSelected: color.toARGB32() == _selectedColor.toARGB32(),
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
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: taskPrimaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
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

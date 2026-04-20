import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/services/task_reminder_service.dart';
import '../../../core/services/vault_service_scope.dart';
import '../../../core/vault/vault_access.dart';
import '../../../core/vault/vault_models.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/domain/task_repository.dart';
import '../../task_management/presentation/task_management_ui.dart';
import '../domain/task_space.dart';
import 'space_detail_screen.dart';
import 'space_form_screen.dart';
import 'spaces_controller.dart';

enum SpacesViewMode { list, grid }

class SpacesPage extends StatefulWidget {
  const SpacesPage({
    super.key,
    required this.repository,
    required this.reminderService,
  });

  static const Key vaultDropdownKey = Key('spaces-vault-dropdown');

  static Key vaultFilterKey(String value) => Key('spaces-vault-filter-$value');

  final TaskRepository repository;
  final TaskReminderService reminderService;

  @override
  State<SpacesPage> createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> {
  static const _viewModeKey = 'spaces_view_mode';

  late final SpacesController _controller = SpacesController(
    widget.repository,
    reminderService: widget.reminderService,
  )..load();

  final TextEditingController _searchController = TextEditingController();
  SpacesViewMode _viewMode = SpacesViewMode.list;
  bool _isFiltersExpanded = false;

  @override
  void initState() {
    super.initState();
    _restoreViewMode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_viewModeKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _viewMode = raw == SpacesViewMode.grid.name
          ? SpacesViewMode.grid
          : SpacesViewMode.list;
    });
  }

  Future<void> _setViewMode(SpacesViewMode mode) async {
    if (_viewMode == mode) {
      return;
    }
    setState(() {
      _viewMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode.name);
  }

  Future<void> _openSpaceForm({TaskSpace? initialSpace}) async {
    if (_controller.categories.isEmpty) {
      showTaskToast(
        context,
        message: 'Add a category first before creating a space.',
        isError: true,
      );
      return;
    }

    final result = await Navigator.of(context).push<SpaceFormResult>(
      MaterialPageRoute<SpaceFormResult>(
        builder: (context) => SpaceFormScreen(
          categories: _controller.categories,
          initialSpace: initialSpace,
        ),
      ),
    );

    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      VaultConfig? nextVaultConfig = initialSpace?.vaultConfig;
      List<String> recoveryKeys = const [];
      if (!result.vaultDraft.preserveExistingConfig) {
        final vaultService = VaultServiceScope.of(context);
        final vaultResolution = await vaultService.resolveConfig(
          entityKey: initialSpace == null
              ? 'space:create:${DateTime.now().microsecondsSinceEpoch}'
              : spaceVaultEntityKey(initialSpace.id),
          draft: result.vaultDraft,
          existingConfig: initialSpace?.vaultConfig,
        );
        nextVaultConfig = vaultResolution.config;
        recoveryKeys = vaultResolution.recoveryKeys;
      }
      await _controller.saveSpace(
        id: result.id,
        name: result.name,
        description: result.description,
        categoryId: result.categoryId,
        colorValue: result.colorValue,
        vaultConfig: nextVaultConfig,
      );
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: initialSpace == null
            ? 'Space created successfully.'
            : 'Space updated successfully.',
      );
      if (recoveryKeys.isNotEmpty) {
        await showVaultRecoveryKeysDialog(
          context: context,
          recoveryKeys: recoveryKeys,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to save the space right now.',
        isError: true,
      );
    }
  }

  Future<void> _deleteSpace(TaskSpace space) async {
    if (!await _confirmVaultProtectedSpaceAction(space)) {
      return;
    }
    if (!mounted) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteSpaceDialog(spaceName: space.name),
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await _controller.deleteSpace(space.id);
      if (!mounted) {
        return;
      }
      showTaskToast(context, message: 'Space deleted successfully.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to delete the space right now.',
        isError: true,
      );
    }
  }

  Future<void> _openSpace(TaskSpace space) async {
    final vaultService = VaultServiceScope.of(context);
    var targetSpace = space;
    final unlockResult = await ensureUnlocked(
      context: context,
      vaultService: vaultService,
      entityKey: spaceVaultEntityKey(space.id),
      title: space.name,
      entityKind: VaultEntityKind.space,
      config: space.vaultConfig,
      onRecoveryReset: (resolution) async {
        final config = resolution.config;
        if (config == null) {
          return;
        }
        targetSpace = space.copyWith(
          vaultConfig: config,
          updatedAt: DateTime.now(),
        );
        await widget.repository.upsertSpace(targetSpace);
        await _controller.load();
      },
    );
    if (!mounted) {
      return;
    }
    if (unlockResult == VaultUnlockResult.failed) {
      showTaskToast(
        context,
        message: 'Incorrect vault password or PIN.',
        backgroundColor: const Color(0xFFFFEBEE),
        foregroundColor: taskDangerText,
      );
      return;
    }
    if (unlockResult == VaultUnlockResult.cancelled) {
      return;
    }
    if (unlockResult == VaultUnlockResult.unlocked) {
      showTaskToast(context, message: 'Unlocked successfully.');
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SpaceDetailScreen(
          repository: widget.repository,
          reminderService: widget.reminderService,
          space: targetSpace,
        ),
      ),
    );
    await _controller.load();
  }

  Future<void> _handleSpaceMenuAction(
    TaskSpace space,
    _SpaceAction action,
  ) async {
    switch (action) {
      case _SpaceAction.edit:
        if (!await _confirmVaultProtectedSpaceAction(space)) {
          return;
        }
        if (!mounted) {
          return;
        }
        await _openSpaceForm(initialSpace: space);
      case _SpaceAction.delete:
        await _deleteSpace(space);
    }
  }

  Future<void> _showSpaceActions(TaskSpace space) async {
    if (!await _confirmVaultProtectedSpaceAction(space)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final action = await showModalBottomSheet<_SpaceAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: taskMutedBorderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _ActionTile(
                  icon: TablerIcons.edit,
                  label: 'Edit Space',
                  onTap: () => Navigator.of(context).pop(_SpaceAction.edit),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: TablerIcons.trash,
                  label: 'Delete Space',
                  isDestructive: true,
                  onTap: () => Navigator.of(context).pop(_SpaceAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SpaceAction.edit:
        await _openSpaceForm(initialSpace: space);
      case _SpaceAction.delete:
        await _deleteSpace(space);
    }
  }

  Future<bool> _confirmVaultProtectedSpaceAction(TaskSpace space) async {
    if (space.vaultConfig == null) {
      return true;
    }

    final result = await ensureUnlocked(
      context: context,
      vaultService: VaultServiceScope.of(context),
      entityKey: spaceVaultEntityKey(space.id),
      title: space.name,
      entityKind: VaultEntityKind.space,
      config: space.vaultConfig,
      forcePrompt: true,
      onRecoveryReset: (resolution) async {
        final config = resolution.config;
        if (config == null) {
          return;
        }
        await widget.repository.upsertSpace(
          space.copyWith(vaultConfig: config, updatedAt: DateTime.now()),
        );
        await _controller.load();
      },
    );
    if (!mounted) {
      return false;
    }
    if (result == VaultUnlockResult.failed) {
      showTaskToast(
        context,
        message: 'Incorrect vault password or PIN.',
        backgroundColor: const Color(0xFFFFEBEE),
        foregroundColor: taskDangerText,
      );
      return false;
    }
    if (result == VaultUnlockResult.cancelled) {
      return false;
    }
    if (result == VaultUnlockResult.unlocked) {
      showTaskToast(context, message: 'Unlocked successfully.');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filteredSpaces = _controller.filteredSpaces();

        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.errorMessage != null) {
          return _SpacesErrorState(
            message: _controller.errorMessage!,
            onRetry: _controller.load,
          );
        }

        return ColoredBox(
          color: taskSurface,
          child: Stack(
            children: [
              RefreshIndicator(
                color: taskPrimaryBlue,
                onRefresh: _controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Spaces',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: taskDarkText,
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Organize & manage your tasks spaces',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: taskMutedText,
                                fontSize: 14,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SpacesSearchField(
                      controller: _searchController,
                      onChanged: _controller.updateSearchQuery,
                    ),
                    const SizedBox(height: 16),
                    _SpacesFiltersSection(
                      title: 'Filters',
                      subtitle:
                          'Search across space names, descriptions, and categories.',
                      isExpanded: _isFiltersExpanded,
                      onHeaderTap: () {
                        setState(() {
                          _isFiltersExpanded = !_isFiltersExpanded;
                        });
                      },
                      child: _SpacesCategoryFilterRow(
                        categories: _controller.categories,
                        selectedCategoryId: _controller.categoryFilterId,
                        selectedVaultFilter: _controller.vaultFilter,
                        onCategorySelected: _controller.updateCategoryFilter,
                        onVaultSelected: _controller.updateVaultFilter,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _SpacesViewToggle(
                          viewMode: _viewMode,
                          onChanged: _setViewMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_controller.spaces.isEmpty)
                      const _SpacesEmptyState()
                    else if (filteredSpaces.isEmpty)
                      const _SpacesFilteredEmptyState()
                    else if (_viewMode == SpacesViewMode.list)
                      ...filteredSpaces.map(
                        (space) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SpaceListCard(
                            space: space,
                            category: _controller.categoryFor(space.categoryId),
                            taskCount: _controller.taskCountFor(space.id),
                            previewProtected: isPreviewProtected(
                              vaultService: VaultServiceScope.of(context),
                              ownVault: space.vaultConfig,
                              ownEntityKey: spaceVaultEntityKey(space.id),
                              inheritedVault: null,
                              inheritedEntityKey: null,
                            ),
                            onTap: () => _openSpace(space),
                            onLongPress: () => _showSpaceActions(space),
                            onMenuSelected: (action) async {
                              switch (action) {
                                case _SpaceAction.edit:
                                  await _openSpaceForm(initialSpace: space);
                                case _SpaceAction.delete:
                                  await _deleteSpace(space);
                              }
                            },
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSpaces.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.56,
                            ),
                        itemBuilder: (context, index) {
                          final space = filteredSpaces[index];
                          return _SpaceGridCard(
                            space: space,
                            category: _controller.categoryFor(space.categoryId),
                            taskCount: _controller.taskCountFor(space.id),
                            previewProtected: isPreviewProtected(
                              vaultService: VaultServiceScope.of(context),
                              ownVault: space.vaultConfig,
                              ownEntityKey: spaceVaultEntityKey(space.id),
                              inheritedVault: null,
                              inheritedEntityKey: null,
                            ),
                            onTap: () => _openSpace(space),
                            onLongPress: () => _showSpaceActions(space),
                            onMenuSelected: (action) =>
                                _handleSpaceMenuAction(space, action),
                          );
                        },
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: _controller.isSaving ? null : _openSpaceForm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 52),
                      backgroundColor: taskPrimaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(TablerIcons.plus, size: 18),
                    label: const Text('Add Space'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpacesViewToggle extends StatelessWidget {
  const _SpacesViewToggle({required this.viewMode, required this.onChanged});

  final SpacesViewMode viewMode;
  final ValueChanged<SpacesViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isList = viewMode == SpacesViewMode.list;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: taskBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            isSelected: !isList,
            label: 'Grid',
            icon: TablerIcons.layout_grid,
            onTap: () => onChanged(SpacesViewMode.grid),
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            isSelected: isList,
            label: 'List',
            icon: TablerIcons.list_details,
            onTap: () => onChanged(SpacesViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _SpacesSearchField extends StatelessWidget {
  const _SpacesSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: taskInputDecoration(
        context: context,
        hintText: 'Search spaces, descriptions, categories',
        prefixIcon: const Icon(
          TablerIcons.search,
          size: 18,
          color: taskMutedText,
        ),
      ),
    );
  }
}

class _SpacesFiltersSection extends StatelessWidget {
  const _SpacesFiltersSection({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onHeaderTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onHeaderTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: taskDarkText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: taskSecondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isExpanded
                      ? TablerIcons.chevron_up
                      : TablerIcons.chevron_down,
                  size: 18,
                  color: taskMutedText,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: taskBorderColor),
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}

class _SpacesCategoryFilterRow extends StatelessWidget {
  const _SpacesCategoryFilterRow({
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedVaultFilter,
    required this.onCategorySelected,
    required this.onVaultSelected,
  });

  final List<TaskCategory> categories;
  final String? selectedCategoryId;
  final SpacesVaultFilter selectedVaultFilter;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<SpacesVaultFilter> onVaultSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskCompactDropdown<SpacesVaultFilter>(
          buttonKey: SpacesPage.vaultDropdownKey,
          menuKeyBuilder: (value) => SpacesPage.vaultFilterKey(value.name),
          currentValue: selectedVaultFilter,
          currentLabel: _vaultFilterLabel(selectedVaultFilter),
          onSelected: onVaultSelected,
          items: SpacesVaultFilter.values,
          labelBuilder: _vaultFilterLabel,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SpacesCategoryChip(
                  label: 'All Categories',
                  icon: null,
                  iconColor: selectedCategoryId == null
                      ? Colors.white
                      : taskMutedText,
                  selected: selectedCategoryId == null,
                  onTap: () => onCategorySelected(null),
                ),
              ),
              ...categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SpacesCategoryChip(
                    label: category.name,
                    icon: resolveTaskCategoryIcon(category.iconKey),
                    iconColor: selectedCategoryId == category.id
                        ? Colors.white
                        : category.color,
                    selected: selectedCategoryId == category.id,
                    onTap: () => onCategorySelected(
                      selectedCategoryId == category.id ? null : category.id,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  static String _vaultFilterLabel(SpacesVaultFilter filter) {
    return switch (filter) {
      SpacesVaultFilter.all => 'All Vault',
      SpacesVaultFilter.vaultOnly => 'Vault',
      SpacesVaultFilter.nonVaultOnly => 'Non-Vault',
    };
  }
}

class _SpacesCategoryChip extends StatelessWidget {
  const _SpacesCategoryChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: taskFilterControlHeight,
          maxHeight: taskFilterControlHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? taskPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? taskPrimaryBlue : taskBorderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : taskSecondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool isSelected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? taskAccentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? taskPrimaryBlue : taskMutedText,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: taskPrimaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SpaceAction { edit, delete }

class _SpaceListCard extends StatelessWidget {
  const _SpaceListCard({
    required this.space,
    required this.category,
    required this.taskCount,
    required this.previewProtected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuSelected,
  });

  final TaskSpace space;
  final TaskCategory? category;
  final int taskCount;
  final bool previewProtected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function(_SpaceAction action) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: taskBorderColor),
          ),
          child: Row(
            children: [
              _FolderAccent(color: space.color, count: taskCount),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            space.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: taskDarkText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (space.vaultConfig?.isEnabled == true) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            TablerIcons.lock,
                            size: 14,
                            color: taskMutedText,
                          ),
                        ],
                        const SizedBox(width: 8),
                        if (category != null)
                          _CategoryPill(
                            label: category!.name,
                            color: space.color,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previewProtected
                          ? 'Protected content'
                          : space.description.isEmpty
                          ? 'Folder short description'
                          : space.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: taskMutedText),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_SpaceAction>(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                onSelected: (value) => onMenuSelected(value),
                itemBuilder: (context) => [
                  const PopupMenuItem<_SpaceAction>(
                    value: _SpaceAction.edit,
                    child: Text('Edit'),
                  ),
                  PopupMenuItem<_SpaceAction>(
                    value: _SpaceAction.delete,
                    child: Text(
                      'Delete',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: taskDangerText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                icon: const Icon(
                  TablerIcons.dots_vertical,
                  size: 18,
                  color: taskMutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceGridCard extends StatelessWidget {
  const _SpaceGridCard({
    required this.space,
    required this.category,
    required this.taskCount,
    required this.previewProtected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuSelected,
  });

  final TaskSpace space;
  final TaskCategory? category;
  final int taskCount;
  final bool previewProtected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<void> Function(_SpaceAction action) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: taskBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: category == null
                            ? const SizedBox.shrink()
                            : _CategoryPill(
                                label: category!.name,
                                color: space.color,
                              ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<_SpaceAction>(
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        onSelected: (value) => onMenuSelected(value),
                        itemBuilder: (context) => [
                          const PopupMenuItem<_SpaceAction>(
                            value: _SpaceAction.edit,
                            child: Text('Edit'),
                          ),
                          PopupMenuItem<_SpaceAction>(
                            value: _SpaceAction.delete,
                            child: Text(
                              'Delete',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: taskDangerText,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          TablerIcons.dots_vertical,
                          size: 18,
                          color: taskMutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Divider(
                height: 1,
                thickness: 1,
                color: taskMutedBorderColor,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: Center(
                  child: _FolderAccent(
                    color: space.color,
                    count: taskCount,
                    large: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (space.vaultConfig?.isEnabled == true) ...[
                const _SpaceLockBadge(),
                const SizedBox(height: 4),
              ],
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    space.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: taskDarkText,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 26,
                child: Text(
                  previewProtected
                      ? 'Protected content'
                      : space.description.isEmpty
                      ? 'Folder short description'
                      : space.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: taskMutedText,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderAccent extends StatelessWidget {
  const _FolderAccent({
    required this.color,
    required this.count,
    this.large = false,
  });

  final Color color;
  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final folderSize = large ? 68.0 : 42.0;
    final iconSize = large ? 36.0 : 24.0;
    final badgeSize = large ? 26.0 : 18.0;
    final frameSize = large ? 90.0 : 48.0;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: folderSize,
            height: folderSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(TablerIcons.folder, size: iconSize, color: color),
          ),
          if (count > 0)
            Positioned(
              top: large ? 1 : -1,
              right: large ? 5 : -1,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: large ? 12 : 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpaceLockBadge extends StatelessWidget {
  const _SpaceLockBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: taskSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.lock, size: 12, color: taskSecondaryText),
            const SizedBox(width: 6),
            Text(
              'Locked',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: taskSecondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SpacesEmptyState extends StatelessWidget {
  const _SpacesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: taskAccentBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                TablerIcons.folder_plus,
                size: 34,
                color: taskPrimaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No spaces yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create one to organize your tasks and keep related work together.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: taskMutedText, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SpacesFilteredEmptyState extends StatelessWidget {
  const _SpacesFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: taskAccentBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              TablerIcons.search_off,
              size: 34,
              color: taskPrimaryBlue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No matching spaces',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your search or category filters to see more spaces.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: taskMutedText, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DeleteSpaceDialog extends StatelessWidget {
  const _DeleteSpaceDialog({required this.spaceName});

  final String spaceName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: taskDangerText,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Space',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: taskDangerText,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Deleting "$spaceName" will remove all tasks inside. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: taskSecondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFFF1F3F5),
                      foregroundColor: taskDarkText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: taskDangerText,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Delete Space'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? taskDangerText : taskDarkText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? taskDangerText.withValues(alpha: 0.06)
              : taskSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpacesErrorState extends StatelessWidget {
  const _SpacesErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              TablerIcons.alert_circle,
              size: 36,
              color: taskDangerText,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: taskDarkText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: taskPrimaryBlue),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

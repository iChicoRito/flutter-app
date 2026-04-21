import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/vault/vault_models.dart';
import '../../../core/services/task_reminder_service.dart';
import '../../task_management/domain/task_category.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/domain/task_repository.dart';
import '../domain/task_space.dart';

enum SpacesVaultFilter { all, vaultOnly, nonVaultOnly }

class SpacesController extends ChangeNotifier {
  SpacesController(
    this._repository, {
    TaskReminderService? reminderService,
    Uuid? uuid,
  }) : _reminderService = reminderService ?? const NoopTaskReminderService(),
       _uuid = uuid ?? const Uuid();

  final TaskRepository _repository;
  final TaskReminderService _reminderService;
  final Uuid _uuid;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String searchQuery = '';
  String? categoryFilterId;
  SpacesVaultFilter _vaultFilter = SpacesVaultFilter.all;
  List<TaskSpace> _spaces = [];
  List<TaskCategory> _categories = [];
  List<TaskItem> _tasks = [];

  List<TaskSpace> get spaces => _visibleSpaces(_spaces);
  List<TaskCategory> get categories => _categories;
  SpacesVaultFilter get vaultFilter => _vaultFilter;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSpaces(),
        _repository.getCategories(),
        _repository.getTasks(),
      ]);
      _spaces = results[0] as List<TaskSpace>;
      _categories = results[1] as List<TaskCategory>;
      _tasks = results[2] as List<TaskItem>;
    } catch (_) {
      errorMessage = 'Unable to load your spaces right now.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  TaskCategory? categoryFor(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  int taskCountFor(String spaceId) {
    return _tasks
        .where((task) => task.spaceId == spaceId && !task.isArchived)
        .length;
  }

  void updateSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void updateCategoryFilter(String? value) {
    categoryFilterId = value;
    notifyListeners();
  }

  void updateVaultFilter(SpacesVaultFilter value) {
    _vaultFilter = value;
    notifyListeners();
  }

  List<TaskSpace> filteredSpaces() {
    final query = searchQuery.trim().toLowerCase();
    final categoryLookup = {
      for (final category in _categories) category.id: category.name,
    };

    return _visibleSpaces(_spaces).where((space) {
      final matchesSearch =
          query.isEmpty ||
          space.name.toLowerCase().contains(query) ||
          space.description.toLowerCase().contains(query) ||
          (categoryLookup[space.categoryId]?.toLowerCase().contains(query) ??
              false);
      final matchesCategory =
          categoryFilterId == null || space.categoryId == categoryFilterId;
      final isVaultProtected = space.vaultConfig?.isEnabled == true;
      final matchesVault = switch (_vaultFilter) {
        SpacesVaultFilter.all => true,
        SpacesVaultFilter.vaultOnly => isVaultProtected,
        SpacesVaultFilter.nonVaultOnly => !isVaultProtected,
      };
      return matchesSearch && matchesCategory && matchesVault;
    }).toList();
  }

  List<TaskSpace> archivedSpaces() {
    return _spaces.where((space) => space.isArchived).toList()..sort(
      (a, b) =>
          (b.archivedAt ?? b.updatedAt).compareTo(a.archivedAt ?? a.updatedAt),
    );
  }

  List<TaskItem> archivedTasksForArchivedSpaces() {
    final archivedIds = _spaces
        .where((space) => space.isArchived)
        .map((space) => space.id)
        .toSet();
    return _tasks
        .where(
          (task) => task.spaceId != null && archivedIds.contains(task.spaceId),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<TaskSpace> saveSpace({
    String? id,
    required String name,
    required String description,
    required String categoryId,
    required int colorValue,
    VaultConfig? vaultConfig,
  }) async {
    isSaving = true;
    notifyListeners();
    final now = DateTime.now();
    final existing = id == null ? null : await _repository.getSpaceById(id);
    final space = TaskSpace(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      categoryId: categoryId,
      colorValue: colorValue,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      vaultConfig: vaultConfig,
    );

    try {
      await _repository.upsertSpace(space);
      if (existing != null && existing.categoryId != categoryId) {
        final spaceTasks = await _repository.getTasksBySpace(existing.id);
        for (final task in spaceTasks) {
          final updatedTask = task.copyWith(
            categoryId: categoryId,
            updatedAt: now,
          );
          await _repository.upsertTask(updatedTask);
          await _reminderService.syncTask(updatedTask);
        }
      }
      await load();
      return space;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteSpace(String spaceId) async {
    isSaving = true;
    notifyListeners();
    try {
      final tasks = await _repository.getTasksBySpace(spaceId);
      await _repository.deleteSpaceWithTasks(spaceId);
      for (final task in tasks) {
        await _reminderService.cancelTask(task.id);
      }
      await load();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> archiveSpace(TaskSpace space) async {
    isSaving = true;
    notifyListeners();
    final now = DateTime.now();
    try {
      await _repository.upsertSpace(
        space.copyWith(archivedAt: now, updatedAt: now),
      );
      final tasks = await _repository.getTasksBySpace(space.id);
      for (final task in tasks) {
        await _reminderService.cancelTask(task.id);
      }
      await load();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> restoreSpace(TaskSpace space) async {
    isSaving = true;
    notifyListeners();
    final now = DateTime.now();
    try {
      final restoredSpace = space.copyWith(
        clearArchivedAt: true,
        updatedAt: now,
      );
      await _repository.upsertSpace(restoredSpace);
      final tasks = await _repository.getTasksBySpace(space.id);
      for (final task in tasks) {
        if (!task.isArchived) {
          await _reminderService.syncTask(task);
        }
      }
      await load();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  List<TaskSpace> _visibleSpaces(List<TaskSpace> spaces) {
    return spaces.where((space) => !space.isArchived).toList();
  }
}

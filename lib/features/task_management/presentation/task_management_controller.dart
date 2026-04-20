import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/vault/vault_models.dart';
import '../../../core/services/task_reminder_service.dart';
import '../../spaces/domain/task_space.dart';
import '../data/task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

enum TaskStatusFilter { all, today, upcoming, overdue, completed }

enum TaskPriorityFilter { all, low, medium, high, urgent }

enum TaskVaultFilter { all, vaultOnly, nonVaultOnly }

class TaskManagementController extends ChangeNotifier {
  TaskManagementController(
    this._repository, {
    TaskReminderService? reminderService,
    Uuid? uuid,
    this.fixedSpaceId,
    this.lockedCategoryId,
  }) : _reminderService = reminderService ?? const NoopTaskReminderService(),
       _uuid = uuid ?? const Uuid();

  final TaskRepository _repository;
  final TaskReminderService _reminderService;
  final Uuid _uuid;
  final String? fixedSpaceId;
  final String? lockedCategoryId;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String searchQuery = '';
  String? categoryFilterId;
  TaskPriorityFilter _priorityFilter = TaskPriorityFilter.all;
  TaskStatusFilter _statusFilter = TaskStatusFilter.all;
  TaskVaultFilter _vaultFilter = TaskVaultFilter.all;
  List<TaskItem> _tasks = [];
  List<TaskCategory> _categories = [];
  List<TaskSpace> _spaces = [];

  List<TaskItem> get tasks => _tasks;
  List<TaskCategory> get categories => _categories;
  List<TaskSpace> get spaces => _spaces;
  TaskPriorityFilter get priorityFilter => _priorityFilter;
  TaskStatusFilter get statusFilter => _statusFilter;
  TaskVaultFilter get vaultFilter => _vaultFilter;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final tasks = await _repository.getTasks();
      final categories = await _repository.getCategories();
      final spaces = await _repository.getSpaces();
      _tasks = tasks;
      _categories = categories;
      _spaces = spaces;
    } catch (_) {
      errorMessage = 'Unable to load your tasks right now.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<TaskItem?> getTaskById(String taskId) {
    return _repository.getTaskById(taskId);
  }

  Future<TaskItem> createTask({
    required String title,
    String? description,
    required String categoryId,
    required TaskPriority priority,
    DateTime? endDate,
    int? endMinutes,
    String? spaceId,
    VaultConfig? vaultConfig,
  }) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: _uuid.v4(),
      title: title.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      spaceId: spaceId ?? fixedSpaceId,
      vaultConfig: vaultConfig,
      noteDocumentJson: buildPlainTextNoteDocumentJson(null),
      notePlainText: null,
      priority: priority,
      categoryId: lockedCategoryId ?? categoryId,
      endDate: endDate,
      endMinutes: endMinutes,
      createdAt: now,
      updatedAt: now,
    );
    await saveTask(task);
    return task;
  }

  Future<void> saveTask(TaskItem task) async {
    isSaving = true;
    notifyListeners();
    try {
      await _repository.upsertTask(task);
      await _reminderService.syncTask(task);
      await load();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteTask(String taskId) async {
    isSaving = true;
    notifyListeners();
    try {
      await _repository.deleteTask(taskId);
      await _reminderService.cancelTask(taskId);
      await load();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(TaskItem task) async {
    final now = DateTime.now();
    final nextCompleted = !task.isCompleted;
    await saveTask(
      task.copyWith(
        isCompleted: nextCompleted,
        updatedAt: now,
        completedAt: nextCompleted ? now : null,
        clearCompletedAt: !nextCompleted,
      ),
    );
  }

  void updateSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void updateCategoryFilter(String? value) {
    categoryFilterId = value;
    notifyListeners();
  }

  void updatePriorityFilter(TaskPriorityFilter value) {
    _priorityFilter = value;
    notifyListeners();
  }

  void updateStatusFilter(TaskStatusFilter value) {
    _statusFilter = value;
    notifyListeners();
  }

  void updateVaultFilter(TaskVaultFilter value) {
    _vaultFilter = value;
    notifyListeners();
  }

  TaskCategory? categoryFor(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  TaskSpace? spaceFor(String? spaceId) {
    if (spaceId == null) {
      return null;
    }
    for (final space in _spaces) {
      if (space.id == spaceId) {
        return space;
      }
    }
    return null;
  }

  List<TaskItem> filteredTasks(DateTime now) {
    final categoryLookup = {
      for (final category in _categories) category.id: category.name,
    };
    final query = searchQuery.trim().toLowerCase();
    final filtered = _tasks.where((task) {
      final noteText = taskNotePreview(task).toLowerCase();
      final descriptionText = (task.description ?? '').toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          descriptionText.contains(query) ||
          noteText.contains(query) ||
          (categoryLookup[task.categoryId]?.toLowerCase().contains(query) ??
              false);
      final matchesCategory = lockedCategoryId != null
          ? task.categoryId == lockedCategoryId
          : categoryFilterId == null || task.categoryId == categoryFilterId;
      final matchesPriority = switch (_priorityFilter) {
        TaskPriorityFilter.all => true,
        TaskPriorityFilter.low => task.priority == TaskPriority.low,
        TaskPriorityFilter.medium => task.priority == TaskPriority.medium,
        TaskPriorityFilter.high => task.priority == TaskPriority.high,
        TaskPriorityFilter.urgent => task.priority == TaskPriority.urgent,
      };
      final matchesSpace = fixedSpaceId == null || task.spaceId == fixedSpaceId;
      final matchesStatus = switch (_statusFilter) {
        TaskStatusFilter.all => true,
        TaskStatusFilter.today => _isTodayBucket(task, now),
        TaskStatusFilter.upcoming => _isUpcomingBucket(task, now),
        TaskStatusFilter.overdue =>
          !task.isCompleted && task.statusAt(now) == TaskStatus.overdue,
        TaskStatusFilter.completed => task.isCompleted,
      };
      final isVaultProtected =
          task.vaultConfig?.isEnabled == true ||
          spaceFor(task.spaceId)?.vaultConfig?.isEnabled == true;
      final matchesVault = switch (_vaultFilter) {
        TaskVaultFilter.all => true,
        TaskVaultFilter.vaultOnly => isVaultProtected,
        TaskVaultFilter.nonVaultOnly => !isVaultProtected,
      };
      return matchesSearch &&
          matchesCategory &&
          matchesPriority &&
          matchesSpace &&
          matchesStatus &&
          matchesVault;
    }).toList();

    filtered.sort((a, b) {
      final priorityDiff =
          _priorityWeight(b.priority) - _priorityWeight(a.priority);
      if (priorityDiff != 0) {
        return priorityDiff;
      }

      return b.updatedAt.compareTo(a.updatedAt);
    });

    return filtered;
  }

  static int _priorityWeight(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 1,
      TaskPriority.medium => 2,
      TaskPriority.high => 3,
      TaskPriority.urgent => 4,
    };
  }

  static bool _isTodayBucket(TaskItem task, DateTime now) {
    if (task.isCompleted || task.statusAt(now) == TaskStatus.overdue) {
      return false;
    }

    final dueAt = task.endDateTime;
    if (dueAt == null) {
      return false;
    }

    return dueAt.year == now.year &&
        dueAt.month == now.month &&
        dueAt.day == now.day;
  }

  static bool _isUpcomingBucket(TaskItem task, DateTime now) {
    if (task.isCompleted || task.statusAt(now) == TaskStatus.overdue) {
      return false;
    }

    final dueAt = task.endDateTime;
    if (dueAt == null) {
      return false;
    }

    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDate.isAfter(today);
  }
}

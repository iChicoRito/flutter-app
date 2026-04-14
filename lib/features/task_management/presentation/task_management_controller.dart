import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/task_reminder_service.dart';
import '../data/task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class TaskManagementController extends ChangeNotifier {
  TaskManagementController(
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
  TaskPriority? _priorityFilter;
  List<TaskItem> _tasks = [];
  List<TaskCategory> _categories = [];

  List<TaskItem> get tasks => _tasks;
  List<TaskCategory> get categories => _categories;
  TaskPriority? get priorityFilter => _priorityFilter;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final tasks = await _repository.getTasks();
      final categories = await _repository.getCategories();
      _tasks = tasks;
      _categories = categories;
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
    DateTime? startDate,
    int? startMinutes,
    DateTime? endDate,
    int? endMinutes,
  }) async {
    final now = DateTime.now();
    final task = TaskItem(
      id: _uuid.v4(),
      title: title.trim(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      noteDocumentJson: buildPlainTextNoteDocumentJson(null),
      notePlainText: null,
      priority: priority,
      categoryId: categoryId,
      startDate: startDate,
      startMinutes: startMinutes,
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

  void updatePriorityFilter(TaskPriority? value) {
    _priorityFilter = value;
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
          (categoryLookup[task.categoryId]?.toLowerCase().contains(query) ?? false);
      final matchesCategory =
          categoryFilterId == null || task.categoryId == categoryFilterId;
      final matchesPriority =
          _priorityFilter == null || task.priority == _priorityFilter;
      return matchesSearch && matchesCategory && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      final priorityDiff = _priorityWeight(b.priority) - _priorityWeight(a.priority);
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
}

import 'package:flutter/foundation.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

enum TaskListStatusFilter { all, pending, completed, overdue }

enum TaskSortOption { createdNewest, endDate, priority }

class TaskManagementController extends ChangeNotifier {
  TaskManagementController(this._repository);

  final TaskRepository _repository;

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

  Future<void> saveTask(TaskItem task) async {
    isSaving = true;
    notifyListeners();
    await _repository.upsertTask(task);
    await load();
    isSaving = false;
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    isSaving = true;
    notifyListeners();
    await _repository.deleteTask(taskId);
    await load();
    isSaving = false;
    notifyListeners();
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

  List<TaskItem> filteredTasks(DateTime now) {
    final categoryLookup = {
      for (final category in _categories) category.id: category.name,
    };
    final query = searchQuery.trim().toLowerCase();
    final filtered = _tasks.where((task) {
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          (task.description?.toLowerCase().contains(query) ?? false) ||
          (categoryLookup[task.categoryId]?.toLowerCase().contains(query) ??
              false);
      final matchesCategory =
          categoryFilterId == null || task.categoryId == categoryFilterId;
      final matchesPriority =
          _priorityFilter == null || task.priority == _priorityFilter;
      return matchesSearch && matchesCategory && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      final priorityDiff =
          _priorityWeight(b.priority) - _priorityWeight(a.priority);
      if (priorityDiff != 0) {
        return priorityDiff;
      }

      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  TaskCategory? categoryFor(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    return null;
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

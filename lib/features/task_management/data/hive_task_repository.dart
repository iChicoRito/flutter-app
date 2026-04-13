import 'package:hive_flutter/hive_flutter.dart';

import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_seed_data.dart';

class HiveTaskRepository implements TaskRepository {
  HiveTaskRepository._({
    required Box<TaskItem> taskBox,
    required Box<TaskCategory> categoryBox,
  }) : _taskBox = taskBox,
       _categoryBox = categoryBox;

  static const _taskBoxName = 'tasksBox';
  static const _categoryBoxName = 'categoriesBox';
  static bool _adaptersRegistered = false;

  final Box<TaskItem> _taskBox;
  final Box<TaskCategory> _categoryBox;

  static Future<HiveTaskRepository> initialize() async {
    await Hive.initFlutter();

    if (!_adaptersRegistered) {
      Hive
        ..registerAdapter(TaskItemAdapter())
        ..registerAdapter(TaskCategoryAdapter());
      _adaptersRegistered = true;
    }

    final taskBox = await Hive.openBox<TaskItem>(_taskBoxName);
    final categoryBox = await Hive.openBox<TaskCategory>(_categoryBoxName);
    final repository = HiveTaskRepository._(
      taskBox: taskBox,
      categoryBox: categoryBox,
    );
    await repository.seedDefaultCategoriesIfNeeded();
    return repository;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _taskBox.delete(taskId);
  }

  @override
  Future<List<TaskCategory>> getCategories() async {
    final categories = _categoryBox.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return categories;
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks = _taskBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  Future<void> seedDefaultCategoriesIfNeeded() async {
    if (_categoryBox.isNotEmpty) {
      return;
    }

    for (final category in buildDefaultTaskCategories()) {
      await _categoryBox.put(category.id, category);
    }
  }

  @override
  Future<void> upsertCategory(TaskCategory category) async {
    await _categoryBox.put(category.id, category);
  }

  @override
  Future<void> upsertTask(TaskItem task) async {
    await _taskBox.put(task.id, task);
  }
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({
    List<TaskItem>? tasks,
    List<TaskCategory>? categories,
    bool seedDefaults = true,
  }) : _tasks = [...?tasks],
       _categories = categories != null
           ? [...categories]
           : (seedDefaults ? buildDefaultTaskCategories() : <TaskCategory>[]);

  final List<TaskItem> _tasks;
  final List<TaskCategory> _categories;

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<TaskCategory>> getCategories() async {
    final categories = [..._categories]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return categories;
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks = [..._tasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  @override
  Future<void> upsertCategory(TaskCategory category) async {
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index >= 0) {
      _categories[index] = category;
      return;
    }

    _categories.add(category);
  }

  @override
  Future<void> upsertTask(TaskItem task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
      return;
    }

    _tasks.add(task);
  }
}

class TaskItemAdapter extends TypeAdapter<TaskItem> {
  @override
  final int typeId = 0;

  @override
  TaskItem read(BinaryReader reader) {
    final values = <dynamic>[];
    while (reader.availableBytes > 0) {
      values.add(reader.read());
    }

    final legacyDueDate = values.length > 3 ? values[3] as DateTime? : null;
    final legacyDueMinutes = values.length > 4 ? values[4] as int? : null;
    final completedAt = values.length > 10 ? values[10] as DateTime? : null;
    final startDate = values.length > 11 ? values[11] as DateTime? : null;
    final startMinutes = values.length > 12 ? values[12] as int? : null;
    final endDate = values.length > 13
        ? values[13] as DateTime?
        : legacyDueDate;
    final endMinutes = values.length > 14
        ? values[14] as int?
        : legacyDueMinutes;

    return TaskItem(
      id: values[0] as String,
      title: values[1] as String,
      description: values[2] as String?,
      startDate: startDate,
      startMinutes: startMinutes,
      endDate: endDate,
      endMinutes: endMinutes,
      priority: TaskPriority.values[values[5] as int],
      categoryId: values[6] as String,
      isCompleted: values[7] as bool,
      createdAt: values[8] as DateTime,
      updatedAt: values[9] as DateTime,
      completedAt: completedAt,
    );
  }

  @override
  void write(BinaryWriter writer, TaskItem obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..write(obj.description)
      ..write(null)
      ..write(null)
      ..writeInt(obj.priority.index)
      ..writeString(obj.categoryId)
      ..writeBool(obj.isCompleted)
      ..write(obj.createdAt)
      ..write(obj.updatedAt)
      ..write(obj.completedAt)
      ..write(obj.startDate)
      ..write(obj.startMinutes)
      ..write(obj.endDate)
      ..write(obj.endMinutes);
  }
}

class TaskCategoryAdapter extends TypeAdapter<TaskCategory> {
  @override
  final int typeId = 1;

  @override
  TaskCategory read(BinaryReader reader) {
    return TaskCategory(
      id: reader.readString(),
      name: reader.readString(),
      iconKey: reader.readString(),
      colorValue: reader.readInt(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, TaskCategory obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.iconKey)
      ..writeInt(obj.colorValue)
      ..write(obj.createdAt);
  }
}

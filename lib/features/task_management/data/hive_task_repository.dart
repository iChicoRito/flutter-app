import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

import 'task_note_codec.dart';
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

    final taskBox = await _openTaskBoxWithRecovery();
    final categoryBox = await Hive.openBox<TaskCategory>(_categoryBoxName);
    final repository = HiveTaskRepository._(
      taskBox: taskBox,
      categoryBox: categoryBox,
    );
    await repository.seedDefaultCategoriesIfNeeded();
    await repository.migrateLegacyTasksIfNeeded();
    return repository;
  }

  static Future<Box<TaskItem>> _openTaskBoxWithRecovery() async {
    try {
      return await Hive.openBox<TaskItem>(_taskBoxName);
    } on HiveError catch (error) {
      final isLegacyTypeFailure = error.toString().contains('unknown typeId');
      if (!isLegacyTypeFailure) {
        rethrow;
      }

      // Recover from incompatible legacy task payloads so the app can boot.
      try {
        await Hive.deleteBoxFromDisk(_taskBoxName);
      } on PathNotFoundException {
        // Hive may already have removed the main box file before attempting to
        // delete a non-existent lock file on some Android environments.
      } on FileSystemException catch (error) {
        final isMissingLockFile =
            error.path?.toLowerCase().endsWith('tasksbox.lock') ?? false;
        if (!isMissingLockFile) {
          rethrow;
        }
      }
      return Hive.openBox<TaskItem>(_taskBoxName);
    }
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
  Future<TaskItem?> getTaskById(String taskId) async {
    final task = _taskBox.get(taskId);
    if (task == null) {
      return null;
    }

    return normalizeTaskNoteFields(task);
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks = _taskBox.values.map(normalizeTaskNoteFields).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  Future<void> migrateLegacyTasksIfNeeded() async {
    for (final task in _taskBox.values) {
      final normalized = normalizeTaskNoteFields(task);
      if (normalized != task) {
        await _taskBox.put(task.id, normalized);
      }
    }
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
    await _taskBox.put(task.id, normalizeTaskNoteFields(task));
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
  Future<TaskItem?> getTaskById(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return null;
    }

    final normalized = normalizeTaskNoteFields(_tasks[index]);
    _tasks[index] = normalized;
    return normalized;
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks = _tasks.map(normalizeTaskNoteFields).toList()
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
    final normalizedTask = normalizeTaskNoteFields(task);
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) {
      _tasks[index] = normalizedTask;
      return;
    }

    _tasks.add(normalizedTask);
  }
}

class TaskItemAdapter extends TypeAdapter<TaskItem> {
  @override
  final int typeId = 0;

  @override
  TaskItem read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final description = reader.read() as String?;
    final legacyDueDate = reader.availableBytes > 0
        ? _readDateValue(reader.read(), dateOnly: true)
        : null;
    final legacyDueMinutes = reader.availableBytes > 0 ? reader.read() as int? : null;
    final priorityIndex = reader.readInt();
    final categoryId = reader.readString();
    final isCompleted = reader.readBool();
    final createdAt = _readDateValue(reader.read()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final updatedAt = _readDateValue(reader.read()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final completedAt = reader.availableBytes > 0
        ? _readDateValue(reader.read())
        : null;
    final startDate = reader.availableBytes > 0
        ? _readDateValue(reader.read(), dateOnly: true)
        : null;
    final startMinutes = reader.availableBytes > 0 ? reader.read() as int? : null;
    final endDate = reader.availableBytes > 0
        ? _readDateValue(reader.read(), dateOnly: true)
        : legacyDueDate;
    final endMinutes = reader.availableBytes > 0
        ? reader.read() as int?
        : legacyDueMinutes;
    final noteDocumentJson = reader.availableBytes > 0 ? reader.read() as String? : null;
    final notePlainText = reader.availableBytes > 0 ? reader.read() as String? : null;

    return TaskItem(
      id: id,
      title: title,
      description: description,
      noteDocumentJson: noteDocumentJson,
      notePlainText: notePlainText,
      startDate: startDate,
      startMinutes: startMinutes,
      endDate: endDate,
      endMinutes: endMinutes,
      priority: TaskPriority.values[priorityIndex],
      categoryId: categoryId,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
      ..write(_writeDateValue(obj.createdAt))
      ..write(_writeDateValue(obj.updatedAt))
      ..write(_writeDateValue(obj.completedAt))
      ..write(_writeDateValue(obj.startDate, dateOnly: true))
      ..write(obj.startMinutes)
      ..write(_writeDateValue(obj.endDate, dateOnly: true))
      ..write(obj.endMinutes)
      ..write(obj.noteDocumentJson)
      ..write(obj.notePlainText);
  }

  static DateTime? _readDateValue(dynamic value, {bool dateOnly = false}) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return dateOnly
          ? DateTime(value.year, value.month, value.day)
          : value;
    }
    if (value is int) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(value);
      return dateOnly
          ? DateTime(dateTime.year, dateTime.month, dateTime.day)
          : dateTime;
    }
    return null;
  }

  static int? _writeDateValue(DateTime? value, {bool dateOnly = false}) {
    if (value == null) {
      return null;
    }
    final normalized = dateOnly
        ? DateTime(value.year, value.month, value.day)
        : value;
    return normalized.millisecondsSinceEpoch;
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
      createdAt: TaskItemAdapter._readDateValue(reader.read()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  void write(BinaryWriter writer, TaskCategory obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.iconKey)
      ..writeInt(obj.colorValue)
      ..write(TaskItemAdapter._writeDateValue(obj.createdAt));
  }
}

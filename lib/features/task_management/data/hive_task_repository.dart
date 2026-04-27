import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/vault/vault_models.dart';
import '../../spaces/domain/task_space.dart';
import 'task_note_codec.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';
import 'task_seed_data.dart';

class HiveTaskRepository implements TaskRepository {
  HiveTaskRepository._({
    required Box<TaskItem> taskBox,
    required Box<TaskCategory> categoryBox,
    required Box<TaskSpace> spaceBox,
  }) : _taskBox = taskBox,
       _categoryBox = categoryBox,
       _spaceBox = spaceBox;

  static const _taskBoxName = 'tasksBox';
  static const _categoryBoxName = 'categoriesBox';
  static const _spaceBoxName = 'spacesBox';
  static bool _adaptersRegistered = false;

  final Box<TaskItem> _taskBox;
  final Box<TaskCategory> _categoryBox;
  final Box<TaskSpace> _spaceBox;

  static Future<HiveTaskRepository> initialize() async {
    await Hive.initFlutter();

    if (!_adaptersRegistered) {
      Hive
        ..registerAdapter(TaskItemAdapter())
        ..registerAdapter(TaskCategoryAdapter())
        ..registerAdapter(TaskSpaceAdapter())
        ..registerAdapter(VaultConfigAdapter())
        ..registerAdapter(VaultMethodAdapter());
      _adaptersRegistered = true;
    }

    final taskBox = await _openTaskBoxWithRecovery();
    final categoryBox = await Hive.openBox<TaskCategory>(_categoryBoxName);
    final spaceBox = await Hive.openBox<TaskSpace>(_spaceBoxName);
    final repository = HiveTaskRepository._(
      taskBox: taskBox,
      categoryBox: categoryBox,
      spaceBox: spaceBox,
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
  Future<void> deleteSpace(String spaceId) async {
    await _spaceBox.delete(spaceId);
  }

  @override
  Future<void> deleteSpaceWithTasks(String spaceId) async {
    final taskIds = _taskBox.values
        .where((task) => task.spaceId == spaceId)
        .map((task) => task.id)
        .toList();
    if (taskIds.isNotEmpty) {
      await _taskBox.deleteAll(taskIds);
    }
    await deleteSpace(spaceId);
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

    return normalizeTaskNoteFields(task).normalizedSingleSchedule();
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks =
        _taskBox.values
            .map(
              (task) =>
                  normalizeTaskNoteFields(task).normalizedSingleSchedule(),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  @override
  Future<List<TaskItem>> getTasksBySpace(String spaceId) async {
    final tasks = (await getTasks())
        .where((task) => task.spaceId == spaceId)
        .toList();
    return tasks;
  }

  @override
  Future<TaskSpace?> getSpaceById(String spaceId) async {
    return _spaceBox.get(spaceId);
  }

  @override
  Future<List<TaskSpace>> getSpaces() async {
    final spaces = _spaceBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return spaces;
  }

  Future<void> migrateLegacyTasksIfNeeded() async {
    for (final task in _taskBox.values) {
      final normalized = normalizeTaskNoteFields(
        task,
      ).normalizedSingleSchedule();
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
  Future<void> upsertSpace(TaskSpace space) async {
    await _spaceBox.put(space.id, space);
  }

  @override
  Future<void> upsertTask(TaskItem task) async {
    await _taskBox.put(
      task.id,
      normalizeTaskNoteFields(task).normalizedSingleSchedule(),
    );
  }
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({
    List<TaskItem>? tasks,
    List<TaskCategory>? categories,
    List<TaskSpace>? spaces,
    bool seedDefaults = true,
  }) : _tasks = [...?tasks],
       _categories = categories != null
           ? [...categories]
           : (seedDefaults ? buildDefaultTaskCategories() : <TaskCategory>[]),
       _spaces = [...?spaces];

  final List<TaskItem> _tasks;
  final List<TaskCategory> _categories;
  final List<TaskSpace> _spaces;

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<void> deleteSpace(String spaceId) async {
    _spaces.removeWhere((space) => space.id == spaceId);
  }

  @override
  Future<void> deleteSpaceWithTasks(String spaceId) async {
    _tasks.removeWhere((task) => task.spaceId == spaceId);
    await deleteSpace(spaceId);
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

    final normalized = normalizeTaskNoteFields(
      _tasks[index],
    ).normalizedSingleSchedule();
    _tasks[index] = normalized;
    return normalized;
  }

  @override
  Future<TaskSpace?> getSpaceById(String spaceId) async {
    final index = _spaces.indexWhere((space) => space.id == spaceId);
    if (index < 0) {
      return null;
    }
    return _spaces[index];
  }

  @override
  Future<List<TaskSpace>> getSpaces() async {
    final spaces = [..._spaces]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return spaces;
  }

  @override
  Future<List<TaskItem>> getTasks() async {
    final tasks =
        _tasks
            .map(
              (task) =>
                  normalizeTaskNoteFields(task).normalizedSingleSchedule(),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  @override
  Future<List<TaskItem>> getTasksBySpace(String spaceId) async {
    final tasks = (await getTasks())
        .where((task) => task.spaceId == spaceId)
        .toList();
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
  Future<void> upsertSpace(TaskSpace space) async {
    final index = _spaces.indexWhere((item) => item.id == space.id);
    if (index >= 0) {
      _spaces[index] = space;
      return;
    }
    _spaces.add(space);
  }

  @override
  Future<void> upsertTask(TaskItem task) async {
    final normalizedTask = normalizeTaskNoteFields(
      task,
    ).normalizedSingleSchedule();
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
    final legacyDueMinutes = reader.availableBytes > 0
        ? reader.read() as int?
        : null;
    final priorityIndex = reader.readInt();
    final categoryId = reader.readString();
    final isCompleted = reader.readBool();
    final createdAt =
        _readDateValue(reader.read()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final updatedAt =
        _readDateValue(reader.read()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final completedAt = reader.availableBytes > 0
        ? _readDateValue(reader.read())
        : null;
    final startDate = reader.availableBytes > 0
        ? _readDateValue(reader.read(), dateOnly: true)
        : null;
    final startMinutes = reader.availableBytes > 0
        ? reader.read() as int?
        : null;
    final endDate = reader.availableBytes > 0
        ? _readDateValue(reader.read(), dateOnly: true)
        : legacyDueDate;
    final endMinutes = reader.availableBytes > 0
        ? reader.read() as int?
        : legacyDueMinutes;
    final noteDocumentJson = reader.availableBytes > 0
        ? reader.read() as String?
        : null;
    final notePlainText = reader.availableBytes > 0
        ? reader.read() as String?
        : null;
    final spaceId = reader.availableBytes > 0 ? reader.read() as String? : null;
    final vaultConfig = reader.availableBytes > 0
        ? reader.read() as VaultConfig?
        : null;
    final archivedAt = reader.availableBytes > 0
        ? TaskItemAdapter._readDateValue(reader.read())
        : null;
    final standaloneCategoryId = reader.availableBytes > 0
        ? reader.read() as String?
        : null;

    return TaskItem(
      id: id,
      title: title,
      description: description,
      spaceId: spaceId,
      standaloneCategoryId: standaloneCategoryId,
      vaultConfig: vaultConfig,
      archivedAt: archivedAt,
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
    ).normalizedSingleSchedule();
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
      ..write(null)
      ..write(null)
      ..write(_writeDateValue(obj.endDate, dateOnly: true))
      ..write(obj.endMinutes)
      ..write(obj.noteDocumentJson)
      ..write(obj.notePlainText)
      ..write(obj.spaceId)
      ..write(obj.vaultConfig)
      ..write(_writeDateValue(obj.archivedAt))
      ..write(obj.standaloneCategoryId);
  }

  static DateTime? _readDateValue(dynamic value, {bool dateOnly = false}) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return dateOnly ? DateTime(value.year, value.month, value.day) : value;
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
      createdAt:
          TaskItemAdapter._readDateValue(reader.read()) ??
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

class TaskSpaceAdapter extends TypeAdapter<TaskSpace> {
  @override
  final int typeId = 2;

  @override
  TaskSpace read(BinaryReader reader) {
    return TaskSpace(
      id: reader.readString(),
      name: reader.readString(),
      description: reader.readString(),
      categoryId: reader.readString(),
      colorValue: reader.readInt(),
      createdAt:
          TaskItemAdapter._readDateValue(reader.read()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          TaskItemAdapter._readDateValue(reader.read()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      vaultConfig: reader.availableBytes > 0
          ? reader.read() as VaultConfig?
          : null,
      archivedAt: reader.availableBytes > 0
          ? TaskItemAdapter._readDateValue(reader.read())
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, TaskSpace obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.description)
      ..writeString(obj.categoryId)
      ..writeInt(obj.colorValue)
      ..write(TaskItemAdapter._writeDateValue(obj.createdAt))
      ..write(TaskItemAdapter._writeDateValue(obj.updatedAt))
      ..write(obj.vaultConfig)
      ..write(TaskItemAdapter._writeDateValue(obj.archivedAt));
  }
}

class VaultMethodAdapter extends TypeAdapter<VaultMethod> {
  @override
  final int typeId = 3;

  @override
  VaultMethod read(BinaryReader reader) {
    return VaultMethod.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, VaultMethod obj) {
    writer.writeInt(obj.index);
  }
}

class VaultConfigAdapter extends TypeAdapter<VaultConfig> {
  @override
  final int typeId = 4;

  @override
  VaultConfig read(BinaryReader reader) {
    return VaultConfig(
      isEnabled: reader.readBool(),
      method: reader.read() as VaultMethod,
      secretKeyRef: reader.read() as String?,
      recoveryKeyRef: reader.availableBytes > 0
          ? reader.read() as String?
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, VaultConfig obj) {
    writer
      ..writeBool(obj.isEnabled)
      ..write(obj.method)
      ..write(obj.secretKeyRef)
      ..write(obj.recoveryKeyRef);
  }
}

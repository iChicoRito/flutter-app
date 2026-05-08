import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/vault/vault_models.dart';
import '../../spaces/domain/task_space.dart';
import '../domain/task_attachment.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class AppDataExportSelection {
  const AppDataExportSelection({
    required this.includeTasks,
    required this.includeSpaces,
  });

  final bool includeTasks;
  final bool includeSpaces;

  bool get isEmpty => !includeTasks && !includeSpaces;
}

class AppDataImportResult {
  const AppDataImportResult({
    required this.taskCount,
    required this.spaceCount,
  });

  final int taskCount;
  final int spaceCount;
}

const int _appDataSchemaVersion = 1;
const int _maxImportFileSizeBytes = 25 * 1024 * 1024;

Map<String, dynamic> buildAppDataExportPayload({
  required List<TaskItem> tasks,
  required List<TaskSpace> spaces,
  required AppDataExportSelection selection,
  DateTime Function()? clock,
}) {
  final now = (clock ?? DateTime.now)();
  final payload = <String, dynamic>{
    'schemaVersion': _appDataSchemaVersion,
    'exportedAt': now.toIso8601String(),
  };

  if (selection.includeTasks) {
    payload['tasks'] = tasks.map(_taskToJson).toList();
  }
  if (selection.includeSpaces) {
    payload['spaces'] = spaces.map(_spaceToJson).toList();
  }

  return payload;
}

String buildAppDataExportJson({
  required List<TaskItem> tasks,
  required List<TaskSpace> spaces,
  required AppDataExportSelection selection,
  DateTime Function()? clock,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    buildAppDataExportPayload(
      tasks: tasks,
      spaces: spaces,
      selection: selection,
      clock: clock,
    ),
  );
}

Future<File> createAppDataExportFile({
  required List<TaskItem> tasks,
  required List<TaskSpace> spaces,
  required AppDataExportSelection selection,
  DateTime Function()? clock,
}) async {
  final directory = await getTemporaryDirectory();
  final exportedAt = (clock ?? DateTime.now)();
  final fileName =
      'remindly-data-${exportedAt.year.toString().padLeft(4, '0')}-'
      '${exportedAt.month.toString().padLeft(2, '0')}-'
      '${exportedAt.day.toString().padLeft(2, '0')}.json';
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(
    buildAppDataExportJson(
      tasks: tasks,
      spaces: spaces,
      selection: selection,
      clock: clock,
    ),
  );
  return file;
}

Future<void> shareAppDataExport({
  required TaskRepository repository,
  required AppDataExportSelection selection,
  DateTime Function()? clock,
}) async {
  if (selection.isEmpty) {
    throw StateError('Select at least one data type to export.');
  }

  final tasks = selection.includeTasks
      ? await repository.getTasks()
      : const <TaskItem>[];
  final spaces = selection.includeSpaces
      ? await repository.getSpaces()
      : const <TaskSpace>[];
  final file = await createAppDataExportFile(
    tasks: tasks,
    spaces: spaces,
    selection: selection,
    clock: clock,
  );

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      title: 'RemindLy data export',
      text: 'RemindLy data export',
      fileNameOverrides: [file.uri.pathSegments.last],
    ),
  );
}

Future<AppDataImportResult> importAppDataFromDevice(
  TaskRepository repository,
) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) {
    throw StateError('No file selected.');
  }

  final file = result.files.single;
  if (file.size > _maxImportFileSizeBytes) {
    throw FormatException('The selected file is larger than 25 MB.');
  }

  return importAppDataFromPlatformFile(file, repository);
}

Future<AppDataImportResult> importAppDataFromPlatformFile(
  PlatformFile file,
  TaskRepository repository,
) async {
  final content = await _readPlatformFile(file);
  return importAppDataFromJson(content, repository);
}

Future<AppDataImportResult> importAppDataFromJson(
  String content,
  TaskRepository repository,
) async {
  final decoded = jsonDecode(content);
  if (decoded is! Map) {
    throw const FormatException('Invalid app data file.');
  }

  final root = Map<String, dynamic>.from(decoded);
  final importedSpaces = _decodeSpaces(root);
  final importedTasks = _decodeTasks(root);

  for (final space in importedSpaces.values) {
    await repository.upsertSpace(space);
  }
  for (final task in importedTasks.values) {
    await repository.upsertTask(task);
  }

  return AppDataImportResult(
    taskCount: importedTasks.length,
    spaceCount: importedSpaces.length,
  );
}

Future<String> _readPlatformFile(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes != null) {
    return utf8.decode(bytes);
  }

  final path = file.path;
  if (path == null || path.isEmpty) {
    throw const FormatException('Unable to read the selected file.');
  }

  return File(path).readAsString();
}

Map<String, TaskItem> _decodeTasks(Map<String, dynamic> root) {
  final rawTasks = root['tasks'] ?? root['task'];
  if (rawTasks == null) {
    return <String, TaskItem>{};
  }

  final items = _readRecordList(rawTasks);
  final tasks = <String, TaskItem>{};
  for (final item in items) {
    final task = _taskFromJson(item);
    tasks[task.id] = task;
  }
  return tasks;
}

Map<String, TaskSpace> _decodeSpaces(Map<String, dynamic> root) {
  final rawSpaces = root['spaces'] ?? root['space'];
  if (rawSpaces == null) {
    return <String, TaskSpace>{};
  }

  final items = _readRecordList(rawSpaces);
  final spaces = <String, TaskSpace>{};
  for (final item in items) {
    final space = _spaceFromJson(item);
    spaces[space.id] = space;
  }
  return spaces;
}

List<Map<String, dynamic>> _readRecordList(dynamic value) {
  if (value is! List) {
    throw const FormatException('Expected a list in the app data file.');
  }

  return value.map((record) {
    if (record is! Map) {
      throw const FormatException('Expected a JSON object in the app data file.');
    }
    return Map<String, dynamic>.from(record);
  }).toList();
}

Map<String, dynamic> _taskToJson(TaskItem task) {
  return <String, dynamic>{
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'spaceId': task.spaceId,
    'standaloneCategoryId': task.standaloneCategoryId,
    'vaultConfig': _vaultConfigToJson(task.vaultConfig),
    'archivedAt': task.archivedAt?.toIso8601String(),
    'noteDocumentJson': task.noteDocumentJson,
    'notePlainText': task.notePlainText,
    'startDate': task.startDate?.toIso8601String(),
    'startMinutes': task.startMinutes,
    'endDate': task.endDate?.toIso8601String(),
    'endMinutes': task.endMinutes,
    'priority': task.priority.name,
    'categoryId': task.categoryId,
    'isCompleted': task.isCompleted,
    'createdAt': task.createdAt.toIso8601String(),
    'updatedAt': task.updatedAt.toIso8601String(),
    'completedAt': task.completedAt?.toIso8601String(),
    'isPinned': task.isPinned,
    'sortOrder': task.sortOrder,
    'attachments': task.attachments.map(_attachmentToJson).toList(),
  };
}

Map<String, dynamic> _spaceToJson(TaskSpace space) {
  return <String, dynamic>{
    'id': space.id,
    'name': space.name,
    'description': space.description,
    'categoryId': space.categoryId,
    'colorValue': space.colorValue,
    'createdAt': space.createdAt.toIso8601String(),
    'updatedAt': space.updatedAt.toIso8601String(),
    'vaultConfig': _vaultConfigToJson(space.vaultConfig),
    'archivedAt': space.archivedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _attachmentToJson(TaskAttachment attachment) {
  return <String, dynamic>{
    'id': attachment.id,
    'kind': attachment.kind.name,
    'displayName': attachment.displayName,
    'mimeType': attachment.mimeType,
    'localPath': attachment.localPath,
    'sizeBytes': attachment.sizeBytes,
    'createdAt': attachment.createdAt.toIso8601String(),
  };
}

TaskItem _taskFromJson(Map<String, dynamic> json) {
  final id = _readString(json['id'], field: 'task.id');
  final title = _readString(json['title'], field: 'task.title');
  final categoryId = _readString(json['categoryId'], field: 'task.categoryId');

  return TaskItem(
    id: id,
    title: title,
    description: _readNullableString(json['description']),
    spaceId: _readNullableString(json['spaceId']),
    standaloneCategoryId: _readNullableString(json['standaloneCategoryId']),
    vaultConfig: _vaultConfigFromJson(json['vaultConfig']),
    archivedAt: _readDateTime(json['archivedAt']),
    noteDocumentJson: _readNullableString(json['noteDocumentJson']),
    notePlainText: _readNullableString(json['notePlainText']),
    startDate: _readDateOnly(json['startDate']),
    startMinutes: _readInt(json['startMinutes']),
    endDate: _readDateOnly(json['endDate']),
    endMinutes: _readInt(json['endMinutes']),
    priority: _readTaskPriority(json['priority']),
    categoryId: categoryId,
    isCompleted: _readBool(json['isCompleted']),
    createdAt:
        _readDateTime(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        _readDateTime(json['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    completedAt: _readDateTime(json['completedAt']),
    isPinned: _readBool(json['isPinned']),
    sortOrder: _readDouble(json['sortOrder']) ?? 0,
    attachments: _readAttachments(json['attachments']),
  ).normalizedSingleSchedule();
}

TaskSpace _spaceFromJson(Map<String, dynamic> json) {
  final id = _readString(json['id'], field: 'space.id');
  final name = _readString(json['name'], field: 'space.name');
  final categoryId = _readString(json['categoryId'], field: 'space.categoryId');

  return TaskSpace(
    id: id,
    name: name,
    description: _readNullableString(json['description']) ?? '',
    categoryId: categoryId,
    colorValue: _readInt(json['colorValue']) ?? 0,
    createdAt:
        _readDateTime(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        _readDateTime(json['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    vaultConfig: _vaultConfigFromJson(json['vaultConfig']),
    archivedAt: _readDateTime(json['archivedAt']),
  );
}

List<TaskAttachment> _readAttachments(dynamic value) {
  if (value == null) {
    return const <TaskAttachment>[];
  }
  if (value is! List) {
    throw const FormatException('Expected a list of attachments.');
  }

  return value.map((record) {
    if (record is! Map) {
      throw const FormatException('Expected an attachment object.');
    }
    final json = Map<String, dynamic>.from(record);
    return TaskAttachment(
      id: _readString(json['id'], field: 'attachment.id'),
      kind: _readAttachmentKind(json['kind']),
      displayName: _readString(
        json['displayName'],
        field: 'attachment.displayName',
      ),
      mimeType: _readString(json['mimeType'], field: 'attachment.mimeType'),
      localPath: _readString(json['localPath'], field: 'attachment.localPath'),
      sizeBytes: _readInt(json['sizeBytes']) ?? 0,
      createdAt:
          _readDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }).toList();
}

VaultConfig? _vaultConfigFromJson(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw const FormatException('Expected a vault config object.');
  }

  final json = Map<String, dynamic>.from(value);
  final methodName = _readNullableString(json['method']);
  final method = _enumByName(
    VaultMethod.values,
    methodName,
    VaultMethod.password,
    (value) => value.name,
  );

  return VaultConfig(
    isEnabled: _readBool(json['isEnabled']),
    method: method,
    secretKeyRef: _readNullableString(json['secretKeyRef']),
    recoveryKeyRef: _readNullableString(json['recoveryKeyRef']),
  );
}

Map<String, dynamic>? _vaultConfigToJson(VaultConfig? config) {
  if (config == null) {
    return null;
  }
  return <String, dynamic>{
    'isEnabled': config.isEnabled,
    'method': config.method.name,
    'secretKeyRef': config.secretKeyRef,
    'recoveryKeyRef': config.recoveryKeyRef,
  };
}

TaskPriority _readTaskPriority(dynamic value) {
  return _enumByName(
    TaskPriority.values,
    _readNullableString(value),
    TaskPriority.medium,
    (value) => value.name,
  );
}

TaskAttachmentKind _readAttachmentKind(dynamic value) {
  return _enumByName(
    TaskAttachmentKind.values,
    _readNullableString(value),
    TaskAttachmentKind.file,
    (value) => value.name,
  );
}

String _readString(dynamic value, {required String field}) {
  final text = _readNullableString(value);
  if (text == null || text.isEmpty) {
    throw FormatException('Missing required field: $field');
  }
  return text;
}

String? _readNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString();
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  return false;
}

int? _readInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double? _readDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

DateTime? _readDateTime(dynamic value) {
  final text = _readNullableString(value);
  if (text != null) {
    return DateTime.tryParse(text);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

DateTime? _readDateOnly(dynamic value) {
  final dateTime = _readDateTime(value);
  if (dateTime == null) {
    return null;
  }
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String _coerceEnumName(String value, String fallback) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized.replaceAll(RegExp(r'[\s_\-]+'), '').toLowerCase();
}

T _enumByName<T>(
  Iterable<T> values,
  String? raw,
  T fallback,
  String Function(T value) nameOf,
) {
  final normalizedRaw = raw == null ? null : _coerceEnumName(raw, '');
  if (normalizedRaw == null || normalizedRaw.isEmpty) {
    return fallback;
  }

  for (final value in values) {
    final normalizedValue = _coerceEnumName(nameOf(value), '');
    if (normalizedValue == normalizedRaw) {
      return value;
    }
  }

  return fallback;
}

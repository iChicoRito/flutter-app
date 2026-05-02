import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/task_attachment.dart';
import '../domain/task_item.dart';

String buildTaskExportJson(TaskItem task) {
  final payload = <String, dynamic>{
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'task': <String, dynamic>{
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'spaceId': task.spaceId,
      'standaloneCategoryId': task.standaloneCategoryId,
      'categoryId': task.categoryId,
      'priority': task.priority.name,
      'isCompleted': task.isCompleted,
      'completedAt': task.completedAt?.toIso8601String(),
      'archivedAt': task.archivedAt?.toIso8601String(),
      'isPinned': task.isPinned,
      'sortOrder': task.sortOrder,
      'startDate': task.startDate?.toIso8601String(),
      'startMinutes': task.startMinutes,
      'endDate': task.endDate?.toIso8601String(),
      'endMinutes': task.endMinutes,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'noteDocumentJson': task.noteDocumentJson,
      'notePlainText': task.notePlainText,
      'attachments': task.attachments.map(_attachmentToJson).toList(),
    },
  };

  return const JsonEncoder.withIndent('  ').convert(payload);
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

Future<File> createTaskExportFile(TaskItem task) async {
  final directory = await getTemporaryDirectory();
  final sanitizedTitle = task.title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final baseName = sanitizedTitle.isEmpty ? 'task' : sanitizedTitle;
  final file = File(
    '${directory.path}${Platform.pathSeparator}$baseName-${task.id}.json',
  );
  await file.writeAsString(buildTaskExportJson(task));
  return file;
}

Future<void> shareTaskExport(TaskItem task) async {
  final file = await createTaskExportFile(task);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      title: '${task.title} export',
      text: 'Task export for ${task.title}',
      fileNameOverrides: [file.uri.pathSegments.last],
    ),
  );
}

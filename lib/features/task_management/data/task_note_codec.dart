import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../domain/task_item.dart';

String buildPlainTextNoteDocumentJson(String? text) {
  final normalized = (text ?? '').replaceAll('\r\n', '\n');
  final documentText = normalized.endsWith('\n') ? normalized : '$normalized\n';
  return jsonEncode([
    {'insert': documentText},
  ]);
}

String normalizeNoteDocumentJson(String? documentJson, {String? fallbackText}) {
  final value = documentJson?.trim();
  if (value != null && value.isNotEmpty) {
    try {
      final document = quill.Document.fromJson(
        List<Map<String, dynamic>>.from(jsonDecode(value) as List),
      );
      return jsonEncode(document.toDelta().toJson());
    } catch (_) {
      // Fall through to the plain-text fallback so older or malformed content
      // still opens in the editor.
    }
  }

  return buildPlainTextNoteDocumentJson(fallbackText);
}

String? extractPlainTextFromNoteDocumentJson(
  String? documentJson, {
  String? fallbackText,
}) {
  final value = documentJson?.trim();
  if (value != null && value.isNotEmpty) {
    try {
      final document = quill.Document.fromJson(
        List<Map<String, dynamic>>.from(jsonDecode(value) as List),
      );
      final plainText = document.toPlainText().trim();
      return plainText.isEmpty ? null : plainText;
    } catch (_) {
      // Fall through to the plain-text fallback so older or malformed content
      // still shows a readable preview.
    }
  }

  final plainText = fallbackText?.trim();
  if (plainText == null || plainText.isEmpty) {
    return null;
  }
  return plainText;
}

TaskItem normalizeTaskNoteFields(TaskItem task) {
  final normalizedDocumentJson = normalizeNoteDocumentJson(
    task.noteDocumentJson,
    fallbackText: task.description,
  );
  final normalizedPlainText = extractPlainTextFromNoteDocumentJson(
    normalizedDocumentJson,
    fallbackText: task.description,
  );

  if (task.noteDocumentJson == normalizedDocumentJson &&
      task.notePlainText == normalizedPlainText) {
    return task;
  }

  return task.copyWith(
    noteDocumentJson: normalizedDocumentJson,
    notePlainText: normalizedPlainText,
  );
}

String taskNotePreview(TaskItem task) {
  final notePreview = task.notePlainText?.trim();
  if (notePreview != null && notePreview.isNotEmpty) {
    return notePreview;
  }

  final description = task.description?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }

  return '';
}

String taskDescriptionPreview(TaskItem task) {
  final description = task.description?.trim();
  if (description == null || description.isEmpty) {
    return '';
  }
  return description;
}

String taskActualNotePreview(TaskItem task) {
  final notePreview = task.notePlainText?.trim();
  if (notePreview == null || notePreview.isEmpty) {
    return '';
  }
  return notePreview;
}

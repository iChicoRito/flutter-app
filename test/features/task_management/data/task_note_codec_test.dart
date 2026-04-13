import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  test('legacy description migrates into a plain text note document', () {
    final now = DateTime(2026, 4, 13, 9);
    final legacyTask = TaskItem(
      id: 'legacy-task',
      title: 'Legacy task',
      description: 'Existing plain text note',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
    );

    final normalized = normalizeTaskNoteFields(legacyTask);

    expect(normalized.noteDocumentJson, isNotNull);
    expect(normalized.notePlainText, 'Existing plain text note');
  });

  test('plain text document extraction trims trailing editor newlines', () {
    final documentJson = buildPlainTextNoteDocumentJson('First line\nSecond line');

    expect(
      extractPlainTextFromNoteDocumentJson(documentJson),
      'First line\nSecond line',
    );
  });
}

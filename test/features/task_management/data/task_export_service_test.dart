import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/task_management/data/task_export_service.dart';
import 'package:flutter_app/features/task_management/domain/task_attachment.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  test('buildTaskExportJson includes full task metadata and attachments', () {
    final now = DateTime(2026, 4, 20, 8, 30);
    final task = TaskItem(
      id: 'task-export',
      title: 'Prepare launch brief',
      description: 'Add final metrics',
      priority: TaskPriority.high,
      categoryId: 'work',
      standaloneCategoryId: 'work',
      createdAt: now,
      updatedAt: now,
      endDate: DateTime(2026, 4, 21),
      endMinutes: 9 * 60,
      isPinned: true,
      sortOrder: 7,
      noteDocumentJson: '[{"insert":"Launch brief\\n"}]',
      notePlainText: 'Launch brief',
      attachments: [
        TaskAttachment(
          id: 'file-1',
          kind: TaskAttachmentKind.file,
          displayName: 'launch-brief.pdf',
          mimeType: 'application/pdf',
          localPath: '/tmp/launch-brief.pdf',
          sizeBytes: 2048,
          createdAt: now,
        ),
      ],
    );

    final payload = jsonDecode(buildTaskExportJson(task)) as Map<String, dynamic>;

    expect(payload['schemaVersion'], 1);
    expect(payload['task']['id'], 'task-export');
    expect(payload['task']['isPinned'], isTrue);
    expect(payload['task']['sortOrder'], 7);
    expect(payload['task']['noteDocumentJson'], '[{"insert":"Launch brief\\n"}]');
    expect(payload['task']['attachments'], hasLength(1));
    expect(payload['task']['attachments'][0]['displayName'], 'launch-brief.pdf');
    expect(payload['task']['attachments'][0]['mimeType'], 'application/pdf');
  });
}

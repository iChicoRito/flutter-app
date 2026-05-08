import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/vault/vault_models.dart';
import 'package:flutter_app/features/spaces/domain/task_space.dart';
import 'package:flutter_app/features/task_management/data/app_data_transfer_service.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  test('buildAppDataExportJson includes selected tasks and spaces', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'task-1',
      title: 'Prepare recap',
      description: 'Send the recap',
      priority: TaskPriority.high,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
      endDate: DateTime(2026, 4, 14),
      endMinutes: 9 * 60,
      noteDocumentJson: buildPlainTextNoteDocumentJson('Meeting note'),
      notePlainText: 'Meeting note',
    );
    final space = TaskSpace(
      id: 'space-1',
      name: 'Team Space',
      description: 'Shared work area',
      categoryId: 'work',
      colorValue: 0xFF3B82F6,
      createdAt: now,
      updatedAt: now,
      vaultConfig: const VaultConfig(
        isEnabled: true,
        method: VaultMethod.password,
        secretKeyRef: 'secret',
      ),
    );

    final payload = jsonDecode(
      buildAppDataExportJson(
        tasks: [task],
        spaces: [space],
        selection: const AppDataExportSelection(
          includeTasks: true,
          includeSpaces: true,
        ),
        clock: () => now,
      ),
    ) as Map<String, dynamic>;

    expect(payload['schemaVersion'], 1);
    expect(payload['exportedAt'], now.toIso8601String());
    expect(payload['tasks'], isA<List<dynamic>>());
    expect(payload['spaces'], isA<List<dynamic>>());

    final exportedTask = Map<String, dynamic>.from(
      (payload['tasks'] as List).single as Map,
    );
    final exportedSpace = Map<String, dynamic>.from(
      (payload['spaces'] as List).single as Map,
    );

    expect(exportedTask['id'], 'task-1');
    expect(exportedTask['title'], 'Prepare recap');
    expect(exportedTask['notePlainText'], 'Meeting note');
    expect(exportedTask['endDate'], DateTime(2026, 4, 14).toIso8601String());
    expect(exportedSpace['id'], 'space-1');
    expect(exportedSpace['name'], 'Team Space');
    expect(exportedSpace['vaultConfig'], isA<Map<String, dynamic>>());
  });

  test('importAppDataFromJson upserts matching task and space ids', () async {
    final now = DateTime(2026, 4, 13, 9);
    final repository = InMemoryTaskRepository(
      tasks: [
        TaskItem(
          id: 'task-1',
          title: 'Old title',
          priority: TaskPriority.low,
          categoryId: 'work',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      spaces: [
        TaskSpace(
          id: 'space-1',
          name: 'Old space',
          description: 'Old description',
          categoryId: 'work',
          colorValue: 0xFF3B82F6,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final result = await importAppDataFromJson(
      jsonEncode({
        'schemaVersion': 1,
        'exportedAt': now.toIso8601String(),
        'tasks': [
          {
            'id': 'task-1',
            'title': 'Updated title',
            'description': 'Updated description',
            'categoryId': 'work',
            'priority': 'medium',
            'isCompleted': true,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'noteDocumentJson': buildPlainTextNoteDocumentJson('Imported note'),
            'notePlainText': 'Imported note',
          },
        ],
        'spaces': [
          {
            'id': 'space-1',
            'name': 'Updated space',
            'description': 'Updated description',
            'categoryId': 'work',
            'colorValue': 0xFF14B8A6,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ],
      }),
      repository,
    );

    final updatedTask = await repository.getTaskById('task-1');
    final updatedSpace = await repository.getSpaceById('space-1');

    expect(result.taskCount, 1);
    expect(result.spaceCount, 1);
    expect(updatedTask?.title, 'Updated title');
    expect(updatedTask?.isCompleted, isTrue);
    expect(updatedTask?.notePlainText, 'Imported note');
    expect(updatedSpace?.name, 'Updated space');
    expect(updatedSpace?.colorValue, 0xFF14B8A6);
  });

  test('importAppDataFromJson rejects malformed app data', () async {
    final repository = InMemoryTaskRepository();

    expect(
      () => importAppDataFromJson('[]', repository),
      throwsFormatException,
    );
  });
}

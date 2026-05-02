import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';

import 'package:flutter_app/features/spaces/domain/task_space.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_attachment.dart';
import 'package:flutter_app/features/task_management/domain/task_category.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  group('InMemoryTaskRepository spaces', () {
    late InMemoryTaskRepository repository;

    setUp(() {
      repository = InMemoryTaskRepository(
        seedDefaults: false,
        categories: [
          TaskCategory(
            id: 'work',
            name: 'Work',
            iconKey: 'briefcase',
            colorValue: const Color(0xFF066FD1).toARGB32(),
            createdAt: DateTime(2026, 4, 15),
          ),
        ],
      );
    });

    test('saves and reloads spaces', () async {
      final space = TaskSpace(
        id: 'space-1',
        name: 'Sprint Board',
        description: 'Current sprint tasks',
        categoryId: 'work',
        colorValue: const Color(0xFF066FD1).toARGB32(),
        createdAt: DateTime(2026, 4, 15, 8),
        updatedAt: DateTime(2026, 4, 15, 9),
      );

      await repository.upsertSpace(space);
      final spaces = await repository.getSpaces();

      expect(spaces, hasLength(1));
      expect(spaces.single.name, 'Sprint Board');
      expect(spaces.single.categoryId, 'work');
    });

    test(
      'cascade delete removes only tasks inside the selected space',
      () async {
        await repository.upsertSpace(
          TaskSpace(
            id: 'space-a',
            name: 'Alpha',
            description: 'Alpha space',
            categoryId: 'work',
            colorValue: const Color(0xFF066FD1).toARGB32(),
            createdAt: DateTime(2026, 4, 15, 8),
            updatedAt: DateTime(2026, 4, 15, 8),
          ),
        );
        await repository.upsertSpace(
          TaskSpace(
            id: 'space-b',
            name: 'Beta',
            description: 'Beta space',
            categoryId: 'work',
            colorValue: const Color(0xFF0CA678).toARGB32(),
            createdAt: DateTime(2026, 4, 15, 8),
            updatedAt: DateTime(2026, 4, 15, 8),
          ),
        );
        await repository.upsertTask(
          TaskItem(
            id: 'task-a',
            title: 'Inside alpha',
            spaceId: 'space-a',
            priority: TaskPriority.medium,
            categoryId: 'work',
            createdAt: DateTime(2026, 4, 15, 9),
            updatedAt: DateTime(2026, 4, 15, 9),
          ),
        );
        await repository.upsertTask(
          TaskItem(
            id: 'task-b',
            title: 'Inside beta',
            spaceId: 'space-b',
            priority: TaskPriority.medium,
            categoryId: 'work',
            createdAt: DateTime(2026, 4, 15, 9),
            updatedAt: DateTime(2026, 4, 15, 9),
          ),
        );
        await repository.upsertTask(
          TaskItem(
            id: 'task-c',
            title: 'Unassigned',
            priority: TaskPriority.medium,
            categoryId: 'work',
            createdAt: DateTime(2026, 4, 15, 9),
            updatedAt: DateTime(2026, 4, 15, 9),
          ),
        );

        await repository.deleteSpaceWithTasks('space-a');

        final spaces = await repository.getSpaces();
        final tasks = await repository.getTasks();

        expect(spaces.map((space) => space.id), ['space-b']);
        expect(tasks.map((task) => task.id), containsAll(['task-b', 'task-c']));
        expect(tasks.map((task) => task.id), isNot(contains('task-a')));
      },
    );
  });

  group('TaskItemAdapter', () {
    late TaskItemAdapter adapter;
    late TypeRegistryImpl registry;

    setUp(() {
      adapter = TaskItemAdapter();
      registry = TypeRegistryImpl();
      registry.registerAdapter(TaskAttachmentKindAdapter());
      registry.registerAdapter(TaskAttachmentAdapter());
    });

    test('preserves spaceId in the current serialization format', () {
      final task = TaskItem(
        id: 'task-1',
        title: 'Scoped task',
        description: 'Inside a space',
        spaceId: 'space-1',
        priority: TaskPriority.high,
        categoryId: 'work',
        createdAt: DateTime(2026, 4, 15, 10),
        updatedAt: DateTime(2026, 4, 15, 10),
      );

      final writer = BinaryWriterImpl(registry);
      adapter.write(writer, task);
      final reader = BinaryReaderImpl(
        writer.toBytes(),
        registry,
      );
      final restored = adapter.read(reader);

      expect(restored.spaceId, 'space-1');
      expect(restored.noteDocumentJson, task.noteDocumentJson);
    });

    test('preserves pinning, manual order, and attachments', () {
      final task = TaskItem(
        id: 'task-with-metadata',
        title: 'Pinned task',
        description: 'Includes attachments',
        spaceId: 'space-1',
        priority: TaskPriority.high,
        categoryId: 'work',
        createdAt: DateTime(2026, 4, 15, 10),
        updatedAt: DateTime(2026, 4, 15, 10),
        isPinned: true,
        sortOrder: 42,
        attachments: [
          TaskAttachment(
            id: 'attachment-1',
            kind: TaskAttachmentKind.file,
            displayName: 'brief.pdf',
            mimeType: 'application/pdf',
            localPath: '/tmp/brief.pdf',
            sizeBytes: 2048,
            createdAt: DateTime(2026, 4, 15, 10),
          ),
        ],
      );

      final writer = BinaryWriterImpl(registry);
      adapter.write(writer, task);
      final reader = BinaryReaderImpl(
        writer.toBytes(),
        registry,
      );
      final restored = adapter.read(reader);

      expect(restored.isPinned, isTrue);
      expect(restored.sortOrder, 42);
      expect(restored.attachments, hasLength(1));
      expect(restored.attachments.single.displayName, 'brief.pdf');
    });

    test(
      'preserves explicit schedule ranges in the current serialization format',
      () {
        final task = TaskItem(
          id: 'task-range',
          title: 'Timeline task',
          description: 'Keeps its full range',
          priority: TaskPriority.medium,
          categoryId: 'work',
          createdAt: DateTime(2026, 4, 15, 10),
          updatedAt: DateTime(2026, 4, 15, 10),
          startDate: DateTime(2026, 4, 20),
          startMinutes: 8 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        );

      final writer = BinaryWriterImpl(registry);
      adapter.write(writer, task);
      final reader = BinaryReaderImpl(
        writer.toBytes(),
        registry,
      );
      final restored = adapter.read(reader);

        expect(restored.startDateTime, DateTime(2026, 4, 20, 8));
        expect(restored.endDateTime, DateTime(2026, 4, 20, 11));
      },
    );

    test('reads legacy payloads that do not include spaceId', () {
      final writer = BinaryWriterImpl(registry)
        ..writeString('legacy-task')
        ..writeString('Legacy')
        ..write('Old description')
        ..write(null)
        ..write(null)
        ..writeInt(TaskPriority.medium.index)
        ..writeString('work')
        ..writeBool(false)
        ..write(DateTime(2026, 4, 15, 9).millisecondsSinceEpoch)
        ..write(DateTime(2026, 4, 15, 9).millisecondsSinceEpoch)
        ..write(null)
        ..write(null)
        ..write(null)
        ..write(DateTime(2026, 4, 16).millisecondsSinceEpoch)
        ..write(8 * 60)
        ..write('[{"insert":"hello"}]')
        ..write('hello');

      final restored = adapter.read(
        BinaryReaderImpl(writer.toBytes(), registry),
      );

      expect(restored.spaceId, isNull);
      expect(restored.noteDocumentJson, '[{"insert":"hello"}]');
      expect(restored.notePlainText, 'hello');
      expect(restored.isPinned, isFalse);
      expect(restored.attachments, isEmpty);
    });
  });
}

import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/features/spaces/domain/task_space.dart';
import 'package:flutter_app/features/spaces/presentation/spaces_controller.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editing a space category keeps its existing tasks visible', () async {
    final now = DateTime(2026, 4, 21, 9);
    final repository = InMemoryTaskRepository(
      tasks: [
        TaskItem(
          id: 'task-1',
          title: 'Space task',
          priority: TaskPriority.medium,
          categoryId: 'work',
          spaceId: 'space-1',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      spaces: [
        TaskSpace(
          id: 'space-1',
          name: 'Client Work',
          description: '',
          categoryId: 'work',
          colorValue: 0xFF066FD1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final reminderService = _FakeTaskReminderService();
    final controller = SpacesController(
      repository,
      reminderService: reminderService,
    );

    await controller.saveSpace(
      id: 'space-1',
      name: 'Client Work',
      description: '',
      categoryId: 'personal',
      colorValue: 0xFF0CA678,
    );

    final tasks = await repository.getTasksBySpace('space-1');
    expect(tasks.single.categoryId, 'personal');
    expect(reminderService.lastSyncedTask?.categoryId, 'personal');
  });
}

class _FakeTaskReminderService implements TaskReminderService {
  TaskItem? lastSyncedTask;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncTask(TaskItem task, {DateTime? now}) async {
    lastSyncedTask = task;
  }

  @override
  Future<void> syncTaskIfSchedulingChanged({
    required TaskItem previous,
    required TaskItem next,
    DateTime? now,
  }) async {
    lastSyncedTask = next;
  }

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> clearDueNotification(String taskId) async {}

  @override
  Future<void> rebuildPendingReminders(
    Iterable<TaskItem> tasks, {
    DateTime? now,
  }) async {}

  @override
  Future<void> snoozeTask(
    String taskId, {
    required String taskTitle,
    Duration duration = const Duration(minutes: 5),
  }) async {}

  @override
  bool isTaskAlarmSuppressed(String taskId, {DateTime? now}) => false;

  @override
  void bindAlarmHandler(
    Future<void> Function(TaskReminderEvent event) handler,
  ) {}
}

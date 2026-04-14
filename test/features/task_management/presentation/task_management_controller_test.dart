import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_controller.dart';

void main() {
  late InMemoryTaskRepository repository;
  late FakeTaskReminderService reminderService;
  late TaskManagementController controller;

  setUp(() {
    repository = InMemoryTaskRepository(seedDefaults: false);
    reminderService = FakeTaskReminderService();
    controller = TaskManagementController(
      repository,
      reminderService: reminderService,
    );
  });

  test('creating a scheduled task syncs reminders', () async {
    await controller.createTask(
      title: 'Submit report',
      categoryId: 'work',
      priority: TaskPriority.high,
      endDate: DateTime(2026, 4, 14),
      endMinutes: 10 * 60,
    );

    expect(reminderService.syncedTaskIds, hasLength(1));
    expect(reminderService.syncedTaskIds.single, isNotEmpty);
    expect(reminderService.cancelledTaskIds, isEmpty);
  });

  test('deleting a task cancels reminders', () async {
    final task = TaskItem(
      id: 'delete-me',
      title: 'Delete reminder',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: DateTime(2026, 4, 14, 9),
      updatedAt: DateTime(2026, 4, 14, 9),
      endDate: DateTime(2026, 4, 15),
      endMinutes: 8 * 60,
    );
    await repository.upsertTask(task);

    await controller.deleteTask(task.id);

    expect(reminderService.cancelledTaskIds, [task.id]);
  });

  test('toggling completion resyncs reminders with completed state', () async {
    final task = TaskItem(
      id: 'toggle-me',
      title: 'Toggle reminder',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: DateTime(2026, 4, 14, 9),
      updatedAt: DateTime(2026, 4, 14, 9),
      endDate: DateTime(2026, 4, 15),
      endMinutes: 8 * 60,
    );
    await repository.upsertTask(task);

    await controller.toggleTaskCompletion(task);

    expect(reminderService.syncedTaskIds, [task.id]);
    expect(reminderService.lastSyncedTask?.isCompleted, isTrue);
  });
}

class FakeTaskReminderService implements TaskReminderService {
  final List<String> syncedTaskIds = [];
  final List<String> cancelledTaskIds = [];
  TaskItem? lastSyncedTask;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncTask(TaskItem task, {DateTime? now}) async {
    syncedTaskIds.add(task.id);
    lastSyncedTask = task;
  }

  @override
  Future<void> syncTaskIfSchedulingChanged({
    required TaskItem previous,
    required TaskItem next,
    DateTime? now,
  }) async {
    syncedTaskIds.add(next.id);
    lastSyncedTask = next;
  }

  @override
  Future<void> cancelTask(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

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
  void bindAlarmHandler(Future<void> Function(TaskReminderEvent event) handler) {}
}

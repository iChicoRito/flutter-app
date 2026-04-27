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

  test(
    'creating a scheduled task preserves explicit start and end ranges',
    () async {
      final task = await controller.createTask(
        title: 'Science assessment',
        categoryId: 'school',
        priority: TaskPriority.medium,
        startDate: DateTime(2026, 4, 20),
        startMinutes: 8 * 60,
        endDate: DateTime(2026, 4, 20),
        endMinutes: 11 * 60,
      );

      expect(task.startDateTime, DateTime(2026, 4, 20, 8));
      expect(task.endDateTime, DateTime(2026, 4, 20, 11));
    },
  );

  test('calendarDaysForMonth returns every day in the selected month', () {
    final days = controller.calendarDaysForMonth(DateTime(2026, 4, 20));

    expect(days, hasLength(30));
    expect(days.first, DateTime(2026, 4, 1));
    expect(days.last, DateTime(2026, 4, 30));
  });

  test(
    'calendarTasksForDate filters and sorts tasks by the selected date',
    () async {
      await repository.upsertTask(
        TaskItem(
          id: 'later-task',
          title: 'Second block',
          priority: TaskPriority.medium,
          categoryId: 'work',
          createdAt: DateTime(2026, 4, 20, 8),
          updatedAt: DateTime(2026, 4, 20, 8),
          startDate: DateTime(2026, 4, 20),
          startMinutes: 11 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 16 * 60,
        ),
      );
      await repository.upsertTask(
        TaskItem(
          id: 'earlier-task',
          title: 'First block',
          priority: TaskPriority.medium,
          categoryId: 'work',
          createdAt: DateTime(2026, 4, 20, 8),
          updatedAt: DateTime(2026, 4, 20, 8),
          startDate: DateTime(2026, 4, 20),
          startMinutes: 8 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        ),
      );
      await repository.upsertTask(
        TaskItem(
          id: 'other-day-task',
          title: 'Other day block',
          priority: TaskPriority.medium,
          categoryId: 'work',
          createdAt: DateTime(2026, 4, 20, 8),
          updatedAt: DateTime(2026, 4, 20, 8),
          startDate: DateTime(2026, 4, 21),
          startMinutes: 9 * 60,
          endDate: DateTime(2026, 4, 21),
          endMinutes: 10 * 60,
        ),
      );
      await controller.load();

      final tasks = controller.calendarTasksForDate(
        selectedDate: DateTime(2026, 4, 20),
        statusFilter: TaskStatusFilter.all,
        now: DateTime(2026, 4, 20, 7),
      );

      expect(tasks.map((task) => task.id), ['earlier-task', 'later-task']);
    },
  );

  test('calendarTasksForDate applies completed status filtering', () async {
    await repository.upsertTask(
      TaskItem(
        id: 'completed-task',
        title: 'Done block',
        priority: TaskPriority.medium,
        categoryId: 'work',
        createdAt: DateTime(2026, 4, 20, 8),
        updatedAt: DateTime(2026, 4, 20, 8),
        isCompleted: true,
        completedAt: DateTime(2026, 4, 20, 9),
        startDate: DateTime(2026, 4, 20),
        startMinutes: 8 * 60,
        endDate: DateTime(2026, 4, 20),
        endMinutes: 9 * 60,
      ),
    );
    await repository.upsertTask(
      TaskItem(
        id: 'pending-task',
        title: 'Pending block',
        priority: TaskPriority.medium,
        categoryId: 'work',
        createdAt: DateTime(2026, 4, 20, 8),
        updatedAt: DateTime(2026, 4, 20, 8),
        startDate: DateTime(2026, 4, 20),
        startMinutes: 11 * 60,
        endDate: DateTime(2026, 4, 20),
        endMinutes: 12 * 60,
      ),
    );
    await controller.load();

    final tasks = controller.calendarTasksForDate(
      selectedDate: DateTime(2026, 4, 20),
      statusFilter: TaskStatusFilter.completed,
      now: DateTime(2026, 4, 20, 7),
    );

    expect(tasks.map((task) => task.id), ['completed-task']);
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
  void bindAlarmHandler(
    Future<void> Function(TaskReminderEvent event) handler,
  ) {}
}

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  test('returns pending when no schedule is set', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'pending',
      title: 'Write outline',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
    );

    expect(task.statusAt(now), TaskStatus.pending);
  });

  test('returns overdue when end date and time already passed', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'overdue',
      title: 'Send invoice',
      priority: TaskPriority.high,
      categoryId: 'finance',
      createdAt: now,
      updatedAt: now,
      endDate: DateTime(2026, 4, 13),
      endMinutes: 8 * 60,
    );

    expect(task.statusAt(now), TaskStatus.overdue);
  });

  test('completed overrides overdue timing', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'completed',
      title: 'Finish payroll',
      priority: TaskPriority.urgent,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
      endDate: DateTime(2026, 4, 12),
      endMinutes: 18 * 60,
      isCompleted: true,
      completedAt: now,
    );

    expect(task.statusAt(now), TaskStatus.completed);
  });

  test(
    'legacy start-only schedule normalizes into the target end schedule',
    () {
      final now = DateTime(2026, 4, 13, 9);
      final task = TaskItem(
        id: 'start-only',
        title: 'Kickoff meeting',
        priority: TaskPriority.low,
        categoryId: 'work',
        createdAt: now,
        updatedAt: now,
        startDate: DateTime(2026, 4, 12),
        startMinutes: 8 * 60,
      ).normalizedSingleSchedule();

      expect(task.startDate, isNull);
      expect(task.startMinutes, isNull);
      expect(task.endDateTime, DateTime(2026, 4, 12, 8));
      expect(task.statusAt(now), TaskStatus.overdue);
    },
  );

  test('keeps explicit start and end schedule ranges intact', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'range-task',
      title: 'Science assessment',
      priority: TaskPriority.medium,
      categoryId: 'school',
      createdAt: now,
      updatedAt: now,
      startDate: DateTime(2026, 4, 20),
      startMinutes: 8 * 60,
      endDate: DateTime(2026, 4, 20),
      endMinutes: 11 * 60,
    ).normalizedSingleSchedule();

    expect(task.startDateTime, DateTime(2026, 4, 20, 8));
    expect(task.endDateTime, DateTime(2026, 4, 20, 11));
  });

  test('derives no-time schedule type when no schedule fields are set', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'no-time-task',
      title: 'Inbox item',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
    );

    expect(task.scheduleType, TaskScheduleType.noTime);
    expect(task.isNoTimeTask, isTrue);
    expect(task.isDueTimeTask, isFalse);
    expect(task.isTimeRangeTask, isFalse);
  });

  test('derives due-time schedule type from end-only scheduling', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'due-time-task',
      title: 'Submit form',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
      endDate: DateTime(2026, 4, 20),
      endMinutes: 17 * 60,
    );

    expect(task.scheduleType, TaskScheduleType.dueTime);
    expect(task.isNoTimeTask, isFalse);
    expect(task.isDueTimeTask, isTrue);
    expect(task.isTimeRangeTask, isFalse);
  });

  test('derives time-range schedule type from explicit start and end fields', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'time-range-task',
      title: 'Science assessment',
      priority: TaskPriority.medium,
      categoryId: 'school',
      createdAt: now,
      updatedAt: now,
      startDate: DateTime(2026, 4, 20),
      startMinutes: 8 * 60,
      endDate: DateTime(2026, 4, 20),
      endMinutes: 11 * 60,
    );

    expect(task.scheduleType, TaskScheduleType.timeRange);
    expect(task.isNoTimeTask, isFalse);
    expect(task.isDueTimeTask, isFalse);
    expect(task.isTimeRangeTask, isTrue);
  });

  test('defaults pinning, sort order, and attachments for new tasks', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'task-defaults',
      title: 'New task defaults',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
    );

    expect(task.isPinned, isFalse);
    expect(task.sortOrder, isNotNull);
    expect(task.attachments, isEmpty);
  });
}

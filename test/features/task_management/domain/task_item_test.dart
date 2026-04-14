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
}

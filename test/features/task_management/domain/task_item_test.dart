import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  test('returns pending when no due date is set', () {
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

  test('returns overdue when due date and time already passed', () {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'overdue',
      title: 'Send invoice',
      priority: TaskPriority.high,
      categoryId: 'finance',
      createdAt: now,
      updatedAt: now,
      dueDate: DateTime(2026, 4, 13),
      dueMinutes: 8 * 60,
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
      dueDate: DateTime(2026, 4, 12),
      dueMinutes: 18 * 60,
      isCompleted: true,
      completedAt: now,
    );

    expect(task.statusAt(now), TaskStatus.completed);
  });
}

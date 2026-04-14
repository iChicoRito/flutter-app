import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  group('TaskReminderPlan', () {
    final now = DateTime(2026, 4, 14, 9);

    TaskItem buildTask({
      required String id,
      DateTime? endDate,
      int? endMinutes,
      bool isCompleted = false,
    }) {
      return TaskItem(
        id: id,
        title: 'Submit report',
        priority: TaskPriority.high,
        categoryId: 'work',
        createdAt: now,
        updatedAt: now,
        endDate: endDate,
        endMinutes: endMinutes,
        isCompleted: isCompleted,
      );
    }

    test('schedules reminder and due alert for a future task', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'future-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: 10 * 60,
        ),
        now: now,
      );

      expect(entries, hasLength(2));
      expect(entries.first.kind, TaskReminderKind.reminder);
      expect(entries.last.kind, TaskReminderKind.due);
      expect(entries.first.scheduledAt, DateTime(2026, 4, 14, 9, 45));
      expect(entries.last.scheduledAt, DateTime(2026, 4, 14, 10));
    });

    test('skips early reminder when due time is inside the threshold', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'soon-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: (9 * 60) + 10,
        ),
        now: now,
      );

      expect(entries, hasLength(1));
      expect(entries.single.kind, TaskReminderKind.due);
    });

    test('does not schedule tasks without a due time', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(id: 'unscheduled-task'),
        now: now,
      );

      expect(entries, isEmpty);
    });

    test('does not schedule completed tasks', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'completed-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: 11 * 60,
          isCompleted: true,
        ),
        now: now,
      );

      expect(entries, isEmpty);
    });

    test('notification ids are deterministic and distinct', () {
      final reminderId = TaskReminderPlan.reminderNotificationId('task-1');
      final dueId = TaskReminderPlan.dueNotificationId('task-1');

      expect(reminderId, TaskReminderPlan.reminderNotificationId('task-1'));
      expect(dueId, TaskReminderPlan.dueNotificationId('task-1'));
      expect(reminderId, isNot(dueId));
    });
  });
}

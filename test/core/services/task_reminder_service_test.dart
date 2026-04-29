import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  group('TaskReminderPlan', () {
    final now = DateTime(2026, 4, 14, 9);

    TaskItem buildTask({
      required String id,
      String title = 'Submit report',
      DateTime? startDate,
      int? startMinutes,
      DateTime? endDate,
      int? endMinutes,
      bool isCompleted = false,
    }) {
      return TaskItem(
        id: id,
        title: title,
        priority: TaskPriority.high,
        categoryId: 'work',
        createdAt: now,
        updatedAt: now,
        startDate: startDate,
        startMinutes: startMinutes,
        endDate: endDate,
        endMinutes: endMinutes,
        isCompleted: isCompleted,
      );
    }

    test('schedules both pre-deadline reminders and the due alert', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'future-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: 10 * 60,
        ),
        now: now,
        displayName: 'Mark',
      );

      expect(entries, hasLength(3));
      expect(entries.first.kind, TaskReminderKind.reminder);
      expect(entries[1].kind, TaskReminderKind.reminder);
      expect(entries.last.kind, TaskReminderKind.due);
      expect(entries.first.scheduledAt, DateTime(2026, 4, 14, 9, 50));
      expect(entries[1].scheduledAt, DateTime(2026, 4, 14, 9, 55));
      expect(entries.last.scheduledAt, DateTime(2026, 4, 14, 10));
      expect(entries.first.title, 'Hi, Mark');
      expect(
        entries.first.body,
        'Your task "Submit report" is due in 10 minutes.',
      );
      expect(entries[1].body, 'Your task "Submit report" is due in 5 minutes.');
      expect(entries.last.body, 'Your task "Submit report" is due now.');
    });

    test('schedules start reminder end reminder and due alarm for calendar tasks', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'calendar-task',
          title: 'Sampletasks',
          startDate: DateTime(2026, 4, 14),
          startMinutes: 10 * 60,
          endDate: DateTime(2026, 4, 14),
          endMinutes: 11 * 60,
        ),
        now: now,
        displayName: 'Mark',
      );

      expect(entries, hasLength(3));
      expect(entries[0].kind, TaskReminderKind.scheduledStart);
      expect(entries[1].kind, TaskReminderKind.scheduledEnd);
      expect(entries[2].kind, TaskReminderKind.due);
      expect(entries[0].scheduledAt, DateTime(2026, 4, 14, 9, 55));
      expect(entries[1].scheduledAt, DateTime(2026, 4, 14, 10, 55));
      expect(entries[2].scheduledAt, DateTime(2026, 4, 14, 11));
      expect(
        entries[0].body,
        'Hello, Mark, your scheduled task for Sampletasks will begin in 5mins.',
      );
      expect(
        entries[1].body,
        'Hello, Mark, your scheduled task for Sampletasks will end in 5mins.',
      );
    });

    test('keeps only future calendar reminders when start reminder has passed', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'calendar-task-soon',
          startDate: DateTime(2026, 4, 14),
          startMinutes: (9 * 60) + 4,
          endDate: DateTime(2026, 4, 14),
          endMinutes: 10 * 60,
        ),
        now: now,
        displayName: 'Mark',
      );

      expect(entries, hasLength(2));
      expect(entries[0].kind, TaskReminderKind.scheduledEnd);
      expect(entries[1].kind, TaskReminderKind.due);
      expect(entries[0].scheduledAt, DateTime(2026, 4, 14, 9, 55));
      expect(entries[1].scheduledAt, DateTime(2026, 4, 14, 10));
    });

    test('keeps only due alarm when calendar end reminder has passed', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'calendar-task-ending',
          startDate: DateTime(2026, 4, 14),
          startMinutes: 8 * 60,
          endDate: DateTime(2026, 4, 14),
          endMinutes: (9 * 60) + 4,
        ),
        now: now,
        displayName: 'Mark',
      );

      expect(entries, hasLength(1));
      expect(entries.single.kind, TaskReminderKind.due);
      expect(entries.single.scheduledAt, DateTime(2026, 4, 14, 9, 4));
    });

    test('keeps only future reminders when deadline is inside 10 minutes', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'soon-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: (9 * 60) + 8,
        ),
        now: now,
      );

      expect(entries, hasLength(2));
      expect(entries.first.scheduledAt, DateTime(2026, 4, 14, 9, 3));
      expect(entries.last.kind, TaskReminderKind.due);
    });

    test('uses fallback greeting when no display name exists', () {
      final entries = TaskReminderPlan.buildEntries(
        buildTask(
          id: 'fallback-task',
          endDate: DateTime(2026, 4, 14),
          endMinutes: 10 * 60,
        ),
        now: now,
      );

      expect(entries.first.title, 'Hi, there');
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
      final firstReminderId = TaskReminderPlan.firstReminderNotificationId(
        'task-1',
      );
      final secondReminderId = TaskReminderPlan.secondReminderNotificationId(
        'task-1',
      );
      final startReminderId = TaskReminderPlan.scheduledStartNotificationId(
        'task-1',
      );
      final endReminderId = TaskReminderPlan.scheduledEndNotificationId(
        'task-1',
      );
      final dueId = TaskReminderPlan.dueNotificationId('task-1');

      expect(
        firstReminderId,
        TaskReminderPlan.firstReminderNotificationId('task-1'),
      );
      expect(
        secondReminderId,
        TaskReminderPlan.secondReminderNotificationId('task-1'),
      );
      expect(
        startReminderId,
        TaskReminderPlan.scheduledStartNotificationId('task-1'),
      );
      expect(
        endReminderId,
        TaskReminderPlan.scheduledEndNotificationId('task-1'),
      );
      expect(dueId, TaskReminderPlan.dueNotificationId('task-1'));
      expect(firstReminderId, isNot(secondReminderId));
      expect(startReminderId, isNot(endReminderId));
      expect(startReminderId, isNot(dueId));
      expect(endReminderId, isNot(dueId));
      expect(firstReminderId, isNot(dueId));
      expect(secondReminderId, isNot(dueId));
    });

    test('detects start-time scheduling changes for calendar tasks', () {
      final previous = buildTask(
        id: 'calendar-task',
        startDate: DateTime(2026, 4, 14),
        startMinutes: 10 * 60,
        endDate: DateTime(2026, 4, 14),
        endMinutes: 11 * 60,
      );
      final next = previous.copyWith(startMinutes: (10 * 60) + 30);

      expect(TaskReminderPlan.hasSchedulingChange(previous, next), isTrue);
    });
  });
}

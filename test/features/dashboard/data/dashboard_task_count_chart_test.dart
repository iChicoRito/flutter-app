import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/dashboard/data/dashboard_chart_export_service.dart';
import 'package:flutter_app/features/dashboard/domain/dashboard_task_count_chart.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';

void main() {
  TaskItem buildTask({required String id, required DateTime createdAt}) {
    return TaskItem(
      id: id,
      title: id,
      priority: TaskPriority.medium,
      categoryId: 'work',
      standaloneCategoryId: 'work',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  group('DashboardTaskCountChartData.fromTasks', () {
    test(
      'builds this week bars Monday through Sunday with zero-filled days',
      () {
        final now = DateTime(2026, 5, 7, 9);
        final data = DashboardTaskCountChartData.fromTasks(
          tasks: [
            buildTask(id: 'a', createdAt: DateTime(2026, 5, 4, 8)),
            buildTask(id: 'b', createdAt: DateTime(2026, 5, 4, 18)),
            buildTask(id: 'c', createdAt: DateTime(2026, 5, 6, 11)),
          ],
          scope: DashboardTaskCountScope.thisWeek,
          now: now,
        );

        expect(data.scope, DashboardTaskCountScope.thisWeek);
        expect(data.rangeStart, DateTime(2026, 5, 4));
        expect(data.rangeEnd, DateTime(2026, 5, 10));
        expect(data.totalCount, 3);
        expect(data.maxCount, 2);
        expect(data.bars, hasLength(7));
        expect(data.bars.map((bar) => bar.label), [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ]);
        expect(data.bars.map((bar) => bar.count), [2, 0, 1, 0, 0, 0, 0]);
        expect(data.bars.every((bar) => bar.isCurrentMonthDay), isTrue);
      },
    );

    test('zeros weekly bars that fall outside the current month', () {
      final now = DateTime(2026, 5, 1, 9);
      final data = DashboardTaskCountChartData.fromTasks(
        tasks: [
          buildTask(id: 'april', createdAt: DateTime(2026, 4, 28, 12)),
          buildTask(id: 'may', createdAt: DateTime(2026, 5, 1, 12)),
        ],
        scope: DashboardTaskCountScope.thisWeek,
        now: now,
      );

      expect(data.rangeStart, DateTime(2026, 4, 27));
      expect(data.rangeEnd, DateTime(2026, 5, 3));
      expect(data.bars.take(4).map((bar) => bar.isCurrentMonthDay), [
        false,
        false,
        false,
        false,
      ]);
      expect(data.bars.take(4).map((bar) => bar.count), [0, 0, 0, 0]);
      expect(data.bars.skip(4).map((bar) => bar.count), [1, 0, 0]);
      expect(data.totalCount, 1);
    });

    test('builds one bar per day for the current month', () {
      final now = DateTime(2026, 2, 13, 9);
      final data = DashboardTaskCountChartData.fromTasks(
        tasks: [
          buildTask(id: 'a', createdAt: DateTime(2026, 2, 1, 8)),
          buildTask(id: 'b', createdAt: DateTime(2026, 2, 13, 9)),
          buildTask(id: 'c', createdAt: DateTime(2026, 2, 13, 12)),
          buildTask(id: 'd', createdAt: DateTime(2026, 2, 28, 17)),
        ],
        scope: DashboardTaskCountScope.thisMonth,
        now: now,
      );

      expect(data.scope, DashboardTaskCountScope.thisMonth);
      expect(data.rangeStart, DateTime(2026, 2, 1));
      expect(data.rangeEnd, DateTime(2026, 2, 28));
      expect(data.bars, hasLength(28));
      expect(data.bars.first.label, '1');
      expect(data.bars[12].label, '13');
      expect(data.bars.last.label, '28');
      expect(data.bars[0].count, 1);
      expect(data.bars[12].count, 2);
      expect(data.bars.last.count, 1);
      expect(data.totalCount, 4);
    });

    test('counts scheduled dates before falling back to updatedAt', () {
      final now = DateTime(2026, 5, 7, 9);
      final data = DashboardTaskCountChartData.fromTasks(
        tasks: [
          TaskItem(
            id: 'task',
            title: 'task',
            priority: TaskPriority.medium,
            categoryId: 'work',
            standaloneCategoryId: 'work',
            createdAt: DateTime(2026, 5, 4, 8),
            updatedAt: DateTime(2026, 5, 7, 8),
            endDate: DateTime(2026, 5, 4),
          ),
        ],
        scope: DashboardTaskCountScope.thisWeek,
        now: now,
      );

      expect(data.bars.first.count, 1);
      expect(data.bars[5].count, 0);
      expect(data.bars.last.count, 0);
    });

    test('falls back to updatedAt when a task has no scheduled date', () {
      final now = DateTime(2026, 5, 7, 9);
      final data = DashboardTaskCountChartData.fromTasks(
        tasks: [
          TaskItem(
            id: 'task',
            title: 'task',
            priority: TaskPriority.medium,
            categoryId: 'work',
            standaloneCategoryId: 'work',
            createdAt: DateTime(2026, 5, 4, 8),
            updatedAt: DateTime(2026, 5, 7, 8),
          ),
        ],
        scope: DashboardTaskCountScope.thisWeek,
        now: now,
      );

      expect(data.bars.first.count, 0);
      expect(data.bars[3].count, 1);
    });

    test('rounds the y axis to a nearby value for small totals', () {
      final now = DateTime(2026, 5, 7, 9);
      final data = DashboardTaskCountChartData.fromTasks(
        tasks: [buildTask(id: 'a', createdAt: DateTime(2026, 5, 4, 8))],
        scope: DashboardTaskCountScope.thisWeek,
        now: now,
      );

      expect(data.maxCount, 1);
      expect(data.axisMaximum, 5);
      expect(data.axisLabels, [5, 4, 3, 2, 1, 0]);
    });

    test(
      'rounds the y axis to the exact highest count when it fits cleanly',
      () {
        final now = DateTime(2026, 5, 7, 9);
        final data = DashboardTaskCountChartData.fromTasks(
          tasks: List.generate(
            10,
            (index) => buildTask(
              id: 'task-$index',
              createdAt: DateTime(2026, 5, 4, 8 + index),
            ),
          ),
          scope: DashboardTaskCountScope.thisWeek,
          now: now,
        );

        expect(data.maxCount, 10);
        expect(data.axisMaximum, 10);
        expect(data.axisLabels, [10, 8, 6, 4, 2, 0]);
      },
    );
  });

  test('buildDashboardTaskCountExportJson includes the visible chart data', () {
    final data = DashboardTaskCountChartData.fromTasks(
      tasks: [
        buildTask(id: 'a', createdAt: DateTime(2026, 5, 4, 8)),
        buildTask(id: 'b', createdAt: DateTime(2026, 5, 5, 8)),
      ],
      scope: DashboardTaskCountScope.thisWeek,
      now: DateTime(2026, 5, 7, 9),
    );

    final payload =
        jsonDecode(buildDashboardTaskCountExportJson(data))
            as Map<String, dynamic>;

    expect(payload['schemaVersion'], 1);
    expect(payload['chartType'], 'taskCount');
    expect(payload['scope'], 'thisWeek');
    expect(payload['rangeStart'], '2026-05-04');
    expect(payload['rangeEnd'], '2026-05-10');
    expect(payload['bars'], hasLength(7));
    expect(payload['bars'][0], {
      'date': '2026-05-04',
      'label': 'Mon',
      'count': 1,
    });
  });
}

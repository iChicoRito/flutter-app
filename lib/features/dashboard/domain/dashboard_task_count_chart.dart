import '../../task_management/domain/task_item.dart';

enum DashboardTaskCountScope { thisWeek, thisMonth }

class DashboardTaskCountBar {
  const DashboardTaskCountBar({
    required this.date,
    required this.label,
    required this.count,
    required this.isCurrentMonthDay,
  });

  final DateTime date;
  final String label;
  final int count;
  final bool isCurrentMonthDay;
}

class DashboardTaskCountChartData {
  const DashboardTaskCountChartData({
    required this.scope,
    required this.rangeStart,
    required this.rangeEnd,
    required this.bars,
    required this.maxCount,
    required this.totalCount,
  });

  factory DashboardTaskCountChartData.fromTasks({
    required List<TaskItem> tasks,
    required DashboardTaskCountScope scope,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (scope) {
      DashboardTaskCountScope.thisWeek => _buildWeek(tasks: tasks, now: today),
      DashboardTaskCountScope.thisMonth => _buildMonth(
        tasks: tasks,
        now: today,
      ),
    };
  }

  final DashboardTaskCountScope scope;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<DashboardTaskCountBar> bars;
  final int maxCount;
  final int totalCount;

  int get axisMaximum {
    if (maxCount <= 0) {
      return 5;
    }
    return ((maxCount + 4) ~/ 5) * 5;
  }

  int get axisStep => axisMaximum ~/ 5;

  List<int> get axisLabels {
    final step = axisStep;
    return List<int>.generate(6, (index) => axisMaximum - (step * index));
  }

  static DashboardTaskCountChartData _buildWeek({
    required List<TaskItem> tasks,
    required DateTime now,
  }) {
    final rangeStart = now.subtract(Duration(days: now.weekday - 1));
    final rangeEnd = rangeStart.add(const Duration(days: 6));
    final counts = _countTasksByDay(tasks);
    final bars = <DashboardTaskCountBar>[];

    for (var index = 0; index < 7; index++) {
      final date = rangeStart.add(Duration(days: index));
      final isCurrentMonthDay =
          date.month == now.month && date.year == now.year;
      bars.add(
        DashboardTaskCountBar(
          date: date,
          label: _weekdayLabel(date.weekday),
          count: isCurrentMonthDay ? (counts[_dateKey(date)] ?? 0) : 0,
          isCurrentMonthDay: isCurrentMonthDay,
        ),
      );
    }

    return DashboardTaskCountChartData(
      scope: DashboardTaskCountScope.thisWeek,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      bars: bars,
      maxCount: _maxCount(bars),
      totalCount: _totalCount(bars),
    );
  }

  static DashboardTaskCountChartData _buildMonth({
    required List<TaskItem> tasks,
    required DateTime now,
  }) {
    final rangeStart = DateTime(now.year, now.month, 1);
    final rangeEnd = now.month == 12
        ? DateTime(now.year + 1, 1, 0)
        : DateTime(now.year, now.month + 1, 0);
    final counts = _countTasksByDay(tasks);
    final bars = <DashboardTaskCountBar>[];

    for (var day = 1; day <= rangeEnd.day; day++) {
      final date = DateTime(now.year, now.month, day);
      bars.add(
        DashboardTaskCountBar(
          date: date,
          label: '$day',
          count: counts[_dateKey(date)] ?? 0,
          isCurrentMonthDay: true,
        ),
      );
    }

    return DashboardTaskCountChartData(
      scope: DashboardTaskCountScope.thisMonth,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      bars: bars,
      maxCount: _maxCount(bars),
      totalCount: _totalCount(bars),
    );
  }

  static Map<String, int> _countTasksByDay(List<TaskItem> tasks) {
    final counts = <String, int>{};
    for (final task in tasks) {
      final key = _dateKey(dashboardTaskCountDateForTask(task));
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static int _maxCount(List<DashboardTaskCountBar> bars) {
    var maxCount = 0;
    for (final bar in bars) {
      if (bar.count > maxCount) {
        maxCount = bar.count;
      }
    }
    return maxCount == 0 ? 1 : maxCount;
  }

  static int _totalCount(List<DashboardTaskCountBar> bars) {
    var total = 0;
    for (final bar in bars) {
      total += bar.count;
    }
    return total;
  }
}

String dashboardTaskCountDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime dashboardTaskCountDateForTask(TaskItem task) =>
    task.endDateTime ?? task.startDateTime ?? task.updatedAt;

String _dateKey(DateTime date) => dashboardTaskCountDateKey(date);

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
    _ => '',
  };
}

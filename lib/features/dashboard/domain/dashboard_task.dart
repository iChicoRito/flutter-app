enum TaskPriority { low, medium, high }

enum TaskBucket { today, tomorrow, thisWeek, later, overdue, completed }

class DashboardTask {
  const DashboardTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.bucket,
    this.timeLabel,
    this.isCompleted = false,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String? timeLabel;
  final TaskPriority priority;
  final TaskBucket bucket;
  final bool isCompleted;
  final bool isPinned;

  bool get isOverdue => bucket == TaskBucket.overdue;

  DashboardTask copyWith({
    String? id,
    String? title,
    String? timeLabel,
    TaskPriority? priority,
    TaskBucket? bucket,
    bool? isCompleted,
    bool? isPinned,
  }) {
    return DashboardTask(
      id: id ?? this.id,
      title: title ?? this.title,
      timeLabel: timeLabel ?? this.timeLabel,
      priority: priority ?? this.priority,
      bucket: bucket ?? this.bucket,
      isCompleted: isCompleted ?? this.isCompleted,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

enum TaskPriority { low, medium, high, urgent }

enum TaskStatus { pending, completed, overdue }

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.dueMinutes,
    this.isCompleted = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final int? dueMinutes;
  final TaskPriority priority;
  final String categoryId;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  DateTime? get dueDateTime {
    if (dueDate == null) {
      return null;
    }

    final minutes = dueMinutes ?? 0;
    return DateTime(
      dueDate!.year,
      dueDate!.month,
      dueDate!.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  TaskStatus statusAt(DateTime now) {
    if (isCompleted) {
      return TaskStatus.completed;
    }

    final due = dueDateTime;
    if (due != null && due.isBefore(now)) {
      return TaskStatus.overdue;
    }

    return TaskStatus.pending;
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    int? dueMinutes,
    bool clearDueDate = false,
    bool clearDueMinutes = false,
    TaskPriority? priority,
    String? categoryId,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      dueMinutes: clearDueMinutes ? null : dueMinutes ?? this.dueMinutes,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

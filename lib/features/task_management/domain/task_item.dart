import '../../../core/vault/vault_models.dart';

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
    this.spaceId,
    this.vaultConfig,
    this.archivedAt,
    this.noteDocumentJson,
    this.notePlainText,
    this.startDate,
    this.startMinutes,
    this.endDate,
    this.endMinutes,
    this.isCompleted = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? spaceId;
  final VaultConfig? vaultConfig;
  final DateTime? archivedAt;
  final String? noteDocumentJson;
  final String? notePlainText;
  final DateTime? startDate;
  final int? startMinutes;
  final DateTime? endDate;
  final int? endMinutes;
  final TaskPriority priority;
  final String categoryId;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isArchived => archivedAt != null;

  DateTime? get startDateTime {
    if (startDate == null) {
      return null;
    }

    final minutes = startMinutes ?? 0;
    return DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  DateTime? get endDateTime {
    if (endDate == null) {
      return null;
    }

    final minutes = endMinutes ?? 0;
    return DateTime(
      endDate!.year,
      endDate!.month,
      endDate!.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  TaskItem normalizedSingleSchedule() {
    final targetDate = endDate ?? startDate;
    final targetMinutes = endMinutes ?? startMinutes;

    return copyWith(
      startDate: null,
      startMinutes: null,
      clearStartDate: true,
      clearStartMinutes: true,
      endDate: targetDate,
      endMinutes: targetMinutes,
      clearEndDate: targetDate == null,
      clearEndMinutes: targetMinutes == null,
    );
  }

  TaskStatus statusAt(DateTime now) {
    if (isCompleted) {
      return TaskStatus.completed;
    }

    final end = endDateTime;
    if (end != null && end.isBefore(now)) {
      return TaskStatus.overdue;
    }

    return TaskStatus.pending;
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    String? spaceId,
    bool clearSpaceId = false,
    VaultConfig? vaultConfig,
    bool clearVaultConfig = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    String? noteDocumentJson,
    String? notePlainText,
    DateTime? startDate,
    int? startMinutes,
    bool clearStartDate = false,
    bool clearStartMinutes = false,
    DateTime? endDate,
    int? endMinutes,
    bool clearEndDate = false,
    bool clearEndMinutes = false,
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
      spaceId: clearSpaceId ? null : spaceId ?? this.spaceId,
      vaultConfig: clearVaultConfig ? null : vaultConfig ?? this.vaultConfig,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      noteDocumentJson: noteDocumentJson ?? this.noteDocumentJson,
      notePlainText: notePlainText ?? this.notePlainText,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      startMinutes: clearStartMinutes
          ? null
          : startMinutes ?? this.startMinutes,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      endMinutes: clearEndMinutes ? null : endMinutes ?? this.endMinutes,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

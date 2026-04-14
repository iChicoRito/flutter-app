import 'package:flutter/widgets.dart';

import 'task_reminder_service.dart';

class TaskReminderScope extends InheritedWidget {
  const TaskReminderScope({
    super.key,
    required this.reminderService,
    required super.child,
  });

  final TaskReminderService reminderService;

  static TaskReminderService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TaskReminderScope>();
    assert(scope != null, 'TaskReminderScope not found in context');
    return scope!.reminderService;
  }

  @override
  bool updateShouldNotify(TaskReminderScope oldWidget) {
    return reminderService != oldWidget.reminderService;
  }
}

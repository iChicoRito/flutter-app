import 'package:flutter/widgets.dart';

import '../../features/task_management/domain/task_repository.dart';

class TaskRepositoryScope extends InheritedWidget {
  const TaskRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final TaskRepository repository;

  static TaskRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TaskRepositoryScope>();
    assert(scope != null, 'TaskRepositoryScope is missing in the widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(TaskRepositoryScope oldWidget) {
    return repository != oldWidget.repository;
  }
}

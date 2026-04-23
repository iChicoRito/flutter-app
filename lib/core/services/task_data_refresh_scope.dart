import 'package:flutter/widgets.dart';

class TaskDataRefreshController extends ChangeNotifier {
  void notifyDataChanged() {
    notifyListeners();
  }
}

class TaskDataRefreshScope extends InheritedWidget {
  const TaskDataRefreshScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final TaskDataRefreshController controller;

  static TaskDataRefreshController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TaskDataRefreshScope>();
    assert(
      scope != null,
      'TaskDataRefreshScope is missing in the widget tree.',
    );
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(TaskDataRefreshScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/services/task_reminder_service.dart';
import 'features/task_management/data/hive_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminderService = LocalTaskReminderService();
  await reminderService.initialize();
  final taskRepository = await HiveTaskRepository.initialize();
  await reminderService.rebuildPendingReminders(await taskRepository.getTasks());
  runApp(
    MyApp(
      taskRepository: taskRepository,
      reminderService: reminderService,
    ),
  );
}

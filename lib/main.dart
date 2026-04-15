import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/services/display_name_store.dart';
import 'core/services/task_reminder_service.dart';
import 'core/services/vault_service.dart';
import 'features/task_management/data/hive_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const displayNameStore = SharedPreferencesDisplayNameStore();
  final reminderService = LocalTaskReminderService(
    displayNameStore: displayNameStore,
  );
  await reminderService.initialize();
  final taskRepository = await HiveTaskRepository.initialize();
  final vaultService = LocalVaultService();
  await reminderService.rebuildPendingReminders(
    await taskRepository.getTasks(),
  );
  runApp(
    MyApp(
      displayNameStore: displayNameStore,
      taskRepository: taskRepository,
      reminderService: reminderService,
      vaultService: vaultService,
    ),
  );
}

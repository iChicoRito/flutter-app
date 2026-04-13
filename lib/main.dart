import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/task_management/data/hive_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final taskRepository = await HiveTaskRepository.initialize();
  runApp(MyApp(taskRepository: taskRepository));
}

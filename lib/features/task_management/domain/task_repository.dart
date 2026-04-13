import 'task_category.dart';
import 'task_item.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> getTasks();

  Future<List<TaskCategory>> getCategories();

  Future<void> upsertTask(TaskItem task);

  Future<void> deleteTask(String taskId);

  Future<void> upsertCategory(TaskCategory category);
}

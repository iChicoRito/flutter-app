import 'task_category.dart';
import 'task_item.dart';
import '../../spaces/domain/task_space.dart';

abstract class TaskRepository {
  Future<List<TaskItem>> getTasks();

  Future<List<TaskItem>> getTasksBySpace(String spaceId);

  Future<TaskItem?> getTaskById(String taskId);

  Future<List<TaskCategory>> getCategories();

  Future<List<TaskSpace>> getSpaces();

  Future<TaskSpace?> getSpaceById(String spaceId);

  Future<void> upsertTask(TaskItem task);

  Future<void> deleteTask(String taskId);

  Future<void> upsertCategory(TaskCategory category);

  Future<void> upsertSpace(TaskSpace space);

  Future<void> deleteSpace(String spaceId);

  Future<void> deleteSpaceWithTasks(String spaceId);
}

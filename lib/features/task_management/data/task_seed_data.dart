import '../domain/task_category.dart';

List<TaskCategory> buildDefaultTaskCategories() {
  final now = DateTime.now();

  return const [
    (id: 'personal', name: 'Personal', iconKey: 'user', colorValue: 0xFF1E88E5),
    (id: 'work', name: 'Work', iconKey: 'briefcase', colorValue: 0xFFF59F00),
    (id: 'study', name: 'Study', iconKey: 'book', colorValue: 0xFF7C3AED),
    (
      id: 'shopping',
      name: 'Shopping',
      iconKey: 'shopping_cart',
      colorValue: 0xFF0CA678,
    ),
    (
      id: 'health',
      name: 'Health',
      iconKey: 'heartbeat',
      colorValue: 0xFFD63939,
    ),
    (id: 'finance', name: 'Finance', iconKey: 'cash', colorValue: 0xFF6B7280),
  ].map((seed) {
    return TaskCategory(
      id: seed.id,
      name: seed.name,
      iconKey: seed.iconKey,
      colorValue: seed.colorValue,
      createdAt: now,
    );
  }).toList();
}

import 'package:flutter/material.dart';

import '../../../core/services/task_reminder_service.dart';
import '../../task_management/domain/task_repository.dart';
import '../../task_management/presentation/task_management_controller.dart';
import '../../task_management/presentation/task_management_screen.dart';
import '../domain/task_space.dart';

class SpaceDetailScreen extends StatefulWidget {
  const SpaceDetailScreen({
    super.key,
    required this.repository,
    required this.space,
    required this.reminderService,
  });

  final TaskRepository repository;
  final TaskSpace space;
  final TaskReminderService reminderService;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  late final TaskManagementController _controller = TaskManagementController(
    widget.repository,
    reminderService: widget.reminderService,
    fixedSpaceId: widget.space.id,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TaskManagementScreen(
      repository: widget.repository,
      controller: _controller,
      appBarTitle: widget.space.name,
      useInlineBackHeader: true,
      space: widget.space,
      fixedSpaceId: widget.space.id,
      lockedCategoryId: widget.space.categoryId,
      fabLabel: 'Add Task',
      emptyTitle: 'No tasks in this space yet',
      emptyMessage:
          'Create a task inside this space to keep related work together.',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/core/services/task_data_refresh_scope.dart';
import 'package:flutter_app/core/services/task_reminder_scope.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/services/vault_service_scope.dart';
import 'package:flutter_app/core/theme/app_design_tokens.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_category.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_controller.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';

void main() {
  late InMemoryTaskRepository repository;
  late TaskManagementController controller;

  setUp(() {
    repository = InMemoryTaskRepository(seedDefaults: false);
    controller = TaskManagementController(repository);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<TaskItem> tasks,
    List<TaskCategory>? categories,
  }) async {
    repository = InMemoryTaskRepository(
      tasks: tasks,
      categories: categories,
      seedDefaults: false,
    );
    controller = TaskManagementController(repository);
    await controller.load();
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      TaskDataRefreshScope(
        controller: TaskDataRefreshController(),
        child: TaskReminderScope(
          reminderService: const NoopTaskReminderService(),
          child: VaultServiceScope(
            vaultService: const NoopVaultService(),
            child: MaterialApp(
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: TaskManagementScreen(
                repository: repository,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('finished tasks render below pending tasks in a separate section', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
        buildTask(
          id: 'finished-task',
          title: 'Send invoice',
          priority: TaskPriority.high,
          categoryId: 'work',
          isCompleted: true,
        ),
      ],
    );

    expect(
      find.byKey(TaskManagementScreen.taskListSegmentKey('all')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.taskListSegmentKey('pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.taskListSegmentKey('finished')),
      findsOneWidget,
    );
    expect(find.byKey(TaskManagementScreen.taskTileKey('pending-task')), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.taskTileKey('finished-task')), findsOneWidget);

    final pendingTaskTop = tester.getTopLeft(
      find.byKey(TaskManagementScreen.taskTileKey('pending-task')),
    ).dy;
    final finishedTaskTop = tester.getTopLeft(
      find.byKey(TaskManagementScreen.taskTileKey('finished-task')),
    ).dy;

    expect(pendingTaskTop, lessThan(finishedTaskTop));
  });

  testWidgets('pending segment hides finished tasks', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
        buildTask(
          id: 'finished-task',
          title: 'Send invoice',
          priority: TaskPriority.high,
          categoryId: 'work',
          isCompleted: true,
        ),
      ],
    );

    await tester.tap(find.byKey(TaskManagementScreen.taskListSegmentKey('pending')));
    await tester.pumpAndSettle();

    expect(find.byKey(TaskManagementScreen.taskTileKey('pending-task')), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.taskTileKey('finished-task')), findsNothing);
  });

  testWidgets('finished segment hides pending tasks', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
        buildTask(
          id: 'finished-task',
          title: 'Send invoice',
          priority: TaskPriority.high,
          categoryId: 'work',
          isCompleted: true,
        ),
      ],
    );

    await tester.tap(find.byKey(TaskManagementScreen.taskListSegmentKey('finished')));
    await tester.pumpAndSettle();

    expect(find.byKey(TaskManagementScreen.taskTileKey('pending-task')), findsNothing);
    expect(find.byKey(TaskManagementScreen.taskTileKey('finished-task')), findsOneWidget);
  });

  testWidgets('category filtering still works after switching segments', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      categories: [
        TaskCategory(
          id: 'work',
          name: 'Work',
          iconKey: 'briefcase',
          colorValue: AppColors.blue500.toARGB32(),
          createdAt: DateTime(2026, 4, 13, 9),
        ),
        TaskCategory(
          id: 'health',
          name: 'Health',
          iconKey: 'heartbeat',
          colorValue: AppColors.teal500.toARGB32(),
          createdAt: DateTime(2026, 4, 13, 9),
        ),
      ],
      tasks: [
        buildTask(
          id: 'work-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
        buildTask(
          id: 'health-task',
          title: 'Go for a walk',
          priority: TaskPriority.low,
          categoryId: 'health',
        ),
      ],
    );

    await tester.tap(find.byKey(TaskManagementScreen.taskListSegmentKey('pending')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TaskManagementScreen.categoryFilterKey('health')));
    await tester.pumpAndSettle();

    expect(find.byKey(TaskManagementScreen.taskTileKey('health-task')), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.taskTileKey('work-task')), findsNothing);
  });

  testWidgets('tasks list keeps a small gap below the segmented control', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
      ],
    );

    final segmentBottom = tester
        .getBottomLeft(find.byKey(TaskManagementScreen.taskListSegmentKey('all')))
        .dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(TaskManagementScreen.taskTileKey('pending-task')))
        .dy;

    expect(firstCardTop - segmentBottom, greaterThanOrEqualTo(AppSpacing.two));
    expect(firstCardTop - segmentBottom, lessThan(AppSpacing.four * 2));
  });

  testWidgets('task list segmented control stays compact', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
      ],
    );

    final segmentRect = tester.getRect(
      find.byKey(TaskManagementScreen.taskListSegmentKey('all')),
    );

    expect(segmentRect.height, lessThan(38));
    expect(segmentRect.height, greaterThan(30));
  });

  testWidgets('task list segmented control uses softer corners', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'pending-task',
          title: 'Draft launch checklist',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
      ],
    );

    final shellContainer = tester.widget<Container>(
      find.ancestor(
        of: find.byKey(TaskManagementScreen.taskListSegmentKey('all')),
        matching: find.byType(Container),
      ).first,
    );
    final shellDecoration = shellContainer.decoration! as BoxDecoration;
    final shellRadius = (shellDecoration.borderRadius! as BorderRadius).topLeft.x;

    final selectedSegment = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(TaskManagementScreen.taskListSegmentKey('all')),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    final segmentDecoration = selectedSegment.decoration! as BoxDecoration;
    final segmentRadius = (segmentDecoration.borderRadius! as BorderRadius).topLeft.x;

    expect(shellRadius, lessThan(16));
    expect(segmentRadius, lessThan(16));
  });

  testWidgets('task cards no longer show the description preview', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      tasks: [
        buildTask(
          id: 'minimal-task',
          title: 'Prepare weekly report',
          priority: TaskPriority.medium,
          categoryId: 'work',
          description: 'Send recap to leadership',
        ),
      ],
    );

    expect(find.text('Prepare weekly report'), findsOneWidget);
    expect(find.text('Send recap to leadership'), findsNothing);
    expect(find.text('Open this task to start writing rich notes.'), findsNothing);
    expect(find.text('Locked Content'), findsNothing);
  });

  testWidgets('task shake animation activates and settles cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TaskCardShake(
              taskId: 'demo-task',
              isShaking: true,
              child: const SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 220));

    final shakingTransform = tester.widget<Transform>(
      find.byKey(TaskManagementScreen.taskShakeKey('demo-task')),
    );
    expect(shakingTransform.transform.storage[12].abs(), greaterThan(0.1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TaskCardShake(
              taskId: 'demo-task',
              isShaking: false,
              child: const SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final settledTransform = tester.widget<Transform>(
      find.byKey(TaskManagementScreen.taskShakeKey('demo-task')),
    );
    expect(settledTransform.transform.storage[12].abs(), lessThan(0.1));
  });
}

TaskItem buildTask({
  required String id,
  required String title,
  required TaskPriority priority,
  required String categoryId,
  String? description,
  bool isCompleted = false,
}) {
  final now = DateTime(2026, 4, 13, 9);
  return TaskItem(
    id: id,
    title: title,
    description: description,
    priority: priority,
    categoryId: categoryId,
    standaloneCategoryId: categoryId,
    createdAt: now,
    updatedAt: now,
    isCompleted: isCompleted,
  );
}

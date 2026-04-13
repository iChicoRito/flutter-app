import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/core/services/display_name_store.dart';
import 'package:flutter_app/core/services/onboarding_status_store.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/splash/presentation/splash_screen.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_editor_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';

void main() {
  late FakeOnboardingStatusStore onboardingStatusStore;
  late FakeDisplayNameStore displayNameStore;
  late InMemoryTaskRepository taskRepository;

  setUp(() {
    onboardingStatusStore = FakeOnboardingStatusStore();
    displayNameStore = FakeDisplayNameStore();
    taskRepository = InMemoryTaskRepository();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      MyApp(
        onboardingStatusStore: onboardingStatusStore,
        displayNameStore: displayNameStore,
        taskRepository: taskRepository,
      ),
    );
  }

  Future<void> openDashboard(WidgetTester tester) async {
    onboardingStatusStore.completed = true;
    displayNameStore.displayName = 'Mark';
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('shows splash screen first', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byKey(SplashScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.markerKey), findsNothing);
    expect(find.text('Flutter App'), findsOneWidget);
  });

  testWidgets('navigates to onboarding after five seconds on first launch', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(SplashScreen.markerKey), findsNothing);
    expect(find.byKey(OnboardingScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.homeTabKey), findsNothing);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('completing onboarding writes the flag and opens dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(onboardingStatusStore.completed, isTrue);
    expect(find.byKey(DashboardScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.namePromptKey), findsOneWidget);

    await tester.enterText(find.byKey(DashboardScreen.nameFieldKey), 'Mark');
    await tester.pump();
    await tester.tap(find.byKey(DashboardScreen.nameSaveButtonKey));
    await tester.pumpAndSettle();

    expect(displayNameStore.displayName, 'Mark');
    expect(find.byKey(DashboardScreen.welcomeScreenKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.welcomeButtonKey), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.welcomeButtonKey), findsOneWidget);

    await tester.tap(find.byKey(DashboardScreen.welcomeButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.welcomeScreenKey), findsNothing);
    expect(find.byKey(DashboardScreen.homeTabKey), findsOneWidget);
    expect(find.text('Hi, Mark'), findsOneWidget);
  });

  testWidgets('dashboard asks for a name when none is saved', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.namePromptKey), findsOneWidget);

    await tester.enterText(find.byKey(DashboardScreen.nameFieldKey), 'Jamie');
    await tester.pump();
    await tester.tap(find.byKey(DashboardScreen.nameSaveButtonKey));
    await tester.pumpAndSettle();

    expect(displayNameStore.displayName, 'Jamie');
    expect(find.byKey(DashboardScreen.namePromptKey), findsNothing);
    expect(find.byKey(DashboardScreen.welcomeScreenKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DashboardScreen.welcomeButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Jamie'), findsOneWidget);
  });

  testWidgets('dashboard home still shows task-first overview content', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pending'), findsAtLeastNWidgets(1));
    expect(find.text('Completed'), findsAtLeastNWidgets(1));
    expect(find.text('Overdue'), findsAtLeastNWidgets(1));
    expect(find.byKey(DashboardScreen.homeTabKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.addTaskButtonKey), findsOneWidget);
  });

  testWidgets('tasks tab replaces wallet and shows empty state', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    expect(find.text('Wallet'), findsNothing);
    expect(find.text('Tasks'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.tasksTabKey), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.markerKey), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.emptyStateKey), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(
      find.byKey(TaskManagementScreen.categoryDropdownKey),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.priorityDropdownKey),
      findsOneWidget,
    );
  });

  testWidgets('task module supports add edit search complete and delete', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TaskManagementScreen.addTaskFabKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TaskEditorScreen.titleFieldKey),
      'Prepare weekly report',
    );
    await tester.enterText(
      find.byKey(TaskEditorScreen.descriptionFieldKey),
      'Review metrics and send the summary.',
    );
    expect(find.byKey(TaskEditorScreen.startDateButtonKey), findsOneWidget);
    expect(find.byKey(TaskEditorScreen.endDateButtonKey), findsOneWidget);
    await tester.tap(find.byKey(TaskEditorScreen.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Prepare weekly report'), findsOneWidget);

    final createdTaskId = (await taskRepository.getTasks()).single.id;

    await tester.ensureVisible(
      find.byKey(TaskManagementScreen.taskMenuButtonKey(createdTaskId)),
    );
    await tester.tap(
      find.byKey(TaskManagementScreen.taskMenuButtonKey(createdTaskId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(TaskManagementScreen.taskMenuActionKey(createdTaskId, 'edit')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TaskEditorScreen.titleFieldKey),
      'Prepare monthly report',
    );
    await tester.tap(find.byKey(TaskEditorScreen.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Prepare monthly report'), findsOneWidget);

    await tester.longPress(
      find.byKey(TaskManagementScreen.taskTileKey(createdTaskId)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(TaskManagementScreen.taskToggleKey(createdTaskId)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TaskManagementScreen.searchFieldKey),
      'monthly',
    );
    await tester.pumpAndSettle();
    expect(find.text('Prepare monthly report'), findsOneWidget);

    await tester.enterText(
      find.byKey(TaskManagementScreen.searchFieldKey),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(TaskManagementScreen.emptyStateKey), findsOneWidget);

    await tester.enterText(find.byKey(TaskManagementScreen.searchFieldKey), '');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(TaskManagementScreen.taskMenuButtonKey(createdTaskId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        TaskManagementScreen.taskMenuActionKey(createdTaskId, 'delete'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare monthly report'), findsNothing);
    expect(find.byKey(TaskManagementScreen.emptyStateKey), findsOneWidget);
  });

  testWidgets('task module filters by category and priority', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    taskRepository = InMemoryTaskRepository(
      tasks: [
        TaskItem(
          id: 'work-task',
          title: 'Submit project brief',
          priority: TaskPriority.high,
          categoryId: 'work',
          createdAt: now,
          updatedAt: now,
        ),
        TaskItem(
          id: 'personal-task',
          title: 'Book annual checkup',
          priority: TaskPriority.medium,
          categoryId: 'personal',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
          endDate: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(TaskManagementScreen.categoryFilterKey('work')),
    );
    await tester.tap(
      find.byKey(TaskManagementScreen.categoryFilterKey('work')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Submit project brief'), findsOneWidget);
    expect(find.text('Book annual checkup'), findsNothing);

    await tester.tap(find.byKey(TaskManagementScreen.priorityDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(
            TaskManagementScreen.priorityFilterKey(TaskPriority.medium.name),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Submit project brief'), findsNothing);
    expect(find.text('Book annual checkup'), findsNothing);

    await tester.ensureVisible(
      find.byKey(TaskManagementScreen.allCategoriesKey),
    );
    await tester.tap(find.byKey(TaskManagementScreen.allCategoriesKey));
    await tester.pumpAndSettle();
    expect(find.text('Book annual checkup'), findsOneWidget);
  });

  testWidgets('task editor shows saved schedule values for editing', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'scheduled-task',
      title: 'Run workshop',
      description: 'Finalize the prep list.',
      priority: TaskPriority.high,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
      startDate: DateTime(2026, 4, 15),
      startMinutes: 9 * 60,
      endDate: DateTime(2026, 4, 15),
      endMinutes: 11 * 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TaskEditorScreen(
          repository: taskRepository,
          categories: await taskRepository.getCategories(),
          initialTask: task,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apr 15, 2026'), findsNWidgets(2));
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
  });

  testWidgets('task editor blocks save when end schedule is before start', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 4, 13, 9);
    final task = TaskItem(
      id: 'invalid-schedule',
      title: 'Broken schedule',
      priority: TaskPriority.medium,
      categoryId: 'work',
      createdAt: now,
      updatedAt: now,
      startDate: DateTime(2026, 4, 15),
      startMinutes: 10 * 60,
      endDate: DateTime(2026, 4, 15),
      endMinutes: 9 * 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TaskEditorScreen(
          repository: taskRepository,
          categories: await taskRepository.getCategories(),
          initialTask: task,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TaskEditorScreen.saveButtonKey));
    await tester.pump();

    expect(
      find.text(
        'End schedule must be later than or equal to the start schedule.',
      ),
      findsWidgets,
    );
  });

  testWidgets('create category dialog uses structured modal sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TaskEditorScreen(
          repository: taskRepository,
          categories: await taskRepository.getCategories(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TaskEditorScreen.addCategoryButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Create Category'), findsOneWidget);
    expect(find.text('Category Name'), findsOneWidget);
    expect(find.text('Icon'), findsOneWidget);
    expect(find.text('Color Selection'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
  });
}

class FakeOnboardingStatusStore implements OnboardingStatusStore {
  bool completed = false;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
  }
}

class FakeDisplayNameStore implements DisplayNameStore {
  String? displayName;

  @override
  Future<String?> readDisplayName() async => displayName;

  @override
  Future<void> saveDisplayName(String value) async {
    displayName = value;
  }
}

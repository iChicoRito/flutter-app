import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/core/services/display_name_store.dart';
import 'package:flutter_app/core/services/onboarding_status_store.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_app/shared/widgets/first_run_handoff_dialogs.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_editor_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
    await tester.pumpAndSettle();
  }

  Future<void> createTaskThroughUi(
    WidgetTester tester, {
    required String title,
    String? description,
  }) async {
    await tester.tap(find.byKey(TaskManagementScreen.addTaskFabKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TaskManagementScreen.createTitleFieldKey),
      title,
    );
    if (description != null) {
      await tester.enterText(
        find.byKey(TaskManagementScreen.createDescriptionFieldKey),
        description,
      );
    }
    await tester.tap(find.byKey(TaskManagementScreen.createSubmitButtonKey));
    await tester.pumpAndSettle();
  }

  Widget wrapWithMaterial(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: child,
    );
  }

  testWidgets('opens onboarding immediately on first launch', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.markerKey), findsNothing);
    expect(find.text('Welcome to Remindly'), findsOneWidget);
  });

  testWidgets('opens dashboard directly for returning users', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;
    displayNameStore.displayName = 'Mark';
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.markerKey), findsNothing);
    expect(find.byKey(DashboardScreen.markerKey), findsOneWidget);
    expect(find.text('Hi, Mark'), findsOneWidget);
  });

  testWidgets('onboarding shows the new Remindly copy and matching icons', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Remindly'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Create Tasks Easily'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Never Miss a Reminder'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Stay Focused & Productive'), findsOneWidget);
    expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
  });

  testWidgets(
    'completing onboarding opens dashboard and keeps the dashboard prompt flow',
    (WidgetTester tester) async {
      await pumpApp(tester);
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
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(DashboardScreen.welcomeButtonKey), findsOneWidget);
      await tester.tap(find.byKey(DashboardScreen.welcomeButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(DashboardScreen.markerKey), findsOneWidget);
      expect(find.text('Hi, Mark'), findsOneWidget);
    },
  );

  testWidgets('dashboard asks for a name when none is saved', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.namePromptKey), findsOneWidget);

    await tester.enterText(find.byKey(DashboardScreen.nameFieldKey), 'Jamie');
    await tester.pump();
    await tester.tap(find.byKey(DashboardScreen.nameSaveButtonKey));
    await tester.pumpAndSettle();

    expect(displayNameStore.displayName, 'Jamie');
    expect(find.byKey(DashboardScreen.welcomeScreenKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.welcomeButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Jamie'), findsOneWidget);
  });

  testWidgets('welcome modal CTA uses a full-width rounded rectangle style', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      wrapWithMaterial(const WelcomeHandoffDialog(displayName: 'Mark')),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final buttonFinder = find.byKey(DashboardScreen.welcomeButtonKey);
    final buttonSize = tester.getSize(buttonFinder);
    final dialogSize = tester.getSize(
      find.byKey(DashboardScreen.welcomeScreenKey),
    );
    final button = tester.widget<FilledButton>(buttonFinder);
    final shape = button.style?.shape?.resolve(<WidgetState>{});

    expect(buttonSize.width, greaterThan(280));
    expect(buttonSize.width, lessThan(dialogSize.width));
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(12),
    );
  });

  testWidgets('dashboard home shows live task summary content', (
    WidgetTester tester,
  ) async {
    taskRepository = InMemoryTaskRepository(
      tasks: [
        buildTask(
          id: 'work-task',
          title: 'Submit project brief',
          priority: TaskPriority.high,
          categoryId: 'work',
          noteText: 'Scope and milestones',
        ),
      ],
    );

    await openDashboard(tester);

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.byKey(DashboardScreen.addTaskButtonKey), findsOneWidget);
    expect(find.text('Submit project brief'), findsOneWidget);
  });

  testWidgets('creating a task redirects straight into the rich editor', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await createTaskThroughUi(tester, title: 'Prepare weekly report');

    expect(find.byKey(TaskEditorScreen.markerKey), findsOneWidget);
    expect(find.text('Task Notes'), findsOneWidget);
    expect(find.text('Prepare weekly report'), findsWidgets);
  });

  testWidgets('task card shows the short creation description', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await createTaskThroughUi(
      tester,
      title: 'Prepare weekly report',
      description: 'Send recap to leadership',
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Send recap to leadership'), findsOneWidget);
  });

  testWidgets(
    'task card shows description and actual note preview separately',
    (WidgetTester tester) async {
      taskRepository = InMemoryTaskRepository(
        tasks: [
          buildTask(
            id: 'preview-task',
            title: 'Prepare weekly report',
            priority: TaskPriority.medium,
            categoryId: 'work',
            noteText: 'Full meeting notes for leadership sync',
          ).copyWith(description: 'Send recap to leadership'),
        ],
      );

      await openDashboard(tester);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Send recap to leadership'), findsOneWidget);
      expect(
        find.text('Full meeting notes for leadership sync'),
        findsOneWidget,
      );
    },
  );

  testWidgets('creation description stays separate from the note body', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await createTaskThroughUi(
      tester,
      title: 'Prepare weekly report',
      description: 'Send recap to leadership',
    );

    final createdTask = (await taskRepository.getTasks()).single;
    expect(createdTask.description, 'Send recap to leadership');
    expect(createdTask.notePlainText, isNull);
  });

  testWidgets(
    'editor autosaves title changes and reopens with persisted data',
    (WidgetTester tester) async {
      await openDashboard(tester);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await createTaskThroughUi(tester, title: 'Prepare weekly report');

      await tester.tap(find.byKey(TaskEditorScreen.autosaveStatusKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorScreen.editDetailsButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(TaskEditorScreen.titleFieldKey),
        'Prepare monthly report',
      );
      await tester.tap(find.byKey(TaskEditorScreen.saveButtonKey));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.byKey(TaskEditorScreen.autosaveStatusKey), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Prepare monthly report'), findsOneWidget);

      await tester.tap(find.text('Prepare monthly report'));
      await tester.pumpAndSettle();

      expect(find.text('Prepare monthly report'), findsOneWidget);
    },
  );

  testWidgets('editor metadata changes autosave and update timestamps', (
    WidgetTester tester,
  ) async {
    final task = buildTask(
      id: 'metadata-task',
      title: 'Run workshop',
      priority: TaskPriority.medium,
      categoryId: 'work',
    );
    taskRepository = InMemoryTaskRepository(tasks: [task]);

    await tester.pumpWidget(
      wrapWithMaterial(
        TaskEditorScreen(repository: taskRepository, taskId: task.id),
      ),
    );
    await tester.pumpAndSettle();

    final beforeUpdate = (await taskRepository.getTaskById(task.id))!.updatedAt;

    await tester.tap(find.byKey(TaskEditorScreen.autosaveStatusKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskEditorScreen.editDetailsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskEditorScreen.priorityFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-editor-priority-urgent')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskEditorScreen.saveButtonKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final updatedTask = (await taskRepository.getTaskById(task.id))!;
    expect(updatedTask.priority, TaskPriority.urgent);
    expect(updatedTask.updatedAt.isAfter(beforeUpdate), isTrue);
  });

  testWidgets('task list search matches note preview text', (
    WidgetTester tester,
  ) async {
    taskRepository = InMemoryTaskRepository(
      tasks: [
        buildTask(
          id: 'search-task',
          title: 'Planning session',
          priority: TaskPriority.high,
          categoryId: 'work',
          noteText: 'Quarterly planning notes',
        ),
      ],
    );

    await openDashboard(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TaskManagementScreen.searchFieldKey),
      'planning notes',
    );
    await tester.pumpAndSettle();

    expect(find.text('Planning session'), findsOneWidget);
  });

  testWidgets('task editor opens from both tasks tab and dashboard home', (
    WidgetTester tester,
  ) async {
    final task = buildTask(
      id: 'shared-open',
      title: 'Outline launch checklist',
      priority: TaskPriority.medium,
      categoryId: 'work',
      noteText: 'Draft agenda',
    );
    taskRepository = InMemoryTaskRepository(tasks: [task]);

    await openDashboard(tester);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outline launch checklist'));
    await tester.pumpAndSettle();
    expect(find.byKey(TaskEditorScreen.markerKey), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outline launch checklist'));
    await tester.pumpAndSettle();

    expect(find.byKey(TaskEditorScreen.markerKey), findsOneWidget);
  });

  testWidgets('dashboard completion toggles stay in sync with tasks tab', (
    WidgetTester tester,
  ) async {
    final task = buildTask(
      id: 'sync-task',
      title: 'Review analytics dashboard',
      priority: TaskPriority.medium,
      categoryId: 'work',
    );
    final secondTask = buildTask(
      id: 'sync-task-2',
      title: 'Ship release notes',
      priority: TaskPriority.low,
      categoryId: 'work',
    );
    taskRepository = InMemoryTaskRepository(tasks: [task, secondTask]);

    await openDashboard(tester);

    await tester.tap(find.byKey(DashboardScreen.taskToggleKey(task.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(TaskManagementScreen.taskTileKey(task.id)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.taskToggleKey(secondTask.id)),
      findsOneWidget,
    );

    final checkbox = tester.widget<Checkbox>(
      find.byKey(TaskManagementScreen.taskToggleKey(task.id)),
    );
    expect(checkbox.value, isTrue);
  });

  testWidgets('selection mode clears on outside tap and back press', (
    WidgetTester tester,
  ) async {
    final task = buildTask(
      id: 'selection-task',
      title: 'Finalize budget proposal',
      priority: TaskPriority.medium,
      categoryId: 'work',
    );
    final secondTask = buildTask(
      id: 'selection-task-2',
      title: 'Confirm rollout timeline',
      priority: TaskPriority.high,
      categoryId: 'work',
    );
    taskRepository = InMemoryTaskRepository(tasks: [task, secondTask]);

    await openDashboard(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(TaskManagementScreen.taskTileKey(task.id)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.taskToggleKey(task.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.taskToggleKey(secondTask.id)),
      findsOneWidget,
    );

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.taskToggleKey(task.id)),
      findsNothing,
    );

    await tester.longPress(
      find.byKey(TaskManagementScreen.taskTileKey(task.id)),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(TaskManagementScreen.markerKey), findsOneWidget);
    expect(
      find.byKey(TaskManagementScreen.taskToggleKey(task.id)),
      findsNothing,
    );
  });
}

TaskItem buildTask({
  required String id,
  required String title,
  required TaskPriority priority,
  required String categoryId,
  String? noteText,
}) {
  final now = DateTime(2026, 4, 13, 9);
  return TaskItem(
    id: id,
    title: title,
    priority: priority,
    categoryId: categoryId,
    createdAt: now,
    updatedAt: now,
    noteDocumentJson: buildPlainTextNoteDocumentJson(noteText),
    notePlainText: noteText,
  );
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

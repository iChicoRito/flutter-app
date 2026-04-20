import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/core/services/display_name_store.dart';
import 'package:flutter_app/core/services/onboarding_status_store.dart';
import 'package:flutter_app/core/vault/vault_models.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/spaces/domain/task_space.dart';
import 'package:flutter_app/features/spaces/presentation/spaces_page.dart';
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

  testWidgets('dashboard home header shows saved profile picture', (
    WidgetTester tester,
  ) async {
    displayNameStore.profileImageData = base64Encode(_transparentPngBytes);

    await openDashboard(tester);

    expect(find.text('Hi, Mark'), findsOneWidget);
    expect(find.byKey(DashboardScreen.homeAvatarImageKey), findsOneWidget);
  });

  testWidgets('profile tab shows dynamic stats and static account sections', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 4, 13, 9);
    const vaultConfig = VaultConfig(
      isEnabled: true,
      method: VaultMethod.password,
      secretKeyRef: 'secret',
    );
    taskRepository = InMemoryTaskRepository(
      tasks: [
        buildTask(
          id: 'completed-task',
          title: 'Completed profile task',
          priority: TaskPriority.high,
          categoryId: 'work',
          isCompleted: true,
        ),
        buildTask(
          id: 'pending-task',
          title: 'Pending profile task',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ),
        buildTask(
          id: 'vault-task',
          title: 'Vault profile task',
          priority: TaskPriority.low,
          categoryId: 'work',
          vaultConfig: vaultConfig,
        ),
        buildTask(
          id: 'overdue-task',
          title: 'Overdue profile task',
          priority: TaskPriority.urgent,
          categoryId: 'work',
          endDate: DateTime(2026, 4, 12),
          endMinutes: 8 * 60,
        ),
      ],
      spaces: [
        TaskSpace(
          id: 'vault-space',
          name: 'Secure Space',
          description: 'Protected profile space',
          categoryId: 'work',
          colorValue: Colors.blue.toARGB32(),
          createdAt: now,
          updatedAt: now,
          vaultConfig: vaultConfig,
        ),
      ],
    );

    await openDashboard(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.profileTabKey), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Manage and update your profile'), findsOneWidget);
    expect(find.text('Mark'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(DashboardScreen.profileCompletedStatKey),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(DashboardScreen.profilePendingStatKey),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(DashboardScreen.profileOverdueStatKey),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(DashboardScreen.profileVaultStatKey),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(DashboardScreen.profileUserRowKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.profileVaultRowKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.profileRecoveryRowKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.profileArchivesRowKey), findsOneWidget);
  });

  testWidgets('profile tab shows a saved profile picture', (
    WidgetTester tester,
  ) async {
    displayNameStore.profileImageData = base64Encode(_transparentPngBytes);

    await openDashboard(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byKey(DashboardScreen.profileAvatarImageKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.profileImageButtonKey), findsOneWidget);
  });

  testWidgets('profile picture upload asks before opening photo picker', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.profileImageButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(DashboardScreen.profileImagePermissionDialogKey),
      findsOneWidget,
    );
    expect(find.text('Choose Profile Picture'), findsOneWidget);
    expect(
      find.textContaining('only uses the photo you select'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(DashboardScreen.profileImagePermissionDialogKey),
      findsNothing,
    );
  });

  testWidgets('profile name can be changed from the bottom sheet', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.profileUserRowKey));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile Name'), findsOneWidget);

    await tester.enterText(
      find.byKey(DashboardScreen.profileNameFieldKey),
      'Jamie Rivera',
    );
    await tester.tap(find.byKey(DashboardScreen.profileNameSaveButtonKey));
    await tester.pumpAndSettle();

    expect(displayNameStore.displayName, 'Jamie Rivera');
    expect(find.text('Jamie Rivera'), findsOneWidget);
    expect(find.text('Edit Profile Name'), findsNothing);
  });

  testWidgets('static profile rows do not open the name editor', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(DashboardScreen.profileIdentityKey));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile Name'), findsNothing);

    await tester.tap(find.byKey(DashboardScreen.profileVaultRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.profileRecoveryRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.profileArchivesRowKey));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile Name'), findsNothing);

    await tester.tap(find.byKey(DashboardScreen.profileUserRowKey));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile Name'), findsOneWidget);
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

  testWidgets('task filters can show only vault-protected tasks', (
    WidgetTester tester,
  ) async {
    const vaultConfig = VaultConfig(
      isEnabled: true,
      method: VaultMethod.password,
      secretKeyRef: 'secret',
    );
    final now = DateTime(2026, 4, 13, 9);
    taskRepository = InMemoryTaskRepository(
      tasks: [
        buildTask(
          id: 'direct-vault-task',
          title: 'Direct Vault Task',
          priority: TaskPriority.high,
          categoryId: 'work',
          vaultConfig: vaultConfig,
        ),
        buildTask(
          id: 'space-vault-task',
          title: 'Inherited Vault Task',
          priority: TaskPriority.medium,
          categoryId: 'work',
        ).copyWith(spaceId: 'vault-space'),
        buildTask(
          id: 'plain-task',
          title: 'Plain Task',
          priority: TaskPriority.low,
          categoryId: 'work',
        ),
      ],
      spaces: [
        TaskSpace(
          id: 'vault-space',
          name: 'Locked Space',
          description: 'Protected space',
          categoryId: 'work',
          colorValue: Colors.blue.toARGB32(),
          createdAt: now,
          updatedAt: now,
          vaultConfig: vaultConfig,
        ),
      ],
    );

    await openDashboard(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskManagementScreen.vaultDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(TaskManagementScreen.vaultFilterKey('vaultOnly')).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Direct Vault Task'), findsOneWidget);
    expect(find.text('Inherited Vault Task'), findsOneWidget);
    expect(find.text('Plain Task'), findsNothing);
  });

  testWidgets('spaces filters can show only non-vault spaces', (
    WidgetTester tester,
  ) async {
    const vaultConfig = VaultConfig(
      isEnabled: true,
      method: VaultMethod.password,
      secretKeyRef: 'secret',
    );
    final now = DateTime(2026, 4, 13, 9);
    taskRepository = InMemoryTaskRepository(
      spaces: [
        TaskSpace(
          id: 'vault-space',
          name: 'Vault Space',
          description: 'Protected',
          categoryId: 'work',
          colorValue: Colors.blue.toARGB32(),
          createdAt: now,
          updatedAt: now,
          vaultConfig: vaultConfig,
        ),
        TaskSpace(
          id: 'plain-space',
          name: 'Plain Space',
          description: 'Open',
          categoryId: 'work',
          colorValue: Colors.green.toARGB32(),
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await openDashboard(tester);
    await tester.tap(find.text('Spaces'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SpacesPage.vaultDropdownKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(SpacesPage.vaultFilterKey('nonVaultOnly')).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Plain Space'), findsWidgets);
    expect(find.text('Vault Space'), findsNothing);
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
  bool isCompleted = false,
  VaultConfig? vaultConfig,
  DateTime? endDate,
  int? endMinutes,
}) {
  final now = DateTime(2026, 4, 13, 9);
  return TaskItem(
    id: id,
    title: title,
    priority: priority,
    categoryId: categoryId,
    createdAt: now,
    updatedAt: now,
    isCompleted: isCompleted,
    vaultConfig: vaultConfig,
    endDate: endDate,
    endMinutes: endMinutes,
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
  String? profileImageData;

  @override
  Future<String?> readDisplayName() async => displayName;

  @override
  Future<void> saveDisplayName(String value) async {
    displayName = value;
  }

  @override
  Future<String?> readProfileImageData() async => profileImageData;

  @override
  Future<void> saveProfileImageData(String? value) async {
    profileImageData = value;
  }
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

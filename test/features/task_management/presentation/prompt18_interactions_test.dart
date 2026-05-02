import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/core/services/display_name_store.dart';
import 'package:flutter_app/core/services/onboarding_status_store.dart';
import 'package:flutter_app/core/services/task_data_refresh_scope.dart';
import 'package:flutter_app/core/services/task_reminder_scope.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/services/vault_service_scope.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_editor_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_controller.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';

void main() {
  Future<void> pumpTaskManagement(
    WidgetTester tester, {
    required InMemoryTaskRepository repository,
  }) async {
    final controller = TaskManagementController(repository);
    await controller.load();

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
                FlutterQuillLocalizations.delegate,
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

    final welcomeButton = find.byKey(DashboardScreen.welcomeButtonKey);
    if (welcomeButton.evaluate().isNotEmpty) {
      await tester.tap(welcomeButton);
      await tester.pumpAndSettle();
    }
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required InMemoryTaskRepository repository,
  }) async {
    final onboardingStatusStore = _FakeOnboardingStatusStore()
      ..completed = true;
    await tester.pumpWidget(
      MyApp(
        onboardingStatusStore: onboardingStatusStore,
        displayNameStore: _FakeDisplayNameStore(),
        taskRepository: repository,
        dashboardClock: () => DateTime(2026, 4, 13, 9),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    required InMemoryTaskRepository repository,
    required String taskId,
  }) async {
    await tester.pumpWidget(
      TaskDataRefreshScope(
        controller: TaskDataRefreshController(),
        child: VaultServiceScope(
          vaultService: const NoopVaultService(),
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            home: TaskEditorScreen(
              repository: repository,
              taskId: taskId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('task card menu shows pin and export actions', (tester) async {
    final repository = InMemoryTaskRepository(
      seedDefaults: false,
      tasks: [
        _buildTask(
          id: 'task-1',
          title: 'Prepare roadmap',
        ),
      ],
    );

    await pumpTaskManagement(tester, repository: repository);

    await tester.tap(find.byKey(TaskManagementScreen.taskMenuButtonKey('task-1')));
    await tester.pumpAndSettle();

    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('dashboard task status rows open action menu on long press', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository(
      tasks: [
        _buildTask(
          id: 'home-task',
          title: 'Submit project brief',
        ),
      ],
    );

    await pumpDashboard(tester, repository: repository);
    await tester.dragUntilVisible(
      find.text('Submit project brief'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Submit project brief'));
    await tester.pumpAndSettle();

    expect(find.text('Mark as Complete'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('editor shows attachment and richer formatting actions', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository(
      seedDefaults: false,
      tasks: [
        _buildTask(
          id: 'editor-task',
          title: 'Draft note',
        ),
      ],
    );

    await pumpEditor(tester, repository: repository, taskId: 'editor-task');

    expect(find.byKey(TaskEditorScreen.attachImageButtonKey), findsOneWidget);
    expect(find.byKey(TaskEditorScreen.attachFileButtonKey), findsOneWidget);
    expect(find.byKey(TaskEditorScreen.highlightButtonKey), findsOneWidget);
  });
}

TaskItem _buildTask({
  required String id,
  required String title,
}) {
  final now = DateTime(2026, 4, 13, 9);
  return TaskItem(
    id: id,
    title: title,
    priority: TaskPriority.medium,
    categoryId: 'work',
    standaloneCategoryId: 'work',
    createdAt: now,
    updatedAt: now,
    noteDocumentJson: buildPlainTextNoteDocumentJson('note'),
    notePlainText: 'note',
  );
}

class _FakeDisplayNameStore implements DisplayNameStore {
  @override
  Future<String?> readDisplayName() async => 'Mark';

  @override
  Future<String?> readProfileImageData() async => null;

  @override
  Future<void> saveDisplayName(String value) async {}

  @override
  Future<void> saveProfileImageData(String? value) async {}
}

class _FakeOnboardingStatusStore implements OnboardingStatusStore {
  bool completed = false;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
  }
}

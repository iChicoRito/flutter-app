import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_app/core/services/task_data_refresh_scope.dart';
import 'package:flutter_app/core/services/task_reminder_scope.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/services/vault_service_scope.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_controller.dart';
import 'package:flutter_app/features/task_management/presentation/task_editor_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';

void main() {
  late InMemoryTaskRepository repository;
  late TaskManagementController controller;

  setUp(() async {
    repository = InMemoryTaskRepository(
      tasks: [
        _buildTask(
          id: 'science',
          title: 'Science Assessment',
          description: 'Prepare for quiz',
          categoryId: 'school',
          startDate: DateTime(2026, 4, 20),
          startMinutes: 8 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        ),
        _buildTask(
          id: 'family',
          title: 'Dinner with Family',
          description: 'Evening meal',
          categoryId: 'personal',
          startDate: DateTime(2026, 4, 20),
          startMinutes: 19 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 21 * 60,
        ),
      ],
      seedDefaults: true,
    );
    controller = TaskManagementController(repository);
    await controller.load();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
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
  }

  testWidgets('segmented switcher toggles between tasks list and calendar', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(TaskManagementScreen.tasksSegmentKey), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.calendarSegmentKey), findsOneWidget);
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.byKey(TaskManagementScreen.calendarViewKey), findsNothing);

    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.byKey(TaskManagementScreen.calendarViewKey), findsOneWidget);
    expect(find.text('View and manage your scheduled tasks'), findsOneWidget);
  });

  testWidgets('calendar view renders filters date rail timeline and CTA', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.calendarMonthDropdownKey),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarStatusChipKey('all')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarStatusChipKey('completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarDateKey('2026-04-20')),
      findsOneWidget,
    );
    expect(find.text('April 2026'), findsOneWidget);
    expect(find.text('Science Assessment'), findsOneWidget);
    expect(find.text('Dinner with Family'), findsOneWidget);
    expect(
      find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
      findsOneWidget,
    );
  });

  testWidgets('tapping a calendar task opens the rich editor page', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Science Assessment'));
    await tester.pumpAndSettle();

    expect(find.byKey(TaskEditorScreen.markerKey), findsOneWidget);
  });

  testWidgets(
    'schedule sheet validates range swap and creates a task in the calendar timeline',
    (WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(TaskManagementScreen.calendarSheetKey), findsOneWidget);
      expect(
        find.byKey(TaskManagementScreen.calendarSheetTitleFieldKey),
        findsOneWidget,
      );
      expect(
        find.byKey(TaskManagementScreen.calendarSheetCategoryFieldKey),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetTitleFieldKey),
        'Plan launch',
      );
      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'This description is definitely too long',
      );
      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSubmitButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Description must be 20 characters or fewer.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'Launch prep',
      );
      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSwapButtonKey),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSubmitButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.text('End time must be after start time.'), findsOneWidget);

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSwapButtonKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetCategoryFieldKey),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          TaskManagementScreen.calendarSheetCategoryOptionKey('personal'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSubmitButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(TaskManagementScreen.calendarSheetKey), findsNothing);
      expect(find.text('Plan launch'), findsOneWidget);

      final tasks = await repository.getTasks();
      final created = tasks.firstWhere((task) => task.title == 'Plan launch');
      expect(created.startDateTime, DateTime(2026, 4, 20, 9));
      expect(created.endDateTime, DateTime(2026, 4, 20, 11));
      expect(created.categoryId, 'personal');
    },
  );
}

TaskItem _buildTask({
  required String id,
  required String title,
  required String categoryId,
  required DateTime startDate,
  required int startMinutes,
  required DateTime endDate,
  required int endMinutes,
  String? description,
}) {
  final createdAt = DateTime(2026, 4, 13, 9);
  return TaskItem(
    id: id,
    title: title,
    description: description,
    priority: TaskPriority.medium,
    categoryId: categoryId,
    standaloneCategoryId: categoryId,
    createdAt: createdAt,
    updatedAt: createdAt,
    startDate: startDate,
    startMinutes: startMinutes,
    endDate: endDate,
    endMinutes: endMinutes,
    noteDocumentJson: buildPlainTextNoteDocumentJson(description),
    notePlainText: description,
  );
}

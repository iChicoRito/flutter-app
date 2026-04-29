import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_app/core/theme/app_design_tokens.dart';
import 'package:flutter_app/core/services/task_data_refresh_scope.dart';
import 'package:flutter_app/core/services/task_reminder_scope.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/services/vault_service_scope.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/data/task_note_codec.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_management/presentation/task_calendar_view.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_controller.dart';
import 'package:flutter_app/features/task_management/presentation/task_editor_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_screen.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_ui.dart';

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

  Future<void> pumpScreenWithState(
    WidgetTester tester, {
    required InMemoryTaskRepository repository,
    required TaskManagementController controller,
  }) async {
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

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpScreenWithState(
      tester,
      repository: repository,
      controller: controller,
    );
  }

  Future<void> openCalendarAndSelectDate(
    WidgetTester tester,
    String keyValue,
  ) async {
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();
    final dateFinder = find.byKey(
      TaskManagementScreen.calendarDateKey(keyValue),
    );
    await tester.ensureVisible(dateFinder);
    await tester.pumpAndSettle();
    await tester.tap(dateFinder);
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
    await openCalendarAndSelectDate(tester, '2026-04-20');

    expect(
      find.byKey(TaskManagementScreen.calendarStatusChipKey('all')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarStatusChipKey('completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarDateKey('2026-04-27')),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarDateKey('2026-04-20')),
      findsOneWidget,
    );
    expect(find.text('April 2026'), findsOneWidget);
    expect(find.text('Science Assessment'), findsOneWidget);
    expect(find.text('Dinner with Family'), findsOneWidget);
    expect(find.text('8AM'), findsOneWidget);
    expect(find.text('11AM'), findsOneWidget);
    expect(find.text('08:00 AM'), findsNothing);
    expect(find.text('11:00 AM'), findsNothing);
    expect(
      find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarTimelineScrollKey),
      findsOneWidget,
    );
  });

  testWidgets('calendar opens with today selected by default', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    final todayCard = find.byKey(
      TaskManagementScreen.calendarDateKey('2026-04-29'),
    );
    final selectedContainer = find.descendant(
      of: todayCard,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.blue100,
      ),
    );

    expect(selectedContainer, findsOneWidget);
    final todayRect = tester.getRect(todayCard);
    expect(todayRect.left, greaterThanOrEqualTo(0));
    expect(todayRect.right, lessThanOrEqualTo(430));
  });

  testWidgets('calendar month header opens dropdown picker and changes month', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    final downArrow = find.descendant(
      of: find.byKey(TaskManagementScreen.calendarMonthDropdownKey),
      matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
    );
    expect(downArrow, findsOneWidget);

    await tester.tap(find.byKey(TaskManagementScreen.calendarMonthDropdownKey));
    await tester.pumpAndSettle();

    final upArrow = find.descendant(
      of: find.byKey(TaskManagementScreen.calendarMonthDropdownKey),
      matching: find.byIcon(Icons.keyboard_arrow_up_rounded),
    );
    expect(upArrow, findsOneWidget);
    expect(find.text('Select month'), findsNothing);

    await tester.tap(find.text('May'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(TaskManagementScreen.calendarMonthDropdownKey),
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('May 2026'), findsOneWidget);
    expect(find.text('Your scheduled tasks for month of may'), findsNothing);
  });

  testWidgets('tapping a calendar task opens read-only details sheet', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await openCalendarAndSelectDate(tester, '2026-04-20');

    await tester.tap(find.text('Science Assessment'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
      findsOneWidget,
    );
    expect(find.byKey(TaskEditorScreen.markerKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
        matching: find.text('Prepare for quiz'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
        matching: find.text('Category'),
      ),
      findsOneWidget,
    );
    expect(find.text('Apr 20, 8:00 AM - 11:00 AM'), findsOneWidget);
    expect(
      find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarDetailsCompleteButtonKey),
      findsOneWidget,
    );
    expect(find.text('Mark As Completed'), findsOneWidget);
    final closeRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
    );
    final actionRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarDetailsCompleteButtonKey),
    );
    expect(closeRect.left, actionRect.left);
    expect(closeRect.width, actionRect.width);
    expect(actionRect.top, greaterThan(closeRect.bottom));

    await tester.tap(
      find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
      findsNothing,
    );
  });

  testWidgets(
    'schedule sheet validates description and creates same-day time range',
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
      expect(
        find.byKey(TaskManagementScreen.calendarSheetTargetDateButtonKey),
        findsOneWidget,
      );
      expect(
        find.byKey(TaskManagementScreen.calendarSheetTargetTimeButtonKey),
        findsOneWidget,
      );
      expect(find.text('Color Selection'), findsOneWidget);
      expect(
        find.byKey(
          taskCategoryColorChoiceKey('task-calendar-sheet', AppColors.blue500),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          taskCategoryColorChoiceKey('task-calendar-sheet', AppColors.rose500),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(TaskManagementScreen.calendarSheetSwapButtonKey),
        findsNothing,
      );
      expect(
        find.byKey(TaskManagementScreen.calendarSheetStartDateButtonKey),
        findsNothing,
      );
      expect(
        find.byKey(TaskManagementScreen.calendarSheetEndDateButtonKey),
        findsNothing,
      );
      expect(find.text('Target Date'), findsOneWidget);
      expect(find.text('Target Time'), findsOneWidget);

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetTitleFieldKey),
        'Plan launch',
      );
      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'This description is intentionally longer than one hundred characters so the quick schedule validator can reject it cleanly.',
      );
      final roseColorFinder = find.byKey(
        taskCategoryColorChoiceKey('task-calendar-sheet', AppColors.rose500),
      );
      await tester.ensureVisible(roseColorFinder);
      await tester.tap(roseColorFinder);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          taskCategorySelectedColorCheckKey(
            'task-calendar-sheet',
            AppColors.rose500,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSubmitButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Description must be 100 characters or fewer.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'Launch prep',
      );

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
      expect(created.startDateTime, DateTime(2026, 4, 29, 9));
      expect(created.endDateTime, DateTime(2026, 4, 29, 11));
      expect(created.startDate, DateTime(2026, 4, 29));
      expect(created.endDate, DateTime(2026, 4, 29));
      expect(created.categoryId, 'personal');
      final categories = await repository.getCategories();
      final personal = categories.firstWhere(
        (category) => category.id == 'personal',
      );
      expect(personal.color, AppColors.rose500);
    },
  );

  testWidgets(
    'calendar task details sheet toggles between complete and incomplete states',
    (WidgetTester tester) async {
      await pumpScreen(tester);
      await openCalendarAndSelectDate(tester, '2026-04-20');

      await tester.tap(find.text('Science Assessment'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarDetailsCompleteButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      expect(find.text('Mark As Completed'), findsNothing);
      expect(find.text('Mark as Incomplete'), findsOneWidget);

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarDetailsCompleteButtonKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
          matching: find.text('Completed'),
        ),
        findsNothing,
      );
      expect(find.text('Mark As Completed'), findsOneWidget);
      expect(find.text('Mark as Incomplete'), findsNothing);

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
      );
      await tester.pumpAndSettle();

      final completedTask = await repository.getTaskById('science');
      expect(completedTask?.isCompleted, isFalse);

      final titleText = tester.widget<Text>(
        find.text('Science Assessment').first,
      );
      expect(titleText.style?.decoration, TextDecoration.none);
    },
  );

  testWidgets(
    'overlapping tasks with the same time render in separate columns',
    (WidgetTester tester) async {
      final overlapRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'alpha',
            title: 'Alpha',
            description: 'First overlap',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 11 * 60,
          ),
          _buildTask(
            id: 'beta',
            title: 'Beta',
            description: 'Second overlap',
            categoryId: 'personal',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 11 * 60,
          ),
        ],
        seedDefaults: true,
      );
      final overlapController = TaskManagementController(overlapRepository);
      await overlapController.load();

      await pumpScreenWithState(
        tester,
        repository: overlapRepository,
        controller: overlapController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      final alphaLeft = tester.getTopLeft(find.text('Alpha')).dx;
      final betaLeft = tester.getTopLeft(find.text('Beta')).dx;

      expect(alphaLeft, isNot(equals(betaLeft)));
      expect(find.text('09:00AM - 11:00AM'), findsNWidgets(2));
    },
  );

  testWidgets('three overlapping tasks render across three columns', (
    WidgetTester tester,
  ) async {
    final overlapRepository = InMemoryTaskRepository(
      tasks: [
        _buildTask(
          id: 'alpha',
          title: 'Alpha',
          description: 'First overlap',
          categoryId: 'school',
          startDate: DateTime(2026, 4, 20),
          startMinutes: 9 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        ),
        _buildTask(
          id: 'beta',
          title: 'Beta',
          description: 'Second overlap',
          categoryId: 'personal',
          startDate: DateTime(2026, 4, 20),
          startMinutes: 9 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        ),
        _buildTask(
          id: 'gamma',
          title: 'Gamma',
          description: 'Third overlap',
          categoryId: 'school',
          startDate: DateTime(2026, 4, 20),
          startMinutes: 9 * 60,
          endDate: DateTime(2026, 4, 20),
          endMinutes: 11 * 60,
        ),
      ],
      seedDefaults: true,
    );
    final overlapController = TaskManagementController(overlapRepository);
    await overlapController.load();

    await pumpScreenWithState(
      tester,
      repository: overlapRepository,
      controller: overlapController,
    );
    await openCalendarAndSelectDate(tester, '2026-04-20');

    final leftPositions = <double>{
      tester.getTopLeft(find.byKey(const ValueKey('calendar_task_alpha'))).dx,
      tester.getTopLeft(find.byKey(const ValueKey('calendar_task_beta'))).dx,
      tester.getTopLeft(find.byKey(const ValueKey('calendar_task_gamma'))).dx,
    };

    expect(leftPositions.length, 3);
  });

  testWidgets(
    'a short task overlapping a long task renders in a separate column',
    (WidgetTester tester) async {
      final overlapRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'long',
            title: 'Long Task',
            description: 'Long overlap',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 12 * 60,
          ),
          _buildTask(
            id: 'short',
            title: 'Short Task',
            description: 'Short overlap',
            categoryId: 'personal',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 10 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 11 * 60,
          ),
        ],
        seedDefaults: true,
      );
      final overlapController = TaskManagementController(overlapRepository);
      await overlapController.load();

      await pumpScreenWithState(
        tester,
        repository: overlapRepository,
        controller: overlapController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      final longLeft = tester.getTopLeft(find.text('Long Task')).dx;
      final shortLeft = tester.getTopLeft(find.text('Short Task')).dx;

      expect(longLeft, isNot(equals(shortLeft)));
    },
  );

  testWidgets(
    'tasks that touch end-to-start stay in the same full-width lane',
    (WidgetTester tester) async {
      final adjacentRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'first',
            title: 'First Task',
            description: 'Morning block',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 10 * 60,
          ),
          _buildTask(
            id: 'second',
            title: 'Second Task',
            description: 'Next block',
            categoryId: 'personal',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 10 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 11 * 60,
          ),
        ],
        seedDefaults: true,
      );
      final adjacentController = TaskManagementController(adjacentRepository);
      await adjacentController.load();

      await pumpScreenWithState(
        tester,
        repository: adjacentRepository,
        controller: adjacentController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      final firstLeft = tester.getTopLeft(find.text('First Task')).dx;
      final secondLeft = tester.getTopLeft(find.text('Second Task')).dx;

      expect(firstLeft, equals(secondLeft));
    },
  );

  testWidgets(
    'calendar timeline shows exact minute ranges for scheduled tasks',
    (WidgetTester tester) async {
      final preciseRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'precise',
            title: 'Precise Task',
            description: 'Minute-level schedule',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: (22 * 60) + 30,
            endDate: DateTime(2026, 4, 20),
            endMinutes: (23 * 60) + 25,
          ),
        ],
        seedDefaults: true,
      );
      final preciseController = TaskManagementController(preciseRepository);
      await preciseController.load();

      await pumpScreenWithState(
        tester,
        repository: preciseRepository,
        controller: preciseController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      expect(find.text('10:30PM - 11:25PM'), findsOneWidget);
    },
  );

  test('overlap lane width keeps compact columns and allows scrolling', () {
    expect(
      calendarGroupLaneWidth(
        columnCount: 1,
        availableLaneWidth: 320,
        columnGap: 4,
      ),
      320,
    );
    expect(
      calendarGroupLaneWidth(
        columnCount: 2,
        availableLaneWidth: 320,
        columnGap: 4,
      ),
      356,
    );
    expect(
      calendarGroupLaneWidth(
        columnCount: 2,
        availableLaneWidth: 600,
        columnGap: 4,
      ),
      356,
    );
  });

  test('calendar task content mode falls back to compact before hiding', () {
    expect(
      resolveCalendarTaskContentMode(width: 160, height: 100),
      CalendarTaskContentMode.detailed,
    );
    expect(
      resolveCalendarTaskContentMode(width: 120, height: 100),
      CalendarTaskContentMode.compact,
    );
    expect(
      resolveCalendarTaskContentMode(
        width: 180,
        height: 100,
        preferCompact: true,
      ),
      CalendarTaskContentMode.compact,
    );
    expect(
      resolveCalendarTaskContentMode(width: 80, height: 100),
      CalendarTaskContentMode.hidden,
    );
  });
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

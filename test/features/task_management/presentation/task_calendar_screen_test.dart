import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:tabler_icons/tabler_icons.dart';
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

  Future<void> pumpCalendarView(
    WidgetTester tester, {
    required double initialTimelineZoom,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCalendarView(
            controller: controller,
            segmentControl: const SizedBox.shrink(),
            selectedMonth: DateTime(2026, 4),
            selectedDate: DateTime(2026, 4, 20),
            statusFilter: TaskStatusFilter.all,
            onMonthChanged: (_) {},
            onDateSelected: (_) {},
            onStatusSelected: (_) {},
            onSchedulePressed: () {},
            onTaskTap: (_) {},
            statusChipKeyBuilder: ValueKey.new,
            dateKeyBuilder: ValueKey.new,
            scheduleButtonKey: const ValueKey('schedule_button'),
            timelineScrollKey: TaskManagementScreen.calendarTimelineScrollKey,
            monthHeaderKey: const ValueKey('month_header'),
            initialTimelineZoom: initialTimelineZoom,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCalendarAndSelectDate(
    WidgetTester tester,
    String keyValue,
  ) async {
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();
    final parts = keyValue.split('-');
    final targetMonth = int.parse(parts[1]);
    final targetMonthLabel = _monthName(targetMonth);
    final monthHeaderFinder = find.byKey(
      TaskManagementScreen.calendarMonthDropdownKey,
    );
    final targetHeaderLabel = '$targetMonthLabel ${parts[0]}';
    if (find.descendant(of: monthHeaderFinder, matching: find.text(targetHeaderLabel)).evaluate().isEmpty) {
      await tester.tap(monthHeaderFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text(targetMonthLabel));
      await tester.pumpAndSettle();
    }
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
    expect(find.text('9:10AM'), findsNothing);
    expect(
      find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
      findsOneWidget,
    );
    expect(
      find.byKey(TaskManagementScreen.calendarTimelineScrollKey),
      findsOneWidget,
    );

    final monthRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarMonthDropdownKey),
    );
    final selectedDateRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarDateKey('2026-04-20')),
    );
    expect(monthRect.top, lessThan(selectedDateRect.top));
  });

  testWidgets('calendar opens with today selected by default', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final todayKeyValue =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final todayCard = find.byKey(
      TaskManagementScreen.calendarDateKey(todayKeyValue),
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
      find.byKey(TaskManagementScreen.calendarDetailsEditButtonKey),
      findsOneWidget,
    );
    expect(find.text('Edit Task'), findsOneWidget);
    final closeRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
    );
    final actionRect = tester.getRect(
      find.byKey(TaskManagementScreen.calendarDetailsEditButtonKey),
    );
    expect(closeRect.top, actionRect.top);
    expect(closeRect.width, actionRect.width);
    expect(actionRect.left, greaterThan(closeRect.right));

    await tester.tap(
      find.byKey(TaskManagementScreen.calendarDetailsCloseButtonKey),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
      findsNothing,
    );
  });

  testWidgets('tapping outside the calendar details sheet dismisses it', (
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

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
      findsNothing,
    );
  });

  testWidgets('calendar schedule category popup removes menu icons', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
    );
    await tester.pumpAndSettle();

    final categoryField = find.byKey(
      TaskManagementScreen.calendarSheetCategoryFieldKey,
    );
    await tester.ensureVisible(categoryField);
    await tester.pumpAndSettle();
    await tester.tap(categoryField);
    await tester.pumpAndSettle();

    final personalOption = find.byKey(
      TaskManagementScreen.calendarSheetCategoryOptionKey('personal'),
    );
    expect(
      find.descendant(of: personalOption, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets(
    'long pressing a calendar task opens a delete context menu and removes the task',
    (WidgetTester tester) async {
      await pumpScreen(tester);
      await openCalendarAndSelectDate(tester, '2026-04-20');

      await tester.longPress(
        find.byKey(const ValueKey('calendar_task_science')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Task?'), findsOneWidget);

      await tester.tap(find.text('Yes, Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Science Assessment'), findsNothing);
      expect(await repository.getTaskById('science'), isNull);
    },
  );

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

      final submitButton = find.byKey(
        TaskManagementScreen.calendarSheetSubmitButtonKey,
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Description must be 100 characters or fewer.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'Launch prep',
      );

      final categoryField = find.byKey(
        TaskManagementScreen.calendarSheetCategoryFieldKey,
      );
      await tester.ensureVisible(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          TaskManagementScreen.calendarSheetCategoryOptionKey('personal'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.byKey(TaskManagementScreen.calendarSheetKey), findsNothing);
      expect(find.text('Plan launch'), findsOneWidget);

      final tasks = await repository.getTasks();
      final created = tasks.firstWhere((task) => task.title == 'Plan launch');
      final now = DateTime.now();
      final expectedDate = DateTime(now.year, now.month, now.day);
      expect(
        created.startDateTime,
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day, 9),
      );
      expect(
        created.endDateTime,
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day, 11),
      );
      expect(created.startDate, expectedDate);
      expect(created.endDate, expectedDate);
      expect(created.categoryId, 'personal');
      final categories = await repository.getCategories();
      final personal = categories.firstWhere(
        (category) => category.id == 'personal',
      );
      expect(personal.color, AppColors.rose500);
    },
  );

  testWidgets('schedule sheet stays shorter than the full screen height', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(TaskManagementScreen.calendarSegmentKey));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(TaskManagementScreen.calendarScheduleButtonKey),
    );
    await tester.pumpAndSettle();

    final surfaceHeight = tester.binding.renderView.size.height;
    final sheetHeight = tester
        .getRect(find.byKey(TaskManagementScreen.calendarSheetKey))
        .height;

    expect(sheetHeight, lessThan(surfaceHeight * 0.9));
  });

  testWidgets(
    'calendar task details sheet opens schedule sheet in edit mode and saves updates',
    (WidgetTester tester) async {
      await pumpScreen(tester);
      await openCalendarAndSelectDate(tester, '2026-04-20');

      await tester.tap(find.text('Science Assessment'));
      await tester.pumpAndSettle();

      expect(find.text('Mark As Completed'), findsNothing);
      expect(find.text('Mark as Incomplete'), findsNothing);
      expect(find.text('Edit Task'), findsOneWidget);

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarDetailsEditButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(TaskManagementScreen.calendarSheetKey), findsOneWidget);
      expect(find.text('Edit Task'), findsWidgets);
      expect(find.text('Update your scheduled task'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(TaskManagementScreen.calendarSheetTitleFieldKey),
            )
            .controller
            ?.text,
        'Science Assessment',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
            )
            .controller
            ?.text,
        'Prepare for quiz',
      );
      expect(find.text('08:00 AM - 11:00 AM'), findsOneWidget);

      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetTitleFieldKey),
        'Science Review',
      );
      await tester.enterText(
        find.byKey(TaskManagementScreen.calendarSheetDescriptionFieldKey),
        'Review chapters',
      );

      final categoryField = find.byKey(
        TaskManagementScreen.calendarSheetCategoryFieldKey,
      );
      await tester.ensureVisible(categoryField);
      await tester.tap(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          TaskManagementScreen.calendarSheetCategoryOptionKey('personal'),
        ),
      );
      await tester.pumpAndSettle();

      final roseColorFinder = find.byKey(
        taskCategoryColorChoiceKey('task-calendar-sheet', AppColors.rose500),
      );
      await tester.ensureVisible(roseColorFinder);
      await tester.tap(roseColorFinder);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(TaskManagementScreen.calendarSheetSubmitButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(TaskManagementScreen.calendarSheetKey), findsNothing);
      expect(
        find.byKey(TaskManagementScreen.calendarDetailsSheetKey),
        findsNothing,
      );
      expect(find.text('Science Review'), findsOneWidget);
      expect(find.text('08:00AM - 11:00AM'), findsOneWidget);
      expect(find.text('Personal'), findsWidgets);

      final updatedTask = await repository.getTaskById('science');
      expect(updatedTask, isNotNull);
      expect(updatedTask?.title, 'Science Review');
      expect(updatedTask?.description, 'Review chapters');
      expect(updatedTask?.startDate, DateTime(2026, 4, 20));
      expect(updatedTask?.endDate, DateTime(2026, 4, 20));
      expect(updatedTask?.startMinutes, 8 * 60);
      expect(updatedTask?.endMinutes, 11 * 60);
      expect(updatedTask?.categoryId, 'personal');
      expect(updatedTask?.priority, TaskPriority.medium);
      expect(updatedTask?.isCompleted, isFalse);

      final categories = await repository.getCategories();
      final personal = categories.firstWhere(
        (category) => category.id == 'personal',
      );
      expect(personal.color, AppColors.rose500);
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

      final firstCard = find.byKey(const ValueKey('calendar_task_first'));
      final secondCard = find.byKey(const ValueKey('calendar_task_second'));
      final firstRect = tester.getRect(firstCard);
      final secondRect = tester.getRect(secondCard);
      final firstLeft = firstRect.left;
      final secondLeft = secondRect.left;
      final verticalGap = secondRect.top - firstRect.bottom;

      expect(firstLeft, equals(secondLeft));
      expect(secondRect.top, greaterThan(firstRect.bottom));
      expect(verticalGap, closeTo(1.0, 0.01));
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

  testWidgets(
    'calendar timeline shows selective detailed labels after zooming in',
    (WidgetTester tester) async {
      await pumpCalendarView(tester, initialTimelineZoom: 1.0);

      expect(find.text('9:00AM'), findsNothing);
      expect(find.text('9:10AM'), findsNothing);
      expect(find.text('9:30AM'), findsNothing);
      expect(find.text('9:40AM'), findsNothing);

      expect(find.text('9AM'), findsOneWidget);

      await pumpCalendarView(tester, initialTimelineZoom: 1.3);

      expect(find.text('9:00AM'), findsOneWidget);
      expect(find.text('9:10AM'), findsNothing);
      expect(find.text('9:30AM'), findsOneWidget);
      expect(find.text('9:40AM'), findsNothing);
      expect(find.text('9AM'), findsNothing);

      await pumpCalendarView(tester, initialTimelineZoom: 1.0);

      expect(find.text('9AM'), findsOneWidget);
      expect(find.text('9:00AM'), findsNothing);
      expect(find.text('9:10AM'), findsNothing);
      expect(find.text('9:30AM'), findsNothing);
      expect(find.text('9:40AM'), findsNothing);
    },
  );

  testWidgets(
    'calendar keeps due-only tasks outside the timeline while showing them in the reminder list',
    (WidgetTester tester) async {
      final mixedRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'scheduled',
            title: 'Scheduled Task',
            description: 'Scheduled block',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 10 * 60,
          ),
          TaskItem(
            id: 'due-only',
            title: 'Due Only Task',
            description: 'Due later today',
            priority: TaskPriority.medium,
            categoryId: 'personal',
            standaloneCategoryId: 'personal',
            createdAt: DateTime(2026, 4, 13, 9),
            updatedAt: DateTime(2026, 4, 13, 9),
            endDate: DateTime(2026, 4, 20),
            endMinutes: 17 * 60,
            noteDocumentJson: buildPlainTextNoteDocumentJson('Due later today'),
            notePlainText: 'Due later today',
          ),
          TaskItem(
            id: 'due-second',
            title: 'Second Due Task',
            description: 'Another reminder',
            priority: TaskPriority.medium,
            categoryId: 'school',
            standaloneCategoryId: 'school',
            createdAt: DateTime(2026, 4, 13, 10),
            updatedAt: DateTime(2026, 4, 13, 10),
            endDate: DateTime(2026, 4, 20),
            endMinutes: 21 * 60 + 30,
            noteDocumentJson: buildPlainTextNoteDocumentJson('Another reminder'),
            notePlainText: 'Another reminder',
          ),
        ],
        seedDefaults: true,
      );
      final mixedController = TaskManagementController(mixedRepository);
      await mixedController.load();

      await pumpScreenWithState(
        tester,
        repository: mixedRepository,
        controller: mixedController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      expect(find.text('Scheduled Task'), findsOneWidget);
      expect(find.text('Due Only Task'), findsOneWidget);
      expect(find.text('Second Due Task'), findsOneWidget);
      expect(find.text('09:00AM - 10:00AM'), findsOneWidget);
      expect(find.text('05:00PM - 05:00PM'), findsNothing);
      expect(find.text('Due Time'), findsOneWidget);
      expect(find.text('Reminders scheduled for the selected date'), findsOneWidget);
      expect(find.text('05:00 PM'), findsOneWidget);
      expect(find.text('09:30 PM'), findsOneWidget);
      expect(find.byIcon(TablerIcons.chevron_right), findsNWidgets(2));
    },
  );

  testWidgets(
    'calendar shows due-time tasks outside the timeline and opens the flexible edit form',
    (WidgetTester tester) async {
      final mixedRepository = InMemoryTaskRepository(
        tasks: [
          _buildTask(
            id: 'scheduled',
            title: 'Scheduled Task',
            description: 'Scheduled block',
            categoryId: 'school',
            startDate: DateTime(2026, 4, 20),
            startMinutes: 9 * 60,
            endDate: DateTime(2026, 4, 20),
            endMinutes: 10 * 60,
          ),
          TaskItem(
            id: 'due-only',
            title: 'Due Only Task',
            description: 'Due later today',
            priority: TaskPriority.medium,
            categoryId: 'personal',
            standaloneCategoryId: 'personal',
            createdAt: DateTime(2026, 4, 13, 9),
            updatedAt: DateTime(2026, 4, 13, 9),
            endDate: DateTime(2026, 4, 20),
            endMinutes: 17 * 60,
            noteDocumentJson: buildPlainTextNoteDocumentJson('Due later today'),
            notePlainText: 'Due later today',
          ),
        ],
        seedDefaults: true,
      );
      final mixedController = TaskManagementController(mixedRepository);
      await mixedController.load();

      await pumpScreenWithState(
        tester,
        repository: mixedRepository,
        controller: mixedController,
      );
      await openCalendarAndSelectDate(tester, '2026-04-20');

      expect(find.text('Due Only Task'), findsOneWidget);
      expect(find.text('Scheduled Task'), findsOneWidget);
      expect(find.text('05:00PM - 05:00PM'), findsNothing);

      await tester.tap(find.text('Due Only Task'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tasks'), findsOneWidget);
      expect(find.text('Schedule Type'), findsOneWidget);
      expect(find.text('No Time'), findsOneWidget);
      expect(find.text('Due Time'), findsWidgets);
      expect(find.text('Time Range'), findsOneWidget);
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

  test('timeline markers stay hourly in default mode', () {
    final markers = buildTimelineMarkers(const [8, 9, 10], detailed: false);

    expect(markers.map((marker) => marker.label), ['8AM', '9AM', '10AM']);
    expect(markers.every((marker) => marker.isHour), isTrue);
  });

  test(
    'timeline markers keep 10-minute positions but label only half hours',
    () {
      final markers = buildTimelineMarkers(const [9, 10], detailed: true);

      expect(
        markers
            .where((marker) => marker.showsLabel)
            .map((marker) => marker.label),
        ['9:00AM', '9:30AM', '10:00AM'],
      );
      expect(markers.first.isHour, isTrue);
      expect(markers[1].isHour, isFalse);
      expect(markers.last.isHour, isTrue);
      expect(markers.map((marker) => marker.minutes), [
        540,
        550,
        560,
        570,
        580,
        590,
        600,
      ]);
    },
  );

  test('detailed time labels use h:mmAM formatting', () {
    expect(formatDetailedTimelineLabel((9 * 60) + 30), '9:30AM');
    expect(formatDetailedTimelineLabel((21 * 60) + 40), '9:40PM');
    expect(formatDetailedTimelineLabel(0), '12:00AM');
  });
}

String _monthName(int month) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return monthNames[month - 1];
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

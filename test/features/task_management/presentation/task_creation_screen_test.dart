import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/services/vault_service_scope.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/presentation/task_creation_sheet.dart';

void main() {
  Future<void> pumpCreationScreen(
    WidgetTester tester, {
    required InMemoryTaskRepository repository,
  }) async {
    await tester.pumpWidget(
      VaultServiceScope(
        vaultService: const NoopVaultService(),
        child: MaterialApp(
          home: TaskCreationScreen(
            repository: repository,
            categories: await repository.getCategories(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('task creation screen shows due-time scheduling by default', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryTaskRepository(seedDefaults: true);

    await pumpCreationScreen(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byKey(createDateRangeButtonKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule Type'), findsOneWidget);
    expect(find.text('No Time'), findsOneWidget);
    expect(find.text('Due Time'), findsWidgets);
    expect(find.text('Time Range'), findsOneWidget);
    expect(find.text('Target Date'), findsOneWidget);
    expect(find.text('Target Time'), findsOneWidget);
    expect(find.text('Due time set'), findsOneWidget);
    expect(
      find.text(
        'This task will notify you at the selected time and appear in your calendar as a reminder.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('task creation screen switches to no-time scheduling content', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryTaskRepository(seedDefaults: true);

    await pumpCreationScreen(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byKey(createDateRangeButtonKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No Time'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No Time'));
    await tester.pumpAndSettle();

    expect(find.text('Unscheduled task'), findsOneWidget);
    expect(
      find.text(
        'Tasks without a date or time won\'t appear in your calendar or trigger reminders.',
      ),
      findsOneWidget,
    );
    expect(find.text('Due time set'), findsNothing);
    expect(find.text('Scheduled task'), findsNothing);
  });

  testWidgets('task creation screen switches to time-range scheduling content', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryTaskRepository(seedDefaults: true);

    await pumpCreationScreen(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byKey(createDateRangeButtonKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Time Range'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time Range'));
    await tester.pumpAndSettle();

    expect(find.text('Start & End Time'), findsOneWidget);
    expect(find.text('Scheduled task'), findsOneWidget);
    expect(
      find.text(
        'This task will appear in your calendar for the selected time range.',
      ),
      findsOneWidget,
    );
  });
}

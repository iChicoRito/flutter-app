import 'package:flutter/material.dart';
import 'package:flutter_app/core/services/display_name_store.dart';
import 'package:flutter_app/core/services/task_data_refresh_scope.dart';
import 'package:flutter_app/core/services/task_reminder_service.dart';
import 'package:flutter_app/features/task_management/data/hive_task_repository.dart';
import 'package:flutter_app/features/task_management/domain/task_category.dart';
import 'package:flutter_app/features/task_management/domain/task_item.dart';
import 'package:flutter_app/features/task_reminder/presentation/task_alarm_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness(Widget child) {
    return TaskDataRefreshScope(
      controller: TaskDataRefreshController(),
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  testWidgets(
    'alarm screen uses the redesigned hero illustration and task cards',
    (WidgetTester tester) async {
      final dueAt = DateTime(2026, 4, 14, 17, 19);
      final repository = InMemoryTaskRepository(
        categories: [
          TaskCategory(
            id: 'school',
            name: 'School',
            iconKey: 'briefcase',
            colorValue: const Color(0xFFF43F5E).toARGB32(),
            createdAt: DateTime(2026, 4, 14, 8),
          ),
        ],
        tasks: [
          _buildTask(
            id: 'task-1',
            title: 'Task Title',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Lorem ipsum dolor sit amen con',
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(430, 1000));
      await tester.pumpWidget(
        buildHarness(
          TaskAlarmScreen(
            payload: TaskReminderPayload(
              taskId: 'task-1',
              taskTitle: 'Task Title',
              kind: TaskReminderKind.due,
              scheduledAt: dueAt,
            ),
            reminderService: const NoopTaskReminderService(),
            taskRepository: repository,
            displayNameStore: const _FakeDisplayNameStore(),
          ),
        ),
      );
      await tester.pump();

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svg.bytesLoader;

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(loader, isA<SvgAssetLoader>());
      expect(
        (loader as SvgAssetLoader).assetName,
        'assets/svgs/welcome/remindly-alarm.svg',
      );
      expect(find.text('Tasks Due Now!'), findsOneWidget);
      expect(
        find.text('Your tasks is scheduled for 4/14/2026 at 5:19 PM'),
        findsOneWidget,
      );
      expect(find.text('Task Title'), findsOneWidget);
      expect(find.text('Lorem ipsum dolor sit amen con'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Dismiss Alarm'), findsOneWidget);
    },
  );

  testWidgets(
    'alarm screen keeps all due tasks reachable in a scrollable list',
    (WidgetTester tester) async {
      final repository = InMemoryTaskRepository(
        categories: [
          TaskCategory(
            id: 'school',
            name: 'School',
            iconKey: 'briefcase',
            colorValue: const Color(0xFFF43F5E).toARGB32(),
            createdAt: DateTime(2026, 4, 14, 8),
          ),
        ],
        tasks: [
          _buildTask(
            id: 'task-1',
            title: 'Task One',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Details one',
          ),
          _buildTask(
            id: 'task-2',
            title: 'Task Two',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Details two',
          ),
          _buildTask(
            id: 'task-3',
            title: 'Task Three',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Details three',
          ),
          _buildTask(
            id: 'task-4',
            title: 'Task Four',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Details four',
          ),
          _buildTask(
            id: 'task-5',
            title: 'Task Five',
            categoryId: 'school',
            endDate: DateTime(2026, 4, 14),
            endMinutes: 17 * 60 + 19,
            noteText: 'Details five',
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(430, 760));
      await tester.pumpWidget(
        buildHarness(
          TaskAlarmScreen(
            payload: TaskReminderPayload(
              taskId: 'task-1',
              taskTitle: 'Task One',
              kind: TaskReminderKind.due,
              scheduledAt: DateTime(2026, 4, 14, 17, 19),
            ),
            reminderService: const NoopTaskReminderService(),
            taskRepository: repository,
            displayNameStore: const _FakeDisplayNameStore(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(scrollable.position.pixels, 0);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pump();

      expect(scrollable.position.pixels, greaterThan(0));
    },
  );
}

TaskItem _buildTask({
  required String id,
  required String title,
  required String categoryId,
  required DateTime endDate,
  required int endMinutes,
  String noteText = '',
}) {
  final now = DateTime(2026, 4, 14, 8);
  return TaskItem(
    id: id,
    title: title,
    priority: TaskPriority.medium,
    categoryId: categoryId,
    endDate: endDate,
    endMinutes: endMinutes,
    createdAt: now,
    updatedAt: now,
    notePlainText: noteText,
  );
}

class _FakeDisplayNameStore implements DisplayNameStore {
  const _FakeDisplayNameStore();

  @override
  Future<void> saveDisplayName(String value) async {}

  @override
  Future<String?> readDisplayName() async => null;

  @override
  Future<void> saveProfileImageData(String? value) async {}

  @override
  Future<String?> readProfileImageData() async => null;
}

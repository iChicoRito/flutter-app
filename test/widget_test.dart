import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabler_icons/tabler_icons.dart';

import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/core/services/onboarding_status_store.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/splash/presentation/splash_screen.dart';

void main() {
  late FakeOnboardingStatusStore onboardingStatusStore;

  setUp(() {
    onboardingStatusStore = FakeOnboardingStatusStore();
  });

  testWidgets('shows splash screen first', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );

    expect(find.byKey(SplashScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.markerKey), findsNothing);
    expect(find.text('Flutter App'), findsOneWidget);
  });

  testWidgets('keeps splash visible before five seconds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 4, milliseconds: 900));

    expect(find.byKey(SplashScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.markerKey), findsNothing);
  });

  testWidgets('navigates to onboarding after five seconds on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(SplashScreen.markerKey), findsNothing);
    expect(find.byKey(OnboardingScreen.markerKey), findsOneWidget);
    expect(find.byKey(DashboardScreen.homeTabKey), findsNothing);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('shows four-step onboarding with expected navigation labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.contentKey), findsOneWidget);
    expect(find.text('Welcome Aboard'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Ready To Begin'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('completing onboarding writes the flag and opens home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
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
    expect(find.byKey(DashboardScreen.homeTabKey), findsOneWidget);
  });

  testWidgets('skips onboarding when it was already completed', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.markerKey), findsNothing);
    expect(find.byKey(DashboardScreen.markerKey), findsOneWidget);
  });

  testWidgets('dashboard home shows task-first content and add task CTA', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);

    final dashboardScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Today\'s Tasks'),
      300,
      scrollable: dashboardScroll,
    );
    await tester.scrollUntilVisible(
      find.text('Upcoming'),
      300,
      scrollable: dashboardScroll,
    );

    expect(find.byKey(DashboardScreen.homeTabKey), findsOneWidget);
    expect(find.text('Today\'s Tasks'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.byKey(DashboardScreen.addTaskButtonKey), findsOneWidget);
  });

  testWidgets('toggling a task updates counts and progress', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(DashboardScreen.summaryCountKey('Pending')))
          .data,
      '6',
    );
    expect(
      tester.widget<Text>(find.byKey(DashboardScreen.progressLabelKey)).data,
      '2 of 5 tasks completed today',
    );

    final dashboardScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(DashboardScreen.taskToggleKey('today-design')),
      120,
      scrollable: dashboardScroll,
    );
    await tester.drag(dashboardScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(DashboardScreen.taskToggleKey('today-design')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DashboardScreen.taskToggleKey('today-design')));
    await tester.pumpAndSettle();
    await tester.drag(dashboardScroll, const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(DashboardScreen.summaryCountKey('Pending')))
          .data,
      '5',
    );
  });

  testWidgets('completed section starts collapsed and can expand', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Send status update email'), findsNothing);

    final dashboardScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(DashboardScreen.completedHeaderKey),
      300,
      scrollable: dashboardScroll,
    );
    await tester.tap(find.byKey(DashboardScreen.completedHeaderKey));
    await tester.pumpAndSettle();

    expect(find.text('Send status update email'), findsOneWidget);
  });

  testWidgets('summary cards render as passive stats with icons', (
    WidgetTester tester,
  ) async {
    onboardingStatusStore.completed = true;

    await tester.pumpWidget(
      MyApp(onboardingStatusStore: onboardingStatusStore),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.byIcon(TablerIcons.list_details), findsOneWidget);
    expect(find.byIcon(TablerIcons.clock_hour_8), findsAtLeastNWidgets(1));
    expect(find.byIcon(TablerIcons.circle_check), findsAtLeastNWidgets(1));
    expect(find.byIcon(TablerIcons.alert_circle), findsOneWidget);
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

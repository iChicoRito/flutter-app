import 'package:flutter_test/flutter_test.dart';

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
    expect(find.byKey(HomeScreen.markerKey), findsNothing);
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
    expect(find.text('Dashboard Home'), findsOneWidget);
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

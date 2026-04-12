import 'package:flutter/material.dart';

import '../core/services/onboarding_status_store.dart';
import '../features/splash/presentation/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    OnboardingStatusStore? onboardingStatusStore,
  }) : onboardingStatusStore =
           onboardingStatusStore ?? const SharedPreferencesOnboardingStatusStore();

  final OnboardingStatusStore onboardingStatusStore;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E88E5);

    return MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: primaryBlue,
      ),
      home: SplashScreen(onboardingStatusStore: onboardingStatusStore),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/services/onboarding_status_store.dart';
import '../core/services/task_repository_scope.dart';
import '../features/task_management/data/hive_task_repository.dart';
import '../features/task_management/domain/task_repository.dart';
import '../features/splash/presentation/splash_screen.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    OnboardingStatusStore? onboardingStatusStore,
    TaskRepository? taskRepository,
  }) : onboardingStatusStore =
           onboardingStatusStore ??
           const SharedPreferencesOnboardingStatusStore(),
       taskRepository = taskRepository ?? InMemoryTaskRepository();

  final OnboardingStatusStore onboardingStatusStore;
  final TaskRepository taskRepository;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E88E5);

    return TaskRepositoryScope(
      repository: taskRepository,
      child: MaterialApp(
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
      ),
    );
  }
}

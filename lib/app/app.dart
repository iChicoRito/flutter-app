import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/display_name_store.dart';
import '../core/services/onboarding_status_store.dart';
import '../core/services/task_repository_scope.dart';
import '../features/task_management/data/hive_task_repository.dart';
import '../features/task_management/domain/task_repository.dart';
import '../features/splash/presentation/splash_screen.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    OnboardingStatusStore? onboardingStatusStore,
    DisplayNameStore? displayNameStore,
    TaskRepository? taskRepository,
  }) : onboardingStatusStore =
           onboardingStatusStore ??
           const SharedPreferencesOnboardingStatusStore(),
       displayNameStore =
           displayNameStore ?? const SharedPreferencesDisplayNameStore(),
       taskRepository = taskRepository ?? InMemoryTaskRepository();

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;
  final TaskRepository taskRepository;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF066FD1);

    return TaskRepositoryScope(
      repository: taskRepository,
      child: MaterialApp(
        title: 'Flutter App',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: primaryBlue,
          textTheme: GoogleFonts.poppinsTextTheme(),
          primaryTextTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: SplashScreen(
          onboardingStatusStore: onboardingStatusStore,
          displayNameStore: displayNameStore,
        ),
      ),
    );
  }
}

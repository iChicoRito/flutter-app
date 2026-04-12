import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingStatusStore {
  Future<bool> isCompleted();

  Future<void> markCompleted();
}

class SharedPreferencesOnboardingStatusStore implements OnboardingStatusStore {
  const SharedPreferencesOnboardingStatusStore();

  static const String _completionKey = 'onboarding_completed';

  @override
  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completionKey) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completionKey, true);
  }
}

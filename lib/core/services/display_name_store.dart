import 'package:shared_preferences/shared_preferences.dart';

abstract class DisplayNameStore {
  Future<String?> readDisplayName();

  Future<void> saveDisplayName(String value);
}

class SharedPreferencesDisplayNameStore implements DisplayNameStore {
  const SharedPreferencesDisplayNameStore();

  static const String _displayNameKey = 'display_name';

  @override
  Future<String?> readDisplayName() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_displayNameKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  @override
  Future<void> saveDisplayName(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_displayNameKey, value.trim());
  }
}

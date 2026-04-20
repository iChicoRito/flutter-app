import 'package:shared_preferences/shared_preferences.dart';

abstract class DisplayNameStore {
  Future<String?> readDisplayName();

  Future<void> saveDisplayName(String value);

  Future<String?> readProfileImageData();

  Future<void> saveProfileImageData(String? value);
}

class SharedPreferencesDisplayNameStore implements DisplayNameStore {
  const SharedPreferencesDisplayNameStore();

  static const String _displayNameKey = 'display_name';
  static const String _profileImageDataKey = 'profile_image_data';

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

  @override
  Future<String?> readProfileImageData() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_profileImageDataKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  @override
  Future<void> saveProfileImageData(String? value) async {
    final preferences = await SharedPreferences.getInstance();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await preferences.remove(_profileImageDataKey);
      return;
    }
    await preferences.setString(_profileImageDataKey, trimmed);
  }
}

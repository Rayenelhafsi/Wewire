import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart' as app_models;

class SessionService {
  static const String _userKey = 'current_user';
  static const String _userTypeKey = 'user_type';
  static const String _isLoggedInKey = 'is_logged_in';

  static Future<void> saveUserSession(app_models.User user) async {
    final prefs = await SharedPreferences.getInstance();

    // Save user data
    await prefs.setString(_userKey, user.toJsonString());
    await prefs.setString(_userTypeKey, user.role.toString());
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<app_models.User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) {
      return null;
    }

    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        return app_models.User.fromJsonString(userJson);
      } catch (e) {
        print('Error parsing user from session: $e');
        return null;
      }
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_userTypeKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  static Future<app_models.UserRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString(_userTypeKey);

    if (roleString != null) {
      return app_models.UserRole.values.firstWhere(
        (role) => role.toString() == roleString,
        orElse: () => app_models.UserRole.operator,
      );
    }
    return null;
  }
}

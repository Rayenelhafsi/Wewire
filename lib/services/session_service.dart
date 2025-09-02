import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart' as app_models;
import 'firebase_service.dart';

class SessionService {
  static const String _userKey = 'current_user';
  static const String _userTypeKey = 'user_type';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _fcmTokenKey = 'fcm_token';

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
        debugPrint('Error parsing user from session: $e');
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

  // FCM Token management
  static Future<void> storeFCMToken(String token, {String? matricule}) async {
    final prefs = await SharedPreferences.getInstance();

    // Validate token before storing
    if (token.isEmpty || token == 'null') {
      debugPrint('Warning: Attempted to store invalid FCM token: "$token"');
      return;
    }

    await prefs.setString(_fcmTokenKey, token);

    // Also store the token in Firestore for the current user
    final user = await getCurrentUser();
    final userMatricule = matricule ?? user?.id;

    // Validate userMatricule before calling FirebaseService
    if (userMatricule == null ||
        userMatricule.isEmpty ||
        userMatricule == 'null') {
      debugPrint(
        'Warning: Cannot store FCM token - no valid user matricule found. User: $user, Matricule: $matricule',
      );
      return;
    }

    try {
      await FirebaseService.storeFCMToken(userMatricule, token);
    } catch (e) {
      debugPrint('Error storing FCM token in Firestore: $e');
      // Don't rethrow to prevent app crashes, but log the error
    }
  }

  static Future<String?> getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  static Future<void> removeFCMToken({String? matricule}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fcmTokenKey);

    // Also remove the token from Firestore for the current user
    final user = await getCurrentUser();
    final userMatricule = matricule ?? user?.id;
    if (userMatricule != null) {
      await FirebaseService.removeFCMToken(userMatricule);
    }
  }
}

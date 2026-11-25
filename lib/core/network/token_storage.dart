import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/auth_response_model.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_json';
  static const String _userPhoneKey = 'user_phone';
  static const String _isNewUserKey = 'is_new_user';
  static const String _lockoutPrefix = 'lockout_until_';

  /// Reads current token from secure storage with SharedPreferences fallback
  static Future<String?> getToken() async {
    try {
      final secureToken = await _storage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}

    // Legacy builds kept a plaintext copy in SharedPreferences: migrate it once, then delete it
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_tokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: _tokenKey, value: legacy);
        await prefs.remove(_tokenKey);
        return legacy;
      }
    } catch (_) {}

    return null;
  }

  /// Saves new token to both Secure Storage and SharedPreferences for reliability
  static Future<void> saveToken(String token, {UserModel? user, bool? isNewUser}) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey); // token lives only in encrypted secure storage
      if (isNewUser != null) {
        await prefs.setBool(_isNewUserKey, isNewUser);
      }
      if (user != null) {
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
        await prefs.setString(_userPhoneKey, user.phone);
        if (isNewUser == null) {
          await prefs.setBool(_isNewUserKey, user.isNewUser);
        }
      }
    } catch (_) {}
  }

  /// Sets lockout end timestamp for a specific phone number
  static Future<void> setLockout(String phone, int durationSeconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntil = DateTime.now().millisecondsSinceEpoch + (durationSeconds * 1000);
      await prefs.setInt('$_lockoutPrefix$phone', lockoutUntil);
    } catch (_) {}
  }

  /// Returns remaining lockout seconds for phone, or 0 if not locked
  static Future<int> getRemainingLockoutSeconds(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntil = prefs.getInt('$_lockoutPrefix$phone');
      if (lockoutUntil != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (lockoutUntil > now) {
          return ((lockoutUntil - now) / 1000).ceil();
        } else {
          await prefs.remove('$_lockoutPrefix$phone');
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Clears lockout record for a phone number
  static Future<void> clearLockout(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_lockoutPrefix$phone');
    } catch (_) {}
  }

  /// Clears all stored auth session data
  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_isNewUserKey);
      await prefs.remove('is_duty_online');
    } catch (_) {}
  }
}


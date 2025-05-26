import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _nurseDataKey = 'nurse_data';

  // Get auth token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save auth token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Remove auth token (logout)
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Get nurse data
  static Future<Map<String, dynamic>?> getNurseData() async {
    final prefs = await SharedPreferences.getInstance();
    final nurseDataString = prefs.getString(_nurseDataKey);
    if (nurseDataString != null) {
      return jsonDecode(nurseDataString);
    }
    return null;
  }

  // Save nurse data
  static Future<void> saveNurseData(Map<String, dynamic> nurseData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nurseDataKey, jsonEncode(nurseData));
  }

  // Remove nurse data (logout)
  static Future<void> removeNurseData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nurseDataKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Clear all data (complete logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nurseDataKey);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static Future<User> login(String email, String password) async {
    try {
      final response = await ApiService.post('login', {
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        final userData = response['data']['user'];
        final token = response['data']['token'];

        // Save locally for auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyUserData, jsonEncode(userData));
        await prefs.setString(AppConstants.keyUserToken, token);
        await prefs.setString(AppConstants.keyUserRole, userData['role']);

        return User.fromJson(userData);
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> registerCustomer(String name, String email, String password, String address, double lat, double lng) async {
    try {
      final response = await ApiService.post('users', {
        'name': name,
        'email': email,
        'password': password,
        'address': address,
        'lat': lat,
        'lng': lng,
        'role': 'customer',
      });

      return response['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserData);
    await prefs.remove(AppConstants.keyUserToken);
    await prefs.remove(AppConstants.keyUserRole);
  }

  static Future<bool> updateAddress(int userId, String address, double lat, double lng) async {
    try {
      final response = await ApiService.put('users?action=address', {
        'id': userId,
        'address': address,
        'lat': lat,
        'lng': lng,
      });

      if (response['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final userDataStr = prefs.getString(AppConstants.keyUserData);
        if (userDataStr != null) {
          final userData = jsonDecode(userDataStr);
          userData['address'] = address;
          userData['lat'] = lat;
          userData['lng'] = lng;
          await prefs.setString(AppConstants.keyUserData, jsonEncode(userData));
        }
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}

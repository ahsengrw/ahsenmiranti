import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    final decodedData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedData;
    } else {
      throw Exception(decodedData['message'] ?? 'An error occurred.');
    }
  }
}
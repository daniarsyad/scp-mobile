import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _token();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 &&
            (data['success'] == true || data['data'] != null),
        'statusCode': response.statusCode,
        'data': data['data'] ?? data,
        'day': data['day'],
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal koneksi: $e'};
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode >= 200 &&
            response.statusCode < 300 &&
            (data['success'] == true || data['data'] != null),
        'statusCode': response.statusCode,
        'data': data['data'] ?? data,
        'debug_otp': data['debug_otp'],
        'message': data['message']?.toString() ?? 'Terjadi kesalahan',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal koneksi: $e'};
    }
  }
}
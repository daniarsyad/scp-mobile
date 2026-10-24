import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']?['token'] ?? data['token'];
        final userJson = data['data']?['user'] ?? data['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          if (userJson != null) {
            await prefs.setString('user', jsonEncode(userJson));
          }
        }

        return {
          'success': true,
          'token': token,
          'user': userJson != null ? UserModel.fromJson(userJson) : null,
          'message': data['message'] ?? 'Login berhasil',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Login gagal',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal koneksi: $e',
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    await prefs.remove('token');
    await prefs.remove('user');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return null;
    return UserModel.fromJson(jsonDecode(userStr));
  }
}
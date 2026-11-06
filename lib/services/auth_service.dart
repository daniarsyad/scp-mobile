import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService({this.client});

  final http.Client? client;

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'identifier': identifier,
        'username': identifier,
        'password': password,
      });
      final response =
          await (client == null
                  ? http.post(uri, headers: headers, body: body)
                  : client!.post(uri, headers: headers, body: body))
              .timeout(const Duration(seconds: 15));

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'])
          : data;
      final token = payload['token'];
      final userJson = payload['user'];

      if (response.statusCode == 200 &&
          data['success'] != false &&
          (data['success'] == true || data['data'] is Map)) {
        if (token is! String || token.isEmpty || userJson is! Map) {
          return {
            'success': false,
            'statusCode': response.statusCode,
            'message': 'Respons login tidak memuat token dan profil pengguna.',
          };
        }

        final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(userJson));
        return {
          'success': true,
          'token': token,
          'user': user,
          'message': data['message'] ?? 'Login berhasil',
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'errors': data['errors'],
        'message': _responseMessage(data),
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal koneksi: $e'};
    }
  }

  String _responseMessage(Map<String, dynamic> data) {
    final parts = <String>[];
    final message = data['message']?.toString();
    if (message != null && message.isNotEmpty) parts.add(message);
    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final messages = entry.value is List
            ? entry.value as List
            : [entry.value];
        for (final error in messages) {
          parts.add('${entry.key}: $error');
        }
      }
    }
    return parts.isEmpty ? 'Login gagal' : parts.join('\n');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}');
        final headers = {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        await (client == null
                ? http.post(uri, headers: headers)
                : client!.post(uri, headers: headers))
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

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ApiService {
  ApiService({this.client});

  final http.Client? client;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _token();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = await _headers();
      final response =
          await (client == null
                  ? http.get(uri, headers: headers)
                  : client!.get(uri, headers: headers))
              .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success':
            response.statusCode == 200 &&
            (data['success'] == true || data['data'] != null),
        'statusCode': response.statusCode,
        'data': data['data'] ?? data,
        'day': data['day'],
        'summary': data['summary'],
        'student_summary': data['student_summary'],
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal koneksi: $e'};
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = await _headers();
      final response =
          await (client == null
                  ? http.post(uri, headers: headers, body: jsonEncode(body))
                  : client!.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return {
        'success':
            response.statusCode >= 200 &&
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

  Future<Map<String, dynamic>> postMultipart({
    required String path,
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileField,
    required String filename,
    required String contentType,
    required String idempotencyKey,
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'))
            ..headers.addAll(await _headers(json: false))
            ..headers['Idempotency-Key'] = idempotencyKey
            ..fields.addAll(fields)
            ..files.add(
              http.MultipartFile.fromBytes(
                fileField,
                fileBytes,
                filename: filename,
                contentType: http.MediaType.parse(contentType),
              ),
            );

      final streamed = client == null
          ? await request.send().timeout(const Duration(seconds: 30))
          : await client!.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final body = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'data': body['data'],
        'replayed': body['replayed'] == true,
        'errors': body['errors'],
        'message': body['message']?.toString() ?? '',
      };
    } catch (error) {
      return {
        'success': false,
        'statusCode': null,
        'message': 'Gagal koneksi: $error',
      };
    }
  }

  Future<http.Response> download(String path) async {
    final headers = await _headers(json: false);
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    return (client == null
            ? http.get(uri, headers: headers)
            : client!.get(uri, headers: headers))
        .timeout(const Duration(seconds: 30));
  }
}

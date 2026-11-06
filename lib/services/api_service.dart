import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../screens/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ApiService {
  ApiService({this.client});

  final http.Client? client;
  static bool _isRedirecting401 = false;

  static Future<void> _handleUnauthorized() async {
    if (_isRedirecting401) return;
    _isRedirecting401 = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');

      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirecting401 = false;
      });
    }
  }

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

      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'data': decoded};
      return {
        'success':
            response.statusCode == 200 &&
            data['success'] != false &&
            (data['success'] == true || data['data'] != null),
        'statusCode': response.statusCode,
        'data': data['data'] ?? data,
        'day': data['day'],
        'summary': data['summary'],
        'student_summary': data['student_summary'],
        'errors': data['errors'],
        'conflict_with': data['conflict_with'],
        'isConflict': response.statusCode == 409,
        'message': _responseMessage(
          data,
          response.statusCode == 401
              ? 'Sesi login telah berakhir. Silakan login kembali.'
              : response.statusCode == 403
              ? 'Anda tidak memiliki akses untuk data ini.'
              : response.statusCode == 409
              ? 'Jurnal untuk jadwal ini pada hari ini sudah pernah diisi.'
              : response.statusCode == 422
              ? 'Data tidak valid atau belum memenuhi syarat.'
              : response.statusCode >= 400
              ? 'Permintaan gagal (HTTP ${response.statusCode}).'
              : '',
        ),
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

      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'data': decoded};
      return {
        'success':
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data['success'] != false &&
            (data['success'] == true || data['data'] != null),
        'statusCode': response.statusCode,
        'data': data['data'] ?? data,
        'debug_otp': data['debug_otp'],
        'errors': data['errors'],
        'conflict_with': data['conflict_with'],
        'isConflict': response.statusCode == 409,
        'message': _responseMessage(
          data,
          response.statusCode == 401
              ? 'Sesi login telah berakhir. Silakan login kembali.'
              : response.statusCode == 403
              ? 'Anda tidak memiliki akses untuk tindakan ini.'
              : response.statusCode == 409
              ? 'Jurnal untuk jadwal ini pada hari ini sudah pernah diisi.'
              : response.statusCode == 422
              ? 'Data tidak valid atau belum memenuhi syarat.'
              : 'Permintaan gagal (HTTP ${response.statusCode}).',
        ),
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
      if (response.statusCode == 401) {
        await _handleUnauthorized();
      }

      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final body = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      return {
        'success':
            (response.statusCode == 200 || response.statusCode == 201) &&
            body['success'] != false,
        'statusCode': response.statusCode,
        'data': body['data'],
        'replayed': body['replayed'] == true,
        'errors': body['errors'],
        'conflict_with': body['conflict_with'],
        'isConflict': response.statusCode == 409,
        'message': _responseMessage(
          body,
          response.statusCode == 401
              ? 'Sesi login telah berakhir. Silakan login kembali.'
              : response.statusCode == 403
              ? 'Anda tidak memiliki akses untuk tindakan ini.'
              : response.statusCode == 409
              ? 'Jurnal untuk jadwal ini pada hari ini sudah pernah diisi.'
              : response.statusCode == 422
              ? 'Data tidak valid atau belum memenuhi syarat.'
              : response.statusCode >= 400
              ? 'Permintaan gagal (HTTP ${response.statusCode}).'
              : '',
        ),
      };
    } catch (error) {
      return {
        'success': false,
        'statusCode': null,
        'message': 'Gagal koneksi: $error',
      };
    }
  }

  String _responseMessage(Map<String, dynamic> body, String fallback) {
    final parts = <String>[];
    final message = body['message']?.toString();

    final isGeneric = message != null &&
        (message.toLowerCase().contains('given data was invalid') ||
         message.toLowerCase() == 'validation failed' ||
         message.toLowerCase() == 'validasi gagal');

    if (message != null && message.isNotEmpty && !isGeneric) {
      parts.add(message);
    }

    final errors = body['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final messages = entry.value is List
            ? entry.value as List
            : [entry.value];
        for (final error in messages) {
          if (error != null && error.toString().isNotEmpty) {
            final errStr = error.toString();
            if (!parts.contains(errStr)) {
              parts.add(errStr);
            }
          }
        }
      }
    } else if (errors is List) {
      for (final error in errors) {
        if (error != null && error.toString().isNotEmpty) {
          parts.add(error.toString());
        }
      }
    } else if (errors is String && errors.isNotEmpty) {
      parts.add(errors);
    }

    if (parts.isEmpty && message != null && message.isNotEmpty) {
      parts.add(message);
    }

    final conflict = body['conflict_with'];
    if (conflict is Map) {
      final details =
          [
                conflict['subject'],
                conflict['class'],
                conflict['room'],
                conflict['time'],
              ]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' • ');
      if (details.isNotEmpty) parts.add('Bentrok dengan: $details');
    }

    return parts.isEmpty ? fallback : parts.join('\n');
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

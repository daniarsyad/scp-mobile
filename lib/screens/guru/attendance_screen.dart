import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int journalId;
  final String subject;
  final String className;
  final ApiService? api;

  const AttendanceScreen({
    super.key,
    required this.journalId,
    required this.subject,
    required this.className,
    this.api,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final ApiService _api;
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.get(
      '${ApiConfig.attendanceByJournal}/${widget.journalId}',
    );

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        _items = data is List ? data : [];
      } else {
        _error = result['message'] ?? 'Gagal memuat presensi';
      }
    });
  }

  Color _color(String status) {
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Izin':
        return Colors.orange;
      case 'Sakit':
        return Colors.lightBlue;
      case 'Alpha':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _setStatus(int attendanceId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.attendanceUpdate}/$attendanceId/status',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status: $status'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Gagal update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showStatusPicker(Map item) {
    final id = item['id'] as int;
    final name = item['student']?['fullname'] ?? '-';

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Hadir'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Hadir');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.orange),
                title: const Text('Izin'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Izin');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.medical_services_outlined,
                  color: Colors.lightBlue,
                ),
                title: const Text('Sakit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Sakit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Alpha'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Alpha');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Siswa'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1D4ED8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelas: ${widget.className}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ketuk nama siswa → pilih Hadir / Izin / Sakit / Alpha',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada data presensi.\nIsi jurnal dulu agar daftar siswa muncul.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final name = item['student']?['fullname'] ?? '-';
                      final status = (item['status'] ?? 'Hadir').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _color(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _color(status),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _showStatusPicker(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

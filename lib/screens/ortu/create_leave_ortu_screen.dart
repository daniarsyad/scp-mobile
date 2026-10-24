import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class CreateLeaveOrtuScreen extends StatefulWidget {
  const CreateLeaveOrtuScreen({super.key});

  @override
  State<CreateLeaveOrtuScreen> createState() => _CreateLeaveOrtuScreenState();
}

class _CreateLeaveOrtuScreenState extends State<CreateLeaveOrtuScreen> {
  final _api = ApiService();
  final _reasonController = TextEditingController();

  List<dynamic> _children = [];
  int? _selectedChildId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  bool _loadingChildren = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final result = await _api.get(ApiConfig.children);
    setState(() {
      _loadingChildren = false;
      if (result['success'] == true) {
        final data = result['data'];
        _children = data is List ? data : [];
        if (_children.isNotEmpty) {
          _selectedChildId = _children.first['id'];
        }
      } else {
        _error = result['message'] ?? 'Gagal memuat data anak';
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Pilih tanggal';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_selectedChildId == null) {
      setState(() => _error = 'Pilih anak terlebih dahulu');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Tanggal wajib diisi');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _error = 'Alasan wajib diisi');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaveRequests}'),
      );

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['student_id'] = '$_selectedChildId';
      request.fields['start_date'] = _fmt(_startDate);
      request.fields['end_date'] = _fmt(_endDate);
      request.fields['reason'] = _reasonController.text.trim();

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      setState(() => _loading = false);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan izin anak berhasil dikirim'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'Gagal mengajukan';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Izin Anak'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: _loadingChildren
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedChildId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Anak',
                      border: OutlineInputBorder(),
                    ),
                    items: _children.map<DropdownMenuItem<int>>((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['fullname'] ?? '-'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedChildId = v),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal Mulai'),
                    subtitle: Text(_fmt(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal Selesai'),
                    subtitle: Text(_fmt(_endDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: false),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Alasan izin',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kirim Pengajuan'),
                  ),
                ],
              ),
            ),
    );
  }
}
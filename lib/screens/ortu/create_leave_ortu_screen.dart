import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/live_refresh.dart';

class CreateLeaveOrtuScreen extends StatefulWidget {
  final int? initialStudentId;

  const CreateLeaveOrtuScreen({super.key, this.initialStudentId});

  @override
  State<CreateLeaveOrtuScreen> createState() => _CreateLeaveOrtuScreenState();
}

class _CreateLeaveOrtuScreenState extends State<CreateLeaveOrtuScreen> {
  final _api = ApiService();
  final _reasonController = TextEditingController();
  final _picker = ImagePicker();

  List<dynamic> _children = [];
  int? _selectedChildId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _leaveType = 'Izin';
  XFile? _document;
  Uint8List? _docBytes;
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
    if (!mounted) return;
    setState(() {
      _loadingChildren = false;
      if (result['success'] == true) {
        final data = result['data'];
        _children = data is List ? data : [];
        if (_children.isNotEmpty) {
          final hasInitial =
              widget.initialStudentId != null &&
              _children.any((c) => '${c['id']}' == '${widget.initialStudentId}');
          _selectedChildId = hasInitial
              ? widget.initialStudentId
              : (_children.first['id'] is int
                    ? _children.first['id'] as int
                    : int.tryParse('${_children.first['id']}'));
        }
      } else {
        _error = result['message'] ?? 'Gagal memuat data anak';
      }
    });
  }

  Future<void> _pickDocument(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _document = x;
      _docBytes = bytes;
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
      request.fields['leave_type'] = _leaveType;

      if (_docBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'document',
            _docBytes!,
            filename: 'surat_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 25),
      );
      final response = await http.Response.fromStream(streamed);
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      setState(() => _loading = false);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        LiveRefresh.pingLeaves();
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
                    initialValue: _selectedChildId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Anak',
                      border: OutlineInputBorder(),
                    ),
                    items: _children.map<DropdownMenuItem<int>>((c) {
                      final childName = c['fullname']?.toString() ?? '-';
                      final className = (c['class'] is Map
                              ? c['class']['class_name']?.toString()
                              : null) ??
                          c['class_name']?.toString();
                      final label = className != null && className.isNotEmpty
                          ? '$childName ($className)'
                          : childName;
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(label),
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
                  DropdownButtonFormField<String>(
                    initialValue: _leaveType,
                    decoration: const InputDecoration(
                      labelText: 'Jenis izin',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                      DropdownMenuItem(value: 'Sakit', child: Text('Sakit')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _leaveType = value);
                    },
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
                  const SizedBox(height: 16),
                  const Text(
                    'Lampiran Surat / Foto Bukti (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDocument(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _document == null ? 'Kamera' : 'Foto Ulang',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDocument(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
                  if (_docBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _docBytes!,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
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

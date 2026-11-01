import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../utils/live_refresh.dart';

class CreateLeaveScreen extends StatefulWidget {
  const CreateLeaveScreen({super.key});

  @override
  State<CreateLeaveScreen> createState() => _CreateLeaveScreenState();
}

class _CreateLeaveScreenState extends State<CreateLeaveScreen> {
  final _reasonController = TextEditingController();
  final _picker = ImagePicker();
  DateTime? _startDate;
  DateTime? _endDate;
  String _leaveType = 'Izin';
  XFile? _document;
  Uint8List? _docBytes;
  bool _loading = false;
  String? _error;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickDocument(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _document = x;
      _docBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Pilih tanggal mulai dan selesai');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _error = 'Alasan wajib diisi');
      return;
    }
    if (_document == null) {
      setState(() => _error = 'Ambil foto surat dokter');
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

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['start_date'] = _startDate!.toIso8601String().substring(
        0,
        10,
      );
      request.fields['end_date'] = _endDate!.toIso8601String().substring(0, 10);
      request.fields['reason'] = _reasonController.text.trim();
      request.fields['leave_type'] = _leaveType;

      request.files.add(
        http.MultipartFile.fromBytes(
          'document',
          _docBytes!,
          filename: 'surat_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final payload = response.body.isEmpty ? null : jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(payload is Map && payload['success'] == false)) {
        LiveRefresh.pingLeaves();
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan izin berhasil'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final message = payload is Map ? payload['message']?.toString() : null;
        setState(() {
          _loading = false;
          _error = message ?? 'Gagal mengajukan izin (${response.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal koneksi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Izin'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanggal Mulai',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _pickDate(true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : 'Pilih tanggal',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tanggal Selesai',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _pickDate(false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'Pilih tanggal',
                ),
              ),
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
            const Text('Alasan', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Contoh: Sakit demam',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Foto Surat Dokter',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_document == null ? 'Galeri' : 'Ganti surat'),
                  ),
                ),
              ],
            ),
            if (_docBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_docBytes!, height: 150, fit: BoxFit.cover),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajukan Izin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

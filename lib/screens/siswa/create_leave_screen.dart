import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../utils/live_refresh.dart';
import '../../utils/photo_watermark.dart';

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
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
          }
        }
      });
    }
  }

  Future<void> _pickDocument({
    CameraDevice cameraDevice = CameraDevice.rear,
    bool isSelfie = false,
  }) async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
        preferredCameraDevice: cameraDevice,
      );
      if (x == null) return;
      var bytes = await x.readAsBytes();

      // Jika selfie dari kamera depan, un-mirror otomatis agar hasil foto tidak terbalik
      if (isSelfie || cameraDevice == CameraDevice.front) {
        bytes = flipImageHorizontal(bytes);
      }

      // Berikan watermark hari, tanggal, dan jam secara real-time
      bytes = applyJournalPhotoWatermark(bytes);

      if (!mounted) return;
      setState(() {
        _docBytes = bytes;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal mengambil gambar: $e');
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ambil Foto Real-Time (Kamera)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1D4ED8)),
                title: const Text('Kamera Belakang (Foto Surat / Bukti)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(
                    cameraDevice: CameraDevice.rear,
                    isSelfie: false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_front_outlined, color: Colors.teal),
                title: const Text('Kamera Depan (Selfie Tidak Terbalik)'),
                subtitle: const Text('Otomatis di-unmirror agar foto selfie tetap normal'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(
                    cameraDevice: CameraDevice.front,
                    isSelfie: true,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _flipPhoto() {
    if (_docBytes == null) return;
    setState(() {
      _docBytes = flipImageHorizontal(_docBytes!);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto berhasil dibalik (unmirror)'),
        duration: Duration(seconds: 1),
      ),
    );
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        ApiConfig.buildUri(ApiConfig.leaveRequests),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.fields['start_date'] = _startDate!.toIso8601String().substring(0, 10);
      request.fields['end_date'] = _endDate!.toIso8601String().substring(0, 10);
      request.fields['reason'] = _reasonController.text.trim();
      request.fields['leave_type'] = _leaveType;

      if (_docBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'document',
            _docBytes!,
            filename: 'surat_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: http.MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);

      dynamic payload;
      try {
        if (response.body.isNotEmpty) {
          payload = jsonDecode(response.body);
        }
      } catch (_) {
        payload = null;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !(payload is Map && payload['success'] == false)) {
        LiveRefresh.pingLeaves();
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan izin berhasil dikirim'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        String? message;
        if (payload is Map) {
          final errMap = payload['errors'];
          if (errMap is Map && errMap.isNotEmpty) {
            final errList = <String>[];
            for (final v in errMap.values) {
              if (v is List) {
                errList.addAll(v.map((e) => e.toString()));
              } else if (v != null) {
                errList.add(v.toString());
              }
            }
            if (errList.isNotEmpty) {
              message = errList.join('\n');
            }
          }
          message ??= payload['message']?.toString();
        }

        if (message == null || message.isEmpty) {
          final code = response.statusCode;
          if (code == 404) {
            message = 'Rute API pengajuan izin tidak ditemukan di server (404).';
          } else if (code == 500) {
            message = 'Terjadi kesalahan internal pada server (500).';
          } else if (code == 413) {
            message = 'Ukuran foto terlalu besar untuk server (413).';
          } else {
            message = 'Gagal mengajukan izin (HTTP $code).';
          }
        }

        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final str = e.toString();
      final cleanMsg = str.contains('SocketException') || str.contains('Failed host lookup')
          ? 'Gagal terhubung ke server. Pastikan HP dan server terkoneksi ke jaringan/Wi-Fi yang sama.'
          : str.contains('TimeoutException')
          ? 'Waktu koneksi habis (timeout). Silakan coba lagi.'
          : 'Gagal koneksi: $e';
      setState(() {
        _loading = false;
        _error = cleanMsg;
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
              'Foto Surat Dokter / Foto Bukti (Opsional)',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showImagePickerSheet,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _docBytes == null ? 'Ambil Foto Kamera' : 'Ambil Ulang Foto',
                ),
              ),
            ),
            if (_docBytes != null) ...[
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _docBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _flipPhoto,
                    icon: const Icon(Icons.flip_rounded, size: 18),
                    label: const Text('Balik Foto (Unmirror)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _docBytes = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
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


import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/live_refresh.dart';
import '../../utils/photo_watermark.dart';

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

  Future<void> _pickDocument({
    required ImageSource source,
    CameraDevice cameraDevice = CameraDevice.rear,
    bool isSelfie = false,
  }) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
        preferredCameraDevice: cameraDevice,
      );
      if (x == null) return;
      var bytes = await x.readAsBytes();

      if (isSelfie || cameraDevice == CameraDevice.front) {
        bytes = flipImageHorizontal(bytes);
      }

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
                  'Pilih Sumber Foto Lampiran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1D4ED8)),
                title: const Text('Kamera Belakang (Foto Dokumen / Surat)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(
                    source: ImageSource.camera,
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
                    source: ImageSource.camera,
                    cameraDevice: CameraDevice.front,
                    isSelfie: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.deepPurple),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(
                    source: ImageSource.gallery,
                    isSelfie: false,
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
      if (token != null && token.isNotEmpty) {
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        LiveRefresh.pingLeaves();
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan izin anak berhasil dikirim'),
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
            message = 'Ukuran lampiran foto terlalu besar (413).';
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
        title: const Text('Ajukan Izin Siswa (Orang Tua)'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: _loadingChildren
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Anak / Siswa',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  if (_children.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Tidak ada data anak terdaftar untuk akun ini.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedChildId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _children.map<DropdownMenuItem<int>>((c) {
                        final id = c['id'] is int
                            ? c['id'] as int
                            : int.parse('${c['id']}');
                        final name = c['fullname'] ?? '-';
                        final cls = c['class'] is Map
                            ? (c['class']['class_name'] ?? '')
                            : '';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('$name ${cls.isNotEmpty ? "($cls)" : ""}'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedChildId = v),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jenis Izin',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _leaveType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                      DropdownMenuItem(value: 'Sakit', child: Text('Sakit')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _leaveType = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tanggal Mulai',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickDate(isStart: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_fmt(_startDate)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tanggal Selesai',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _pickDate(isStart: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_fmt(_endDate)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Alasan / Keterangan',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Contoh: Anak sakit demam perlu istirahat',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lampiran Surat / Foto Bukti (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showImagePickerSheet,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        _docBytes == null ? 'Ambil Foto / Pilih Berkas' : 'Ganti Foto',
                      ),
                    ),
                  ),
                  if (_docBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _docBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
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

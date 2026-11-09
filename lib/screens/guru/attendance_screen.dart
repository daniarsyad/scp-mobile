import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/live_refresh.dart';

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
        final list = data is List ? List<dynamic>.from(data) : <dynamic>[];
        list.sort((a, b) {
          final nameA = (a['student']?['fullname'] ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '');
          final nameB = (b['student']?['fullname'] ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '');
          return nameA.compareTo(nameB);
        });
        _items = list;
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

  Future<void> _setStatus(int attendanceId, String status, [String? notes]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final body = <String, dynamic>{'status': status};
      if (notes != null) {
        body['notes'] = notes;
      }

      final response = await http
          .post(
            ApiConfig.buildUri(
              '${ApiConfig.attendanceUpdate}/$attendanceId/status',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded);
          }
        }
      } catch (_) {}
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        LiveRefresh.pingAttendances();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notes != null && notes.isNotEmpty
                ? 'Status: $status (Catatan tersimpan)'
                : 'Status: $status'),
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

  Future<void> _openNoteDialog(Map item) async {
    final id = item['id'] as int;
    final name = item['student']?['fullname'] ?? '-';
    final currentStatus = (item['status'] ?? 'Hadir').toString();
    final currentNote = (item['notes'] ?? '').toString();
    final controller = TextEditingController(text: currentNote);

    const quickNotes = [
      'Motong jam pelajaran',
      'Cabut setelah istirahat',
      'Meninggalkan kelas tanpa izin',
      'Terlambat masuk jam ke-2',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: ScpColors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Catatan: $name',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catatan siswa (misal: motong jam pelajaran):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: quickNotes.map((q) => ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 11)),
                  backgroundColor: ScpColors.blue.withValues(alpha: 0.08),
                  side: BorderSide(color: ScpColors.blue.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    controller.text = q;
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: currentNote.isEmpty,
                decoration: InputDecoration(
                  hintText: 'Ketik catatan di sini...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (currentNote.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ScpColors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _setStatus(id, currentStatus, '');
              },
              child: const Text('Hapus Catatan'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _setStatus(id, currentStatus, controller.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker(Map item) {
    final id = item['id'] as int;
    final name = item['student']?['fullname'] ?? '-';
    final currentStatus = (item['status'] ?? 'Hadir').toString();
    final currentNote = (item['notes'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                trailing: currentStatus == 'Hadir' ? const Icon(Icons.check, color: ScpColors.blue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Hadir');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.orange),
                title: const Text('Izin'),
                trailing: currentStatus == 'Izin' ? const Icon(Icons.check, color: ScpColors.blue) : null,
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
                trailing: currentStatus == 'Sakit' ? const Icon(Icons.check, color: ScpColors.blue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Sakit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Alpha'),
                trailing: currentStatus == 'Alpha' ? const Icon(Icons.check, color: ScpColors.blue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatus(id, 'Alpha');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: ScpColors.blue),
                title: const Text(
                  'Catatan Siswa',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  currentNote.isNotEmpty
                      ? currentNote
                      : 'Ketik catatan khusus untuk siswa ini...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: currentNote.isNotEmpty ? Colors.amber.shade900 : Colors.grey,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _openNoteDialog(item);
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
                      final notes = (item['notes'] ?? '').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ScpColors.text,
                              ),
                            ),
                          ),
                          title: Text(
                            '${index + 1}. $name',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: notes.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Catatan: $notes',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
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

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../utils/live_refresh.dart';
import 'attendance_screen.dart';

class CreateJournalScreen extends StatefulWidget {
  final Map<String, dynamic> schedule;

  const CreateJournalScreen({super.key, required this.schedule});

  @override
  State<CreateJournalScreen> createState() => _CreateJournalScreenState();
}

class _CreateJournalScreenState extends State<CreateJournalScreen> {
  final _topicController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photo;
  Uint8List? _photoBytes;
  bool _loading = false;
  String? _error;

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();
    setState(() {
      _photo = x;
      _photoBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_topicController.text.trim().isEmpty) {
      setState(() => _error = 'Topik wajib diisi');
      return;
    }
    if (_photo == null || _photoBytes == null) {
      setState(() => _error = 'Foto wajib diambil');
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
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.journals}'),
      );

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['schedule_id'] = '${widget.schedule['id']}';
      request.fields['topic_description'] = _topicController.text.trim();

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          _photoBytes!,
          filename: _photo!.name.isNotEmpty ? _photo!.name : 'foto.jpg',
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      setState(() => _loading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == false) {
          setState(() => _error = body['message']?.toString() ?? 'Gagal menyimpan jurnal');
          return;
        }
        LiveRefresh.pingJournals();
        final data = body['data'];
        final journalId = data is Map ? data['id'] : null;

        final subject = widget.schedule['subject']?.toString() ?? '-';
        final className = widget.schedule['class']?['class_name']?.toString() ?? '-';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jurnal tersimpan. Silakan cek presensi siswa.'),
            backgroundColor: Colors.green,
          ),
        );

        if (journalId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AttendanceScreen(
                journalId: journalId is int ? journalId : int.tryParse('$journalId') ?? 0,
                subject: subject,
                className: className,
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = 'Gagal simpan (${response.statusCode}): ${response.body}';
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
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final subject = s['subject'] ?? '-';
    final className = s['class']?['class_name'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Isi Jurnal'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Kelas: $className'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _topicController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Topik / Materi hari ini',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_photo == null ? 'Galeri' : 'Ganti foto'),
                  ),
                ),
              ],
            ),
            if (_photoBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _photoBytes!,
                  height: 180,
                  width: double.infinity,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan Jurnal'),
            ),
          ],
        ),
      ),
    );
  }
}
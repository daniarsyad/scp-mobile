import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/journal_draft_store.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import 'attendance_screen.dart';

class CreateJournalScreen extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final int ownerId;
  final ApiService? api;
  final JournalDraftStore? draftStore;
  final Future<XFile?> Function(ImageSource source)? pickImage;

  const CreateJournalScreen({
    super.key,
    required this.schedule,
    this.ownerId = 0,
    this.api,
    this.draftStore,
    this.pickImage,
  });

  @override
  State<CreateJournalScreen> createState() => _CreateJournalScreenState();
}

class _CreateJournalScreenState extends State<CreateJournalScreen> {
  static const _statuses = ['Hadir', 'Izin', 'Sakit', 'Alpha'];
  static const _maxPhotoBytes = 2 * 1024 * 1024;

  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  late final JournalDraftStore _store;
  late final ApiService _api;
  JournalDraft? _draft;
  List<Map<String, dynamic>> _roster = [];
  Future<void> _saveQueue = Future<void>.value();
  bool _loadingDraft = true;
  bool _submitting = false;
  bool _saveFailed = false;
  String _search = '';
  String? _error;

  int get _scheduleId => _readInt(widget.schedule['id']);
  String get _date {
    final value = widget.schedule['date']?.toString();
    return value != null && value.length >= 10
        ? value.substring(0, 10)
        : todayIso();
  }

  bool get _submissionUncertain => _draft?.submissionUncertain ?? false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _store = widget.draftStore ?? JournalDraftStore();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      if (_scheduleId <= 0) {
        throw const FormatException('Jadwal tidak memiliki ID yang valid.');
      }

      final classData = _asMap(widget.schedule['class']);
      final students = classData['students'];
      if (students is! List) {
        throw const FormatException(
          'Roster siswa tidak ditemukan pada data kelas jadwal.',
        );
      }
      _roster = students.map(_asMap).map((student) {
        final id = _readInt(student['id']);
        if (id <= 0) {
          throw const FormatException(
            'Roster berisi siswa tanpa ID yang valid.',
          );
        }
        return {
          'student_id': id,
          'fullname':
              student['fullname']?.toString() ??
              student['name']?.toString() ??
              'Siswa',
          'nisn': student['nisn']?.toString() ?? '',
        };
      }).toList();
      if (_roster.isEmpty) {
        throw const FormatException('Roster siswa untuk jadwal ini kosong.');
      }

      var draft = await _store.load(widget.ownerId, _scheduleId, _date);
      if (draft == null) {
        draft = JournalDraft(
          ownerId: widget.ownerId,
          scheduleId: _scheduleId,
          date: _date,
          idempotencyKey: _store.newIdempotencyKey(),
          topic: '',
          activityNotes: '',
          attendances: _roster
              .map(
                (student) => {
                  'student_id': student['student_id'],
                  'status': 'Hadir',
                },
              )
              .toList(),
        );
        await _store.save(draft);
      } else {
        final oldIds = draft.attendances
            .map((item) => _readInt(item['student_id']))
            .toSet();
        final newIds = _roster.map((item) => item['student_id'] as int).toSet();
        if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
          if (draft.submissionUncertain) {
            _error =
                'Roster berubah setelah pengiriman yang hasilnya belum pasti. '
                'Draf dikunci agar payload dan Idempotency-Key tidak berubah.';
          } else {
            final oldStatuses = {
              for (final item in draft.attendances)
                _readInt(item['student_id']): item['status']?.toString(),
            };
            draft = draft.copyWith(
              idempotencyKey: _store.newIdempotencyKey(),
              submissionAttempted: false,
              attendances: _roster
                  .map(
                    (student) => {
                      'student_id': student['student_id'],
                      'status': oldStatuses[student['student_id']] ?? 'Hadir',
                    },
                  )
                  .toList(),
            );
            await _store.save(draft);
          }
        }
      }

      _draft = draft;
      _topicController.text = draft.topic;
      _notesController.text = draft.activityNotes;
    } catch (error) {
      _error = 'Gagal memuat draf presensi: $error';
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  void _updateDraft(JournalDraft updated, {bool edited = true}) {
    final current = _draft;
    if (current == null || current.submissionUncertain || _submitting) return;
    if (edited && current.submissionAttempted) {
      updated = updated.copyWith(
        idempotencyKey: _store.newIdempotencyKey(),
        submissionAttempted: false,
      );
    }
    updated = updated.copyWith(
      topic: _topicController.text,
      activityNotes: _notesController.text,
    );
    _draft = updated;
    setState(() {});
    _enqueueSave(updated);
  }

  void _enqueueSave(JournalDraft snapshot) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) async {
      try {
        await _store.save(snapshot);
        _saveFailed = false;
      } catch (error) {
        _saveFailed = true;
        if (!mounted) return;
        setState(() {
          _error = 'Gagal menyimpan draf lokal: $error';
        });
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_submissionUncertain) return;
    try {
      final photo = widget.pickImage == null
          ? await _picker.pickImage(
              source: source,
              imageQuality: 70,
              preferredCameraDevice: CameraDevice.rear,
            )
          : await widget.pickImage!(source);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        setState(() => _error = 'Ukuran foto maksimal 2 MiB.');
        return;
      }

      final contentType = _imageContentType(photo);
      if (contentType == null) {
        setState(() => _error = 'Foto harus berformat JPEG atau PNG.');
        return;
      }
      final draft = _draft;
      if (draft == null) return;
      _updateDraft(
        draft.copyWith(
          photoBase64: base64Encode(bytes),
          photoName: photo.name.isEmpty ? 'dokumentasi.jpg' : photo.name,
          photoContentType: contentType,
        ),
      );
      setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memilih foto: $error');
    }
  }

  String? _imageContentType(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime == 'image/jpeg' || mime == 'image/png') return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    return null;
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null) return;
    if (_submissionUncertain && !draft.submissionAttempted) {
      setState(
        () => _error = 'Draf perlu dimuat ulang sebelum dicoba kembali.',
      );
      return;
    }
    if (_topicController.text.trim().isEmpty) {
      setState(() => _error = 'Topik wajib diisi.');
      return;
    }
    final photoBytes = draft.photoBytes;
    if (photoBytes == null || draft.photoName == null) {
      setState(() => _error = 'Foto dokumentasi wajib dipilih.');
      return;
    }
    if (photoBytes.length > _maxPhotoBytes) {
      setState(() => _error = 'Ukuran foto maksimal 2 MiB.');
      return;
    }
    if (draft.attendances.length != _roster.length ||
        draft.attendances.any(
          (item) =>
              !_statuses.contains(item['status']) ||
              _readInt(item['student_id']) <= 0,
        )) {
      setState(() => _error = 'Pastikan status presensi semua siswa lengkap.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final submittingDraft = draft.copyWith(
      topic: _topicController.text.trim(),
      activityNotes: _notesController.text.trim(),
      submissionAttempted: true,
    );
    _draft = submittingDraft;
    _enqueueSave(submittingDraft);

    try {
      await _saveQueue;
      if (_saveFailed) {
        if (mounted) {
          setState(() {
            _error = 'Draf gagal disimpan di perangkat, jadi belum dikirim.';
            _submitting = false;
          });
        }
        return;
      }
      final fields = <String, String>{
        'schedule_id': '${submittingDraft.scheduleId}',
        'date': submittingDraft.date,
        'topic_description': submittingDraft.topic,
        if (submittingDraft.activityNotes.isNotEmpty)
          'activity_notes': submittingDraft.activityNotes,
      };
      for (var index = 0; index < submittingDraft.attendances.length; index++) {
        final attendance = submittingDraft.attendances[index];
        fields['attendances[$index][student_id]'] =
            '${attendance['student_id']}';
        fields['attendances[$index][status]'] = attendance['status'].toString();
      }

      final result = await _api.postMultipart(
        path: ApiConfig.journals,
        fields: fields,
        fileBytes: photoBytes,
        fileField: 'photo',
        filename: submittingDraft.photoName!,
        contentType: submittingDraft.photoContentType ?? 'image/jpeg',
        idempotencyKey: submittingDraft.idempotencyKey,
      );
      if (!mounted) return;

      final statusCode = result['statusCode'];
      final responseData = _asMap(result['data']);
      final journalId = _readInt(responseData['id']);
      if ((statusCode == 200 || statusCode == 201) &&
          result['success'] == true &&
          journalId > 0) {
        await _store.delete(
          submittingDraft.ownerId,
          submittingDraft.scheduleId,
          submittingDraft.date,
        );
        LiveRefresh.pingJournals();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              journalId: journalId,
              subject: widget.schedule['subject']?.toString() ?? '-',
              className:
                  _asMap(widget.schedule['class'])['class_name']?.toString() ??
                  '-',
              api: _api,
            ),
          ),
        );
        return;
      }

      final message = _responseMessage(result);
      if (statusCode == 409 ||
          statusCode == null ||
          statusCode >= 500 ||
          statusCode == 200 ||
          statusCode == 201) {
        _draft = submittingDraft.copyWith(submissionUncertain: true);
        _enqueueSave(_draft!);
        setState(() {
          _error = statusCode == 409
              ? '$message Draf dikunci; jangan ubah payload sebelum status sesi dipastikan.'
              : '$message Hasil pengiriman belum pasti. Tekan coba lagi untuk mengirim payload dan key yang sama.';
        });
      } else {
        _draft = submittingDraft.copyWith(submissionUncertain: false);
        _enqueueSave(_draft!);
        setState(() {
          _error = message;
        });
      }
    } catch (error) {
      if (mounted) {
        _draft = submittingDraft.copyWith(submissionUncertain: true);
        _enqueueSave(_draft!);
        setState(() {
          _error =
              'Hasil pengiriman belum pasti: $error. Draf dan key dipertahankan untuk retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _responseMessage(Map<String, dynamic> result) {
    final message = result['message']?.toString();
    final errors = result['errors'];
    if (errors is Map) {
      final details = errors.values
          .expand((value) => value is List ? value : [value])
          .map((value) => value.toString())
          .join('\n');
      if (details.isNotEmpty) return '$message\n$details';
    }
    final status = result['statusCode'];
    if (status == 409) {
      return message?.isNotEmpty == true
          ? message!
          : 'Sesi telah memiliki jurnal atau data berubah di server.';
    }
    if (status == 422) {
      return message?.isNotEmpty == true
          ? message!
          : 'Data tidak lolos validasi. Periksa kembali isian.';
    }
    if (status == 401) return 'Sesi berakhir. Silakan login kembali.';
    if (status == 403) return 'Anda tidak memiliki akses untuk jadwal ini.';
    return message?.isNotEmpty == true
        ? message!
        : 'Gagal menyimpan jurnal (${status ?? 'jaringan'}).';
  }

  List<Map<String, dynamic>> get _visibleStudents {
    if (_search.trim().isEmpty) return _roster;
    final query = _search.toLowerCase();
    return _roster.where((student) {
      return student['fullname'].toString().toLowerCase().contains(query) ||
          student['nisn'].toString().toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _chooseStatus(Map<String, dynamic> student) async {
    if (_submissionUncertain) return;
    final studentId = student['student_id'] as int;
    final current = _draft?.attendances
        .firstWhere(
          (item) => _readInt(item['student_id']) == studentId,
          orElse: () => {'status': 'Hadir'},
        )['status']
        ?.toString();
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                student['fullname'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final status in _statuses)
              ListTile(
                title: Text(status),
                trailing: current == status ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, status),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final draft = _draft;
    if (draft == null) return;
    final attendances = draft.attendances
        .map(
          (item) => _readInt(item['student_id']) == studentId
              ? {...item, 'status': selected}
              : item,
        )
        .toList();
    _updateDraft(draft.copyWith(attendances: attendances));
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classData = _asMap(widget.schedule['class']);
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Jurnal & Presensi'),
        actions: [
          if (draft != null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Draf lokal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: _loadingDraft
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _draft == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _buildForm(classData, draft),
    );
  }

  Widget _buildForm(Map<String, dynamic> classData, JournalDraft? draft) {
    final photoBytes = draft?.photoBytes;
    final locked = _submissionUncertain;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Card(
          child: ListTile(
            title: Text(
              widget.schedule['subject']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Kelas: ${classData['class_name'] ?? '-'}  •  ${draft?.date ?? _date}',
            ),
          ),
        ),
        if (locked)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Draf terkunci karena hasil pengiriman sebelumnya belum pasti. '
              'Retry akan menggunakan payload dan Idempotency-Key yang sama.',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('journal-topic'),
          controller: _topicController,
          enabled: !locked,
          onChanged: (_) => _updateDraft(draft!),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Topik / materi pembelajaran',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('journal-activity-notes'),
          controller: _notesController,
          enabled: !locked,
          onChanged: (_) => _updateDraft(draft!),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Catatan kegiatan kelas (opsional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(photoBytes == null ? 'Galeri' : 'Ganti foto'),
              ),
            ),
          ],
        ),
        if (photoBytes != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              Uint8List.fromList(photoBytes),
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          TextButton.icon(
            onPressed: locked
                ? null
                : () => _updateDraft(draft!.copyWith(removePhoto: true)),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus foto'),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Presensi Siswa (${_roster.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          enabled: !locked,
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            hintText: 'Cari nama atau NISN',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        for (final student in _visibleStudents)
          _studentTile(student, draft, locked),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting || draft == null ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _submitting
                ? 'Mengirim...'
                : locked
                ? 'Coba Lagi'
                : 'Selesai & Simpan Jurnal',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Draf tersimpan di perangkat. Data baru dikirim setelah tombol ini ditekan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _studentTile(
    Map<String, dynamic> student,
    JournalDraft? draft,
    bool locked,
  ) {
    final id = student['student_id'];
    final attendance = draft?.attendances.firstWhere(
      (item) => _readInt(item['student_id']) == id,
      orElse: () => {'status': 'Hadir'},
    );
    final status = attendance?['status']?.toString() ?? 'Hadir';
    return Card(
      child: ListTile(
        title: Text(student['fullname'].toString()),
        subtitle: Text(
          student['nisn'].toString().isEmpty
              ? 'Status presensi'
              : 'NISN ${student['nisn']}',
        ),
        trailing: DropdownButton<String>(
          value: _statuses.contains(status) ? status : 'Hadir',
          onChanged: locked
              ? null
              : (value) {
                  if (value == null || draft == null) return;
                  final attendanceList = draft.attendances
                      .map(
                        (item) => _readInt(item['student_id']) == id
                            ? {...item, 'status': value}
                            : item,
                      )
                      .toList();
                  _updateDraft(draft.copyWith(attendances: attendanceList));
                },
          items: _statuses
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
        ),
        onTap: locked ? null : () => _chooseStatus(student),
      ),
    );
  }
}

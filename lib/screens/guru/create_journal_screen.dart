import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/journal_draft_store.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../utils/photo_watermark.dart';

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
      var students = _classStudents(classData);
      if (students == null || students.isEmpty) {
        final classId = _readInt(
          classData['id'] ??
              classData['class_id'] ??
              widget.schedule['class_id'],
        );
        if (classId <= 0) {
          throw const FormatException(
            'ID kelas tidak tersedia untuk memuat roster siswa.',
          );
        }
        final result = await _api.get(ApiConfig.classes);
        if (result['success'] != true) {
          throw StateError(
            result['message']?.toString().isNotEmpty == true
                ? result['message'].toString()
                : 'Gagal memuat daftar kelas.',
          );
        }
        final classesData = result['data'];
        final classes = classesData is List
            ? classesData
            : _asMap(classesData)['data'] is List
            ? _asMap(classesData)['data'] as List
            : const [];
        Map<String, dynamic>? matchingClass;
        for (final item in classes) {
          final candidate = _asMap(item);
          if (_readInt(candidate['id'] ?? candidate['class_id']) == classId) {
            matchingClass = candidate;
            break;
          }
        }
        if (matchingClass != null) {
          students =
              _classStudents(matchingClass) ??
              _classStudents(_asMap(matchingClass['class'])) ??
              _classStudents(classData);
        }
      }
      if (students == null) {
        throw const FormatException(
          'Endpoint daftar kelas tidak menyertakan roster siswa untuk kelas ini.',
        );
      }
      _roster = students.map(_asMap).map((student) {
        final nestedStudent = _asMap(student['student']);
        final id = _readInt(
          student['id'] ?? student['student_id'] ?? nestedStudent['id'],
        );
        if (id <= 0) {
          throw const FormatException(
            'Roster berisi siswa tanpa ID yang valid.',
          );
        }
        return {
          'student_id': id,
          'fullname':
              student['fullname']?.toString() ??
              nestedStudent['fullname']?.toString() ??
              student['name']?.toString() ??
              'Siswa',
          'nisn':
              student['nisn']?.toString() ??
              nestedStudent['nisn']?.toString() ??
              '',
        };
      }).toList();
      _roster.sort((a, b) {
        final nameA = (a['fullname'] ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '');
        final nameB = (b['fullname'] ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '');
        return nameA.compareTo(nameB);
      });
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
                  'notes': '',
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
            final oldNotes = {
              for (final item in draft.attendances)
                _readInt(item['student_id']): item['notes']?.toString(),
            };
            draft = draft.copyWith(
              idempotencyKey: _store.newIdempotencyKey(),
              submissionAttempted: false,
              attendances: _roster
                  .map(
                    (student) => {
                      'student_id': student['student_id'],
                      'status': oldStatuses[student['student_id']] ?? 'Hadir',
                      'notes': oldNotes[student['student_id']] ?? '',
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

  Future<void> _pickPhoto() async {
    if (_submissionUncertain) return;
    try {
      final photo = widget.pickImage == null
          ? await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 70,
              preferredCameraDevice: CameraDevice.rear,
            )
          : await widget.pickImage!(ImageSource.camera);
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

      // Berikan watermark hari, tanggal, dan jam real-time pada foto
      // Catatan: Jika pickImage di-inject untuk test, jangan modifikasi bytes agar contract test tetap terjaga
      final watermarkedBytes = widget.pickImage == null
          ? applyJournalPhotoWatermark(bytes)
          : bytes;

      final draft = _draft;
      if (draft == null) return;
      _updateDraft(
        draft.copyWith(
          photoBase64: base64Encode(watermarkedBytes),
          photoName: photo.name.isEmpty ? 'dokumentasi.jpg' : photo.name,
          photoContentType: widget.pickImage == null ? 'image/jpeg' : contentType,
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
    if (scheduleNotStarted(widget.schedule)) {
      final start = formatTime(widget.schedule['start_time']);
      setState(() => _error = 'Jurnal belum dapat disimpan karena jam pelajaran belum dimulai ($start).');
      return;
    }
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
        final note = attendance['notes']?.toString() ?? '';
        if (note.isNotEmpty) {
          fields['attendances[$index][notes]'] = note;
        }
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
        LiveRefresh.pingAttendances();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jurnal dan presensi siswa berhasil disimpan!'),
            backgroundColor: ScpColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
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

  void _setStudentNote(int studentId, String note) {
    final draft = _draft;
    if (draft == null) return;
    final attendances = draft.attendances
        .map(
          (item) => _readInt(item['student_id']) == studentId
              ? {...item, 'notes': note.trim()}
              : item,
        )
        .toList();
    _updateDraft(draft.copyWith(attendances: attendances));
  }

  Future<void> _openNoteDialog(Map<String, dynamic> student, [JournalDraft? draftState]) async {
    if (_submissionUncertain) return;
    final studentId = student['student_id'] as int;
    final draft = draftState ?? _draft;
    final attendance = draft?.attendances.firstWhere(
      (item) => _readInt(item['student_id']) == studentId,
      orElse: () => {'status': 'Hadir', 'notes': ''},
    );
    final currentNote = attendance?['notes']?.toString() ?? '';
    final controller = TextEditingController(text: currentNote);

    const quickNotes = [
      'Nyekip jam pelajaran',
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
                'Catatan: ${student['fullname']}',
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
                'Catatan khusus jika siswa memotong jam / nyekip pelajaran:',
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
                _setStudentNote(studentId, '');
                Navigator.pop(ctx);
              },
              child: const Text('Hapus Catatan'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              _setStudentNote(studentId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseStatus(Map<String, dynamic> student) async {
    if (_submissionUncertain) return;
    final studentId = student['student_id'] as int;
    final attendance = _draft?.attendances.firstWhere(
      (item) => _readInt(item['student_id']) == studentId,
      orElse: () => {'status': 'Hadir', 'notes': ''},
    );
    final current = attendance?['status']?.toString() ?? 'Hadir';
    final currentNote = attendance?['notes']?.toString() ?? '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                student['fullname'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final status in _statuses)
              ListTile(
                title: Text(
                  status,
                  style: TextStyle(
                    fontWeight: current == status ? FontWeight.bold : FontWeight.normal,
                    color: status == 'Alpha' ? ScpColors.red : null,
                  ),
                ),
                trailing: current == status ? const Icon(Icons.check, color: ScpColors.blue) : null,
                onTap: () => Navigator.pop(context, status),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: ScpColors.blue),
              title: const Text(
                'Catatan Siswa (Nyekip / Motong Jam)',
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
                  fontWeight: currentNote.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _openNoteDialog(student);
              },
            ),
            const SizedBox(height: 8),
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
    if (selected == 'Alpha' && currentNote.isEmpty) {
      _openNoteDialog(student);
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic>? _classStudents(Map<String, dynamic> classData) {
    for (final key in [
      'students',
      'roster',
      'student_list',
      'class_students',
    ]) {
      final value = classData[key];
      if (value is List) return value;
      final nestedData = _asMap(value)['data'];
      if (nestedData is List) return nestedData;
    }
    return null;
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: locked ? null : _pickPhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(photoBytes == null ? 'Ambil foto' : 'Ambil ulang foto'),
          ),
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
        for (var i = 0; i < _visibleStudents.length; i++)
          _studentTile(_visibleStudents[i], draft, locked, i + 1),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (scheduleNotStarted(widget.schedule))
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Color(0xFFB91C1C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jadwal KBM ini belum dimulai (Pukul ${formatTime(widget.schedule['start_time'])}). Jurnal hanya dapat diisi saat jam pelajaran berlangsung.',
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting || draft == null || scheduleNotStarted(widget.schedule) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(scheduleNotStarted(widget.schedule) ? Icons.lock_clock_rounded : Icons.cloud_upload_outlined),
          label: Text(
            _submitting
                ? 'Mengirim...'
                : scheduleNotStarted(widget.schedule)
                ? 'Belum Masuk Jam Pelajaran'
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
    int number,
  ) {
    final id = student['student_id'];
    final attendance = draft?.attendances.firstWhere(
      (item) => _readInt(item['student_id']) == id,
      orElse: () => {'status': 'Hadir', 'notes': ''},
    );
    final status = attendance?['status']?.toString() ?? 'Hadir';
    final notes = attendance?['notes']?.toString() ?? '';
    final isAlpha = status == 'Alpha';
    final hasNotes = notes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAlpha
              ? ScpColors.red.withValues(alpha: 0.35)
              : (hasNotes ? Colors.amber.shade400 : Colors.grey.shade200),
          width: (isAlpha || hasNotes) ? 1.5 : 1,
        ),
      ),
      color: isAlpha
          ? ScpColors.red.withValues(alpha: 0.03)
          : (hasNotes ? Colors.amber.shade50.withValues(alpha: 0.35) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              '$number. ${student['fullname']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Row(
              children: [
                Text(
                  student['nisn'].toString().isEmpty
                      ? 'Status presensi'
                      : 'NISN ${student['nisn']}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (!isAlpha && !hasNotes) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: locked ? null : () => _openNoteDialog(student, draft),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        '+ Catatan',
                        style: TextStyle(
                          fontSize: 11,
                          color: ScpColors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: DropdownButton<String>(
              value: _statuses.contains(status) ? status : 'Hadir',
              underline: const SizedBox(),
              onChanged: locked
                  ? null
                  : (value) {
                      if (value == null || draft == null) return;
                      if (value == '__note__') {
                        _openNoteDialog(student, draft);
                        return;
                      }
                      final attendanceList = draft.attendances
                          .map(
                            (item) => _readInt(item['student_id']) == id
                                ? {...item, 'status': value}
                                : item,
                          )
                          .toList();
                      _updateDraft(draft.copyWith(attendances: attendanceList));
                      if (value == 'Alpha' && notes.isEmpty) {
                        _openNoteDialog(student, draft);
                      }
                    },
              items: [
                ..._statuses.map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: value == 'Alpha'
                            ? ScpColors.red
                            : (value == 'Hadir' ? Colors.green.shade700 : null),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: '__note__',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Text(
                        notes.isNotEmpty ? 'Catatan (Ada)' : 'Catatan (Nyekip/Motong Jam)',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: locked ? null : () => _chooseStatus(student),
          ),
          if (isAlpha || hasNotes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: locked ? null : () => _openNoteDialog(student, draft),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasNotes
                        ? Colors.amber.shade50
                        : ScpColors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasNotes
                          ? Colors.amber.shade300
                          : ScpColors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: hasNotes ? Colors.amber.shade900 : ScpColors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasNotes
                              ? 'Catatan: $notes'
                              : 'Klik untuk mengisi catatan (misal: nyekip jam pelajaran)...',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasNotes ? Colors.amber.shade900 : Colors.grey.shade700,
                            fontWeight: hasNotes ? FontWeight.w600 : FontWeight.normal,
                            fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ),
                      if (!locked && hasNotes)
                        GestureDetector(
                          onTap: () => _setStudentNote(student['student_id'] as int, ''),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          ),
                        )
                      else if (!locked)
                        Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

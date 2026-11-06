import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../theme/scp_theme.dart';
import '../utils/format.dart';
import '../widgets/dashboard_kit.dart';

class AttendanceReportScreen extends StatefulWidget {
  final bool isBk;
  final bool embedded;
  final UserModel? user;

  const AttendanceReportScreen({
    super.key,
    required this.isBk,
    this.embedded = false,
    this.user,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final _api = ApiService();
  DateTime _date = DateTime.now();
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  bool _loading = true;
  bool _filtersLoading = true;
  String? _error;
  String? _filterError;
  List<Map<String, dynamic>> _attendances = [];
  List<Map<String, dynamic>> _classList = [];
  Map<String, dynamic> _filterOptions = {};
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _studentSummary = [];
  bool _dateRangeMode = false;
  bool _exporting = false;
  String _selectedClassId = '';
  String _selectedGrade = '';
  String _selectedMajor = '';
  String _selectedSection = '';
  String _selectedTeacherId = '';
  String _selectedPeriodId = '';

  // Filter states
  String _selectedClass = 'Semua Kelas';
  String _selectedStatus = 'Semua Status';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String get _dateValue =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  bool get _isWaliKelasOnly =>
      !widget.isBk || (widget.user != null && widget.user!.isWaliKelas);

  String? get _waliClassName {
    final name = widget.user?.className;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (!_isWaliKelasOnly) _loadFilters();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final result = await _api.get(ApiConfig.attendanceReportFilters);
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _filtersLoading = false;
        _filterError = result['message']?.toString().isNotEmpty == true
            ? result['message'].toString()
            : 'Gagal memuat opsi filter laporan presensi.';
      });
      return;
    }

    final data = asMap(result['data']);
    final filters = asMap(data['filters']).isNotEmpty
        ? asMap(data['filters'])
        : data;
    final classes = _optionsFrom(filters, ['classes', 'class']);
    setState(() {
      _filtersLoading = false;
      _filterOptions = filters;
      _classList = [
        for (final option in classes)
          {'id': option.id, 'class_name': option.name},
      ];
      _filterError = null;
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final params = _reportParams();
    final path = Uri(
      path: ApiConfig.attendanceReport,
      queryParameters: params,
    ).toString();

    final result = await _api.get(path);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _loading = false;
        final data = result['data'];
        final nestedData = asMap(data);
        _attendances = asList(
          data is Map ? data['attendances'] ?? data['data'] : data,
        ).map(asMap).toList();
        _summary = asMap(result['summary']).isNotEmpty
            ? asMap(result['summary'])
            : asMap(nestedData['summary']);
        _studentSummary = asList(
          result['student_summary'] ?? nestedData['student_summary'],
        ).map(asMap).toList();
        final availablePeriodIds = _options(['periods', 'period'])
            .map((period) => period.id)
            .toSet();
        if (!availablePeriodIds.contains(_selectedPeriodId)) {
          _selectedPeriodId = '';
        }
      });
    } else {
      setState(() {
        _loading = false;
        _error =
            result['message']?.toString() ?? 'Gagal memuat laporan presensi';
      });
    }
  }

  Map<String, String> _reportParams() {
    final params = <String, String>{
      if (_dateRangeMode) ...{
        'from_date': _dateString(_range.start),
        'to_date': _dateString(_range.end),
      } else
        'date': _dateValue,
    };
    if (!_isWaliKelasOnly && _selectedClassId.isNotEmpty) {
      params['class_id'] = _selectedClassId;
    }
    if (_selectedGrade.isNotEmpty) {
      params['grade'] = _selectedGrade;
    }
    if (_selectedMajor.isNotEmpty) {
      params['major'] = _selectedMajor;
    }
    if (_selectedSection.isNotEmpty) {
      params['section'] = _selectedSection;
    }
    if (_selectedTeacherId.isNotEmpty) {
      params['teacher_id'] = _selectedTeacherId;
    }
    if (_selectedPeriodId.isNotEmpty) {
      params['period_id'] = _selectedPeriodId;
    }
    return params;
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  List<({String id, String name})> _options(List<String> keys) =>
      _optionsFrom(_filterOptions, keys);

  List<({String id, String name})> get _gradeOptions =>
      _options(['grades', 'grade'])
          .where((option) => const {'X', 'XI', 'XII'}.contains(option.id))
          .toList();

  List<({String id, String name})> _optionsFrom(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    dynamic values;
    for (final key in keys) {
      if (source[key] != null) {
        values = source[key];
        break;
      }
    }
    if (values is Map && values['data'] is List) values = values['data'];
    if (values is! List) return [];
    final result = <({String id, String name})>[];
    for (final value in values) {
      if (value is String || value is num) {
        final text = value.toString();
        result.add((id: text, name: text));
        continue;
      }
      final item = asMap(value);
      final id =
          item['id']?.toString() ??
          item['value']?.toString() ??
          item['class_id']?.toString() ??
          item['teacher_id']?.toString() ??
          item['period_id']?.toString() ??
          item['grade']?.toString() ??
          item['major']?.toString() ??
          item['section']?.toString();
      final name =
          item['class_name']?.toString() ??
          item['name']?.toString() ??
          item['label']?.toString() ??
          item['grade']?.toString() ??
          item['major']?.toString() ??
          item['section']?.toString() ??
          item['period_name']?.toString() ??
          item['teacher_name']?.toString() ??
          item['section_name']?.toString() ??
          item['major_name']?.toString() ??
          item['grade_name']?.toString() ??
          item['fullname']?.toString() ??
          item['title']?.toString();
      if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
        result.add((id: id, name: name));
      }
    }
    return result;
  }

  Widget _serverFilter({
    required String label,
    required List<({String id, String name})> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: options.any((option) => option.id == selected)
            ? selected
            : '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(value: '', child: Text('Semua $label')),
          for (final option in options)
            DropdownMenuItem(value: option.id, child: Text(option.name)),
        ],
        onChanged: (value) {
          onChanged(value ?? '');
          _load();
        },
      ),
    );
  }

  String _classIdForName(String name) {
    for (final item in _classList) {
      if (item['class_name']?.toString() == name) {
        return item['id']?.toString() ?? '';
      }
    }
    return '';
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final attendances = _filteredAttendances();
      final attendancesByClass = <String, List<Map<String, dynamic>>>{};
      for (final attendance in attendances) {
        final className = _getClassNameOfItem(attendance);
        attendancesByClass.putIfAbsent(className, () => []).add(attendance);
      }
      if (attendancesByClass.isEmpty) {
        final className = _isWaliKelasOnly
            ? _waliClassName ?? 'Kelas'
            : _selectedClass;
        attendancesByClass[className] = [];
      }

      final reportTitle = 'DAFTAR PRESENSI SISWA';
      final document = pw.Document(title: reportTitle);
      for (final entry in attendancesByClass.entries) {
        final className = entry.key;
        final classData = _classDataForReport(className, entry.value);
        final waliKelasName = _homeroomTeacherName(className, classData);
        final studentRows = _attendancePdfRows(entry.value);
        document.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 30),
            maxPages: 200,
            header: (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$reportTitle - Halaman ${context.pageNumber}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
            build: (context) => [
              pw.Center(
                child: pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Tanggal: ${_displayDate()}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'Kelas: $className',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Wali Kelas: $waliKelasName',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 14),
              if (studentRows.isEmpty)
                pw.Text('Tidak ada data presensi untuk kelas dan tanggal ini.')
              else
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'No.',
                    'Nama Siswa',
                    'Hadir',
                    'Sakit',
                    'Alpha',
                    'Catatan',
                  ],
                  data: studentRows,
                  cellHeight: 23,
                  headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFDDF2FA),
                  ),
                  headerAlignment: pw.Alignment.center,
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.blueGrey400,
                    width: 0.6,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FlexColumnWidth(2.2),
                    2: const pw.FlexColumnWidth(0.65),
                    3: const pw.FlexColumnWidth(0.65),
                    4: const pw.FlexColumnWidth(0.65),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Keterangan: tanda X menunjukkan status presensi tercatat.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      final filename = _dateRangeMode
          ? 'rekap-presensi-${_dateString(_range.start)}-${_dateString(_range.end)}'
          : 'rekap-presensi-$_dateValue';
      final savedPath = await FileSaver.instance.saveAs(
        name: filename,
        bytes: await document.save(),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Unduhan dibatalkan.'
                : 'File PDF berhasil disimpan.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh laporan: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<List<String>> _attendancePdfRows(
    List<Map<String, dynamic>> attendances,
  ) {
    final students = <String, Map<String, dynamic>>{};
    for (final item in attendances) {
      final student = asMap(item['student']);
      final name = student['fullname']?.toString().trim();
      final studentName = name == null || name.isEmpty ? 'Siswa' : name;
      final id = student['id']?.toString();
      final key = id == null || id.isEmpty ? studentName.toLowerCase() : id;
      final row = students.putIfAbsent(
        key,
        () => {
          'name': studentName,
          'statuses': <String>{},
          'notes': <String>{},
        },
      );
      final status = item['status']?.toString().trim().toLowerCase() ?? '';
      if (status == 'hadir' || status == 'sakit' || status == 'alpha') {
        (row['statuses'] as Set<String>).add(status);
      } else if (status == 'izin') {
        (row['notes'] as Set<String>).add('Izin');
      }
      final notes = item['notes']?.toString().trim();
      if (notes != null && notes.isNotEmpty) {
        (row['notes'] as Set<String>).add(notes);
      }
    }

    final sortedStudents = students.values.toList()
      ..sort(
        (first, second) =>
            (first['name'] as String).compareTo(second['name'] as String),
      );
    return [
      for (var index = 0; index < sortedStudents.length; index++)
        [
          '${index + 1}',
          sortedStudents[index]['name'] as String,
          if ((sortedStudents[index]['statuses'] as Set<String>).contains(
            'hadir',
          ))
            'X'
          else
            '',
          if ((sortedStudents[index]['statuses'] as Set<String>).contains(
            'sakit',
          ))
            'X'
          else
            '',
          if ((sortedStudents[index]['statuses'] as Set<String>).contains(
            'alpha',
          ))
            'X'
          else
            '',
          (sortedStudents[index]['notes'] as Set<String>).join(', '),
        ],
    ];
  }

  Map<String, dynamic> _classDataForReport(
    String className,
    List<Map<String, dynamic>> attendances,
  ) {
    Map<String, dynamic>? listedClass;
    for (final classData in _classList) {
      if (classData['class_name']?.toString() == className) {
        listedClass = classData;
        break;
      }
    }
    if (attendances.isNotEmpty) {
      final journal = asMap(attendances.first['journal']);
      final schedule = asMap(journal['schedule']);
      final scheduleClass = asMap(schedule['class']);
      if (scheduleClass.isNotEmpty) {
        return {...?listedClass, ...scheduleClass};
      }
      final studentClass = asMap(asMap(attendances.first['student'])['class']);
      if (studentClass.isNotEmpty) {
        return {...?listedClass, ...studentClass};
      }
    }
    return listedClass ?? {};
  }

  String _homeroomTeacherName(
    String className,
    Map<String, dynamic> classData,
  ) {
    String? nameFrom(dynamic value) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      final person = asMap(value);
      for (final key in ['fullname', 'name', 'full_name']) {
        final name = person[key]?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
      return null;
    }

    for (final key in [
      'wali_kelas_name',
      'wali_name',
      'homeroom_teacher_name',
      'homeroom_name',
    ]) {
      final name = nameFrom(classData[key]);
      if (name != null) return name;
    }
    for (final key in [
      'wali_kelas',
      'waliKelas',
      'wali_kelas_user',
      'homeroom_teacher',
      'homeroomTeacher',
      'homeroom',
    ]) {
      final value = classData[key];
      final name = nameFrom(value) ?? nameFrom(asMap(value)['user']);
      if (name != null) return name;
    }
    final user = widget.user;
    if (_isWaliKelasOnly &&
        _waliClassName == className &&
        user != null &&
        user.fullname.trim().isNotEmpty) {
      return user.fullname.trim();
    }
    return 'Belum ditentukan';
  }

  Future<void> _selectDate() async {
    if (_dateRangeMode) {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        initialDateRange: _range,
      );
      if (selected == null || !mounted) return;
      setState(() => _range = selected);
      await _load();
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ScpColors.blue,
              onPrimary: Colors.white,
              onSurface: ScpColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _date = selected);
    await _load();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return ScpColors.green;
      case 'izin':
        return ScpColors.amber;
      case 'sakit':
        return const Color(0xFF0284C7);
      case 'alpha':
        return ScpColors.red;
      default:
        return ScpColors.muted;
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return ScpColors.greenCard;
      case 'izin':
        return ScpColors.amberCard;
      case 'sakit':
        return const Color(0xFFE0F2FE);
      case 'alpha':
        return ScpColors.redCard;
      default:
        return ScpColors.surfaceAlt;
    }
  }

  String _getClassNameOfItem(Map<String, dynamic> item) {
    final journal = asMap(item['journal']);
    final schedule = asMap(journal['schedule']);
    final student = asMap(item['student']);

    // Check class from schedule, then from student
    final fromSchedule = asMap(schedule['class'])['class_name']?.toString();
    if (fromSchedule != null && fromSchedule.isNotEmpty) return fromSchedule;

    final fromStudent =
        asMap(student['class'])['class_name']?.toString() ??
        student['class_name']?.toString();
    if (fromStudent != null && fromStudent.isNotEmpty) return fromStudent;

    return 'Kelas Lainnya';
  }

  List<Map<String, dynamic>> _filteredAttendances() {
    final myClass = _waliClassName;

    return _attendances.where((item) {
      final className = _getClassNameOfItem(item);

      // 1. Wali Kelas constraint: strictly their own class
      if (_isWaliKelasOnly && myClass != null) {
        if (!className.toLowerCase().contains(myClass.toLowerCase()) &&
            !myClass.toLowerCase().contains(className.toLowerCase())) {
          return false;
        }
      }

      // 2. Guru BK filter: by selected class
      if (!_isWaliKelasOnly && _selectedClass != 'Semua Kelas') {
        if (className != _selectedClass) return false;
      }

      // 3. Status filter
      if (_selectedStatus != 'Semua Status') {
        final status = item['status']?.toString() ?? '';
        if (status.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }

      // 4. Search query
      if (_searchQuery.isNotEmpty) {
        final studentName =
            asMap(item['student'])['fullname']?.toString().toLowerCase() ?? '';
        final subject =
            asMap(
              asMap(item['journal'])['schedule'],
            )['subject']?.toString().toLowerCase() ??
            '';
        final q = _searchQuery.toLowerCase();
        if (!studentName.contains(q) && !subject.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> _getAvailableClassesForFilter() {
    final set = <String>{};
    for (final c in _classList) {
      final name = c['class_name']?.toString();
      if (name != null && name.isNotEmpty) set.add(name);
    }
    final list = set.toList()..sort();
    return ['Semua Kelas', ...list];
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) {
      return ColoredBox(color: ScpColors.bg, child: body);
    }
    return ScpPage(
      title: _isWaliKelasOnly
          ? 'Presensi Kelas ${_waliClassName ?? ''}'
          : 'Laporan Presensi Sekolah',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: body,
    );
  }

  Widget _body() {
    final myClass = _waliClassName;
    final filtered = _filteredAttendances();

    // Calculate count stats based on active filtered list
    final counts = <String, int>{'Hadir': 0, 'Izin': 0, 'Sakit': 0, 'Alpha': 0};
    for (final item in filtered) {
      final status = item['status']?.toString() ?? '';
      for (final key in counts.keys) {
        if (status.toLowerCase() == key.toLowerCase()) {
          counts[key] = counts[key]! + 1;
        }
      }
    }
    final serverCounts = asMap(_summary['status_counts']);
    if (_selectedStatus == 'Semua Status' &&
        _selectedClass == 'Semua Kelas' &&
        _searchQuery.isEmpty &&
        _selectedPeriodId.isEmpty) {
      for (final status in counts.keys) {
        final value =
            _summary[status.toLowerCase()] ??
            _summary[status] ??
            serverCounts[status.toLowerCase()] ??
            serverCounts[status];
        final parsed = int.tryParse('$value');
        if (parsed != null) counts[status] = parsed;
      }
    }

    // Group items by class
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in filtered) {
      final className = _getClassNameOfItem(item);
      grouped.putIfAbsent(className, () => []).add(item);
    }
    final sortedClassNames = grouped.keys.toList()..sort();

    final availableClasses = _getAvailableClassesForFilter();

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Harian'),
                selected: !_dateRangeMode,
                onSelected: (_) {
                  setState(() => _dateRangeMode = false);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Rentang'),
                selected: _dateRangeMode,
                onSelected: (_) {
                  setState(() => _dateRangeMode = true);
                  _load();
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _exporting || _loading ? null : _exportReport,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
          // Banner Info
          if (_isWaliKelasOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ScpColors.tealCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.tealBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ScpColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.supervised_user_circle_rounded,
                      color: ScpColors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelas Bimbingan: ${myClass ?? "Belum Ditentukan"}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.teal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Wali Kelas hanya memiliki akses ke data presensi kelas binaan sendiri.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF115E59),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScpColors.purpleCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.purpleBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ScpColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: ScpColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Konseling & Presensi Siswa',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.purple,
                          ),
                        ),
                        Text(
                          'Guru BK dapat memantau presensi seluruh kelas dengan filter.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Date Selector Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ScpColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ScpColors.blueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: ScpColors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateRangeMode
                              ? 'Rentang Tanggal'
                              : 'Tanggal Laporan',
                          style: TextStyle(
                            color: ScpColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _displayDate(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ScpColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ScpColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 14,
                          color: ScpColors.muted,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ganti',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ScpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Filter Section for Guru BK (or multi-class search)
          if (!_isWaliKelasOnly) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: ScpColors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter Laporan Kelas & Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ScpColors.text,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedClass != 'Semua Kelas' ||
                          _selectedGrade.isNotEmpty ||
                          _selectedMajor.isNotEmpty ||
                          _selectedSection.isNotEmpty ||
                          _selectedTeacherId.isNotEmpty ||
                          _selectedStatus != 'Semua Status' ||
                          _selectedPeriodId.isNotEmpty ||
                          _searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedClass = 'Semua Kelas';
                              _selectedClassId = '';
                              _selectedGrade = '';
                              _selectedMajor = '';
                              _selectedSection = '';
                              _selectedTeacherId = '';
                              _selectedStatus = 'Semua Status';
                              _selectedPeriodId = '';
                              _searchController.clear();
                              _searchQuery = '';
                            });
                            _load();
                          },
                          child: const Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontSize: 11,
                              color: ScpColors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Class Dropdown
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Pilih Kelas',
                      labelStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClass,
                        isExpanded: true,
                        isDense: true,
                        items: availableClasses.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 13,
                                color: ScpColors.text,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedClass = val;
                              _selectedClassId = val == 'Semua Kelas'
                                  ? ''
                                  : _classIdForName(val);
                            });
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_filterError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _filterError!,
                        style: const TextStyle(color: ScpColors.red),
                      ),
                    ),
                  if (_filtersLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(),
                    ),
                  _serverFilter(
                    label: 'Tingkat',
                    options: _gradeOptions,
                    selected: _selectedGrade,
                    onChanged: (value) =>
                        setState(() => _selectedGrade = value),
                  ),
                  _serverFilter(
                    label: 'Jurusan',
                    options: _options(['majors', 'major']),
                    selected: _selectedMajor,
                    onChanged: (value) =>
                        setState(() => _selectedMajor = value),
                  ),
                  _serverFilter(
                    label: 'Rombel',
                    options: _options(['sections', 'section']),
                    selected: _selectedSection,
                    onChanged: (value) =>
                        setState(() => _selectedSection = value),
                  ),
                  _serverFilter(
                    label: 'Guru',
                    options: _options(['teachers', 'teacher']),
                    selected: _selectedTeacherId,
                    onChanged: (value) =>
                        setState(() => _selectedTeacherId = value),
                  ),
                  _serverFilter(
                    label: 'Periode',
                    options: _options(['periods', 'period']),
                    selected: _selectedPeriodId,
                    onChanged: (value) =>
                        setState(() => _selectedPeriodId = value),
                  ),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Cari nama siswa atau mapel...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: ScpColors.muted,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                            'Semua Status',
                            'Hadir',
                            'Izin',
                            'Sakit',
                            'Alpha',
                          ].map((status) {
                            final isSelected = _selectedStatus == status;
                            final color = status == 'Semua Status'
                                ? ScpColors.blue
                                : _statusColor(status);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(status),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : ScpColors.text,
                                ),
                                selected: isSelected,
                                selectedColor: color,
                                backgroundColor: ScpColors.surfaceAlt,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                showCheckmark: false,
                                onSelected: (_) {
                                  setState(() => _selectedStatus = status);
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Stat Cards Summary
          if (_summary.isNotEmpty) ...[
            Row(
              children: [
                _statCard(
                  'Total Siswa',
                  _summaryInt(['total_students', 'total_siswa', 'total']),
                  ScpColors.blueLight,
                  ScpColors.blue,
                  Icons.groups_outlined,
                ),
                const SizedBox(width: 8),
                _statCard(
                  'Hadir (%)',
                  _summaryInt([
                    'attendance_percentage',
                    'present_percentage',
                    'persentase_hadir',
                  ]),
                  ScpColors.greenCard,
                  ScpColors.green,
                  Icons.percent_rounded,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              _statCard(
                'Hadir',
                counts['Hadir'] ?? 0,
                ScpColors.greenCard,
                ScpColors.green,
                Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 8),
              _statCard(
                'Izin',
                counts['Izin'] ?? 0,
                ScpColors.amberCard,
                ScpColors.amber,
                Icons.assignment_turned_in_outlined,
              ),
              const SizedBox(width: 8),
              _statCard(
                'Sakit',
                counts['Sakit'] ?? 0,
                const Color(0xFFE0F2FE),
                const Color(0xFF0284C7),
                Icons.medical_services_outlined,
              ),
              const SizedBox(width: 8),
              _statCard(
                'Alpha',
                counts['Alpha'] ?? 0,
                ScpColors.redCard,
                ScpColors.red,
                Icons.cancel_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_studentSummary.isNotEmpty) ...[
            const Text(
              'Rekap per Siswa',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ScpColors.text,
              ),
            ),
            const SizedBox(height: 8),
            for (final student in _studentSummary) _studentSummaryTile(student),
            const SizedBox(height: 12),
          ],

          // Header List
          Row(
            children: [
              Text(
                _isWaliKelasOnly
                    ? 'Daftar Siswa Kelas ${myClass ?? ""}'
                    : 'Daftar Presensi (${filtered.length} Data)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ScpColors.text,
                ),
              ),
              const Spacer(),
              if (filtered.isNotEmpty)
                Text(
                  '${filtered.length} siswa',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ScpColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Content States
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: ScpColors.blue),
              ),
            )
          else if (_error != null)
            ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined)
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ScpEmpty(
                message: _isWaliKelasOnly
                    ? 'Belum ada data presensi untuk kelas ${myClass ?? "ini"} pada tanggal terpilih'
                    : 'Tidak ada data presensi yang sesuai dengan filter',
                icon: Icons.event_note_outlined,
              ),
            )
          else
            for (final className in sortedClassNames) ...[
              if (!_isWaliKelasOnly || sortedClassNames.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: ScpColors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        className,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ScpColors.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ScpColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${grouped[className]!.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final item in grouped[className]!) _attendanceTile(item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  int _summaryInt(List<String> keys) {
    for (final key in keys) {
      final value = _summary[key];
      final parsed = int.tryParse('$value');
      if (parsed != null) return parsed;
      final decimal = double.tryParse('$value');
      if (decimal != null) return decimal.round();
    }
    return 0;
  }

  Widget _studentSummaryTile(Map<String, dynamic> student) {
    final name =
        student['fullname']?.toString() ??
        student['student_name']?.toString() ??
        student['name']?.toString() ??
        'Siswa';
    final present =
        student['hadir'] ?? student['present'] ?? student['present_count'];
    final leave = student['izin'] ?? student['leave'] ?? student['leave_count'];
    final sick = student['sakit'] ?? student['sick'] ?? student['sick_count'];
    final absent =
        student['alpha'] ?? student['absent'] ?? student['alpha_count'];
    final consecutive =
        student['consecutive_alpha'] ??
        student['consecutive_absences'] ??
        student['alpha_streak'];
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          'Hadir $present • Izin $leave • Sakit $sick • Alpha $absent'
          '${consecutive == null ? '' : ' • Alpha beruntun $consecutive hari'}',
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color background,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayDate() {
    if (_dateRangeMode) {
      return '${formatShortDate(_dateString(_range.start))} - '
          '${formatShortDate(_dateString(_range.end))}';
    }
    final short = formatShortDate(_dateValue);
    return '$short ${_date.year}';
  }

  Widget _attendanceTile(Map<String, dynamic> item) {
    final journal = asMap(item['journal']);
    final schedule = asMap(journal['schedule']);
    final student = asMap(item['student']);
    final status = (item['status']?.toString() ?? '-').trim();
    final color = _statusColor(status);
    final bg = _statusBg(status);
    final studentName = student['fullname']?.toString() ?? 'Siswa';
    final subject = schedule['subject']?.toString() ?? 'Mata Pelajaran';
    final notes = item['notes']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScpColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: ScpColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ScpColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Catatan: $notes',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

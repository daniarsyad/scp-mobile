import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';

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
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _attendances = [];
  List<Map<String, dynamic>> _classList = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _studentSummary = [];
  bool _monthly = false;
  bool _exporting = false;
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
    _loadClasses();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final res = await _api.get(ApiConfig.classes);
      if (res['success'] == true && mounted) {
        final data = res['data'];
        if (data is List) {
          setState(() {
            _classList = data.map(asMap).toList();
          });
        }
      }
    } catch (_) {}
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
        final availablePeriodIds = _getAvailablePeriods()
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
      if (_monthly)
        'month':
            '${_date.year.toString().padLeft(4, '0')}-'
            '${_date.month.toString().padLeft(2, '0')}'
      else
        'date': _dateValue,
    };
    if (!_isWaliKelasOnly && _selectedClass != 'Semua Kelas') {
      for (final item in _classList) {
        if (item['class_name']?.toString() == _selectedClass &&
            item['id'] != null) {
          params['class_id'] = item['id'].toString();
          break;
        }
      }
    }
    if (_selectedPeriodId.isNotEmpty) {
      params['period_id'] = _selectedPeriodId;
    }
    return params;
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final response = await _api.download(
        Uri(
          path: ApiConfig.attendanceReportExport,
          queryParameters: _reportParams(),
        ).toString(),
      );
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Export gagal (${response.statusCode}): ${response.body}',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw StateError('File ekspor yang diterima kosong.');
      }
      final filename = _monthly
          ? 'rekap-presensi-${_date.year}-${_date.month.toString().padLeft(2, '0')}'
          : 'rekap-presensi-$_dateValue';
      final savedPath = await FileSaver.instance.saveAs(
        name: filename,
        bytes: response.bodyBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Unduhan dibatalkan.'
                : 'File XLSX berhasil disimpan.',
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

  Future<void> _selectDate() async {
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
    for (final a in _attendances) {
      set.add(_getClassNameOfItem(a));
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
                selected: !_monthly,
                onSelected: (_) {
                  setState(() => _monthly = false);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Bulanan'),
                selected: _monthly,
                onSelected: (_) {
                  setState(() => _monthly = true);
                  _load();
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _exporting ? null : _exportReport,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('XLSX'),
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
                          _monthly ? 'Bulan Laporan' : 'Tanggal Laporan',
                          style: TextStyle(
                            color: ScpColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _monthly
                              ? '${_date.year}-${_date.month.toString().padLeft(2, '0')}'
                              : _displayDate(),
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
                          _selectedStatus != 'Semua Status' ||
                          _searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedClass = 'Semua Kelas';
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
                            setState(() => _selectedClass = val);
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_getAvailablePeriods().isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPeriodId,
                      decoration: const InputDecoration(
                        labelText: 'Periode KBM',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua periode'),
                        ),
                        for (final period in _getAvailablePeriods())
                          DropdownMenuItem(
                            value: period.id,
                            child: Text(period.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPeriodId = value ?? '');
                        _load();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

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

  List<({String id, String name})> _getAvailablePeriods() {
    final periods = <String, String>{};
    for (final item in _attendances) {
      final schedule = asMap(asMap(item['journal'])['schedule']);
      final period = asMap(schedule['period']);
      final id = (period['id'] ?? schedule['period_id'])?.toString();
      if (id == null || id.isEmpty) continue;
      final name =
          period['name']?.toString() ??
          period['period_name']?.toString() ??
          schedule['period_name']?.toString() ??
          'Periode $id';
      periods[id] = name;
    }
    return periods.entries
        .map((entry) => (id: entry.key, name: entry.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
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

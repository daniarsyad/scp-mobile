import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard_kit.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final UserModel user;
  final bool isParent;
  final Map<String, dynamic>? student;
  final List<Map<String, dynamic>>? children;
  final ValueChanged<int>? onSelectStudent;
  final bool embedded;
  final ApiService? api;

  const AttendanceHistoryScreen({
    super.key,
    required this.user,
    this.isParent = false,
    this.student,
    this.children,
    this.onSelectStudent,
    this.embedded = false,
    this.api,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late final ApiService _api;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _dynamicChildren = [];
  Map<String, dynamic>? _selectedChild;
  String _activeFilter = 'Semua';
  DateTimeRange? _customRange;

  List<Map<String, dynamic>> get _children {
    if (widget.children != null && widget.children!.isNotEmpty) {
      return widget.children!;
    }
    if (_dynamicChildren.isNotEmpty) return _dynamicChildren;
    return widget.user.children;
  }

  final List<String> _filterOptions = const [
    'Semua',
    '7 Hari',
    '30 Hari',
    'Semester (6 Bln)',
    '1 Tahun',
    'Pilih Tanggal',
  ];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    if (widget.isParent) {
      _selectedChild = widget.student ??
          (_children.isNotEmpty ? _children.first : null);
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.student != oldWidget.student) {
      setState(() => _selectedChild = widget.student);
      _load();
    }
  }

  String? get _studentId {
    if (!widget.isParent) return null;
    final id = int.tryParse('${asMap(_selectedChild)['id']}');
    return id != null && id > 0 ? '$id' : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.isParent && _selectedChild == null && _children.isEmpty) {
      final childrenRes = await _api.get(ApiConfig.children);
      if (childrenRes['success'] == true) {
        final list = asList(childrenRes['data']).map(asMap).toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _dynamicChildren = list;
            _selectedChild = list.first;
          });
          final id = int.tryParse('${list.first['id']}');
          if (id != null) widget.onSelectStudent?.call(id);
        }
      }
    }

    if (widget.isParent && _studentId == null) {
      setState(() {
        _loading = false;
        _error = 'Belum ada data siswa yang tertaut dengan akun Orang Tua ini.';
      });
      return;
    }

    final path = _studentId == null
        ? ApiConfig.myAttendances
        : Uri(
            path: ApiConfig.myAttendances,
            queryParameters: {'student_id': _studentId!},
          ).toString();

    final result = await _api.get(path);
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString().isNotEmpty == true
            ? result['message'].toString()
            : 'Gagal memuat riwayat presensi.';
      });
      return;
    }

    final records = asList(result['data']).map(asMap).toList()
      ..sort((a, b) => _recordDate(b).compareTo(_recordDate(a)));

    setState(() {
      _loading = false;
      _records = records;
    });
  }

  DateTime _recordDate(Map<String, dynamic> record) {
    final rawDate = _date(record);
    return DateTime.tryParse(rawDate) ?? DateTime(0);
  }

  String _date(Map<String, dynamic> record) {
    return (record['date'] ?? asMap(record['journal'])['date'] ?? '')
        .toString();
  }

  String _status(Map<String, dynamic> record) {
    final value = (record['status'] ?? record['attendance_status'] ?? '')
        .toString()
        .trim();
    final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (key) {
      case 'hadir':
      case 'present':
        return 'Hadir';
      case 'izin':
      case 'excused':
        return 'Izin';
      case 'sakit':
      case 'sick':
        return 'Sakit';
      case 'alpa':
      case 'alpha':
      case 'absent':
      case 'tidakhadir':
        return 'Alpa';
      default:
        return value.isEmpty ? 'Belum tercatat' : value;
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_activeFilter == 'Semua') return _records;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_activeFilter == '7 Hari') {
      final start = today.subtract(const Duration(days: 7));
      return _records.where((r) => !_recordDate(r).isBefore(start)).toList();
    }
    if (_activeFilter == '30 Hari') {
      final start = today.subtract(const Duration(days: 30));
      return _records.where((r) => !_recordDate(r).isBefore(start)).toList();
    }
    if (_activeFilter == 'Semester (6 Bln)') {
      final start = today.subtract(const Duration(days: 180));
      return _records.where((r) => !_recordDate(r).isBefore(start)).toList();
    }
    if (_activeFilter == '1 Tahun') {
      final start = today.subtract(const Duration(days: 365));
      return _records.where((r) => !_recordDate(r).isBefore(start)).toList();
    }
    if (_activeFilter == 'Pilih Tanggal' && _customRange != null) {
      return _records.where((r) {
        final d = _recordDate(r);
        final start = _customRange!.start;
        final end = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          23,
          59,
          59,
        );
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }
    return _records;
  }

  int _count(String status) =>
      _filteredRecords.where((record) => _status(record) == status).length;

  double get _attendanceRate {
    final list = _filteredRecords;
    if (list.isEmpty) return 100.0;
    final present = list.where((r) => _status(r) == 'Hadir').length;
    return (present / list.length) * 100;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Hadir':
        return ScpColors.green;
      case 'Alpa':
        return ScpColors.red;
      case 'Sakit':
        return ScpColors.purple;
      case 'Izin':
        return ScpColors.amber;
      default:
        return ScpColors.muted;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'Hadir':
        return ScpColors.greenCard;
      case 'Alpa':
        return ScpColors.redCard;
      case 'Sakit':
        return ScpColors.purpleCard;
      case 'Izin':
        return ScpColors.amberCard;
      default:
        return ScpColors.surfaceAlt;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ScpColors.blue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _activeFilter = 'Pilih Tanggal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return ColoredBox(color: ScpColors.bg, child: body);
    }
    return Scaffold(
      backgroundColor: ScpColors.bg,
      appBar: AppBar(
        title: Text(widget.isParent ? 'Presensi Anak' : 'Presensi Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    final studentName = widget.isParent
        ? (asMap(_selectedChild)['fullname']?.toString() ?? 'Siswa')
        : widget.user.fullname;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ScpColors.blue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ScpEmpty(
            message: _error!,
            icon: Icons.cloud_off_outlined,
          ),
        ),
      );
    }

    final filtered = _filteredRecords;

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          // Header Siswa
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ScpColors.blueLight,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: ScpColors.blue,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
                      style: const TextStyle(
                        color: ScpColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.isParent
                          ? 'Rekapitulasi catatan presensi siswa di sekolah.'
                          : 'Rekapitulasi riwayat presensi pembelajaran Anda.',
                      style: const TextStyle(color: ScpColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector Anak (jika Ortu punya lebih dari 1 anak)
          if (widget.isParent && _children.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ScpColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.family_restroom_rounded, size: 18, color: ScpColors.blue),
                  const SizedBox(width: 10),
                  const Text('Pilih Anak: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: int.tryParse('${asMap(_selectedChild)['id']}'),
                        isExpanded: true,
                        isDense: true,
                        items: _children.map((c) {
                          final id = int.tryParse('${c['id']}') ?? 0;
                          final name = c['fullname']?.toString() ?? 'Anak';
                          final className = asMap(c['class'])['class_name']?.toString() ?? c['class_name']?.toString() ?? '';
                          final label = className.isNotEmpty ? '$name ($className)' : name;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final match = _children.firstWhere(
                              (c) => int.tryParse('${c['id']}') == id,
                              orElse: () => _children.first,
                            );
                            setState(() => _selectedChild = match);
                            widget.onSelectStudent?.call(id);
                            _load();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Filter Periode (Chips horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((opt) {
                final isSelected = _activeFilter == opt;
                String chipLabel = opt;
                if (opt == 'Pilih Tanggal' && _customRange != null) {
                  chipLabel = '${formatShortDate(_customRange!.start.toIso8601String().substring(0, 10))} - ${formatShortDate(_customRange!.end.toIso8601String().substring(0, 10))}';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(chipLabel),
                    selected: isSelected,
                    onSelected: (_) {
                      if (opt == 'Pilih Tanggal') {
                        _pickDateRange();
                      } else {
                        setState(() => _activeFilter = opt);
                      }
                    },
                    selectedColor: ScpColors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : ScpColors.text,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? ScpColors.blue : ScpColors.line,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Tingkat Kehadiran Card Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: ScpColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ScpColors.blue.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tingkat Kehadiran ($_activeFilter)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_attendanceRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tercatat ${filtered.length} sesi pembelajaran pada rentang ini',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Status Summary Cards
          Row(
            children: [
              Expanded(child: _summaryCard('Hadir', Icons.check_circle_outline_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Izin', Icons.assignment_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Sakit', Icons.healing_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Alpa', Icons.cancel_outlined)),
            ],
          ),
          const SizedBox(height: 20),

          // Header List
          Row(
            children: [
              Text(
                'Riwayat Presensi (${filtered.length} Sesi)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ScpColors.text,
                ),
              ),
              const Spacer(),
              if (_activeFilter != 'Semua')
                InkWell(
                  onTap: () => setState(() => _activeFilter = 'Semua'),
                  child: const Text(
                    'Reset Filter',
                    style: TextStyle(
                      fontSize: 12,
                      color: ScpColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.line),
              ),
              child: ScpEmpty(
                message: _records.isEmpty
                    ? 'Belum ada catatan presensi pembelajaran tercatat di sistem.'
                    : 'Tidak ada catatan presensi pada periode "$_activeFilter". Coba pilih rentang lain.',
                icon: Icons.fact_check_outlined,
              ),
            )
          else
            for (final record in filtered) _attendanceTile(record),
        ],
      ),
    );
  }

  Widget _summaryCard(String status, IconData icon) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '${_count(status)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTile(Map<String, dynamic> record) {
    final journal = asMap(record['journal']);
    final schedule = asMap(journal['schedule']);
    final subject = schedule['subject']?.toString() ??
        record['subject']?.toString() ??
        'Presensi Pembelajaran';
    final roomName = asMap(schedule['room'])['room_name']?.toString() ?? '';
    final roomStr = roomName.isNotEmpty ? ' • Ruang $roomName' : '';
    final startTime = formatTime(schedule['start_time']);
    final endTime = formatTime(schedule['end_time']);
    final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty) ? ' • $startTime-$endTime' : '';
    final status = _status(record);
    final color = _statusColor(status);
    final notes = (record['notes'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notes.isNotEmpty
              ? Colors.amber.shade300
              : ScpColors.line,
          width: notes.isNotEmpty ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _statusBackground(status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ScpColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatShortDate(_date(record))}$timeStr$roomStr',
                      style: const TextStyle(color: ScpColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBackground(status),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan Guru: $notes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

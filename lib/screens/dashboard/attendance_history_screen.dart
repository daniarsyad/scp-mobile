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
  final ApiService? api;

  const AttendanceHistoryScreen({
    super.key,
    required this.user,
    this.isParent = false,
    this.student,
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

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _load();
  }

  String? get _studentId {
    if (!widget.isParent) return null;
    final id = int.tryParse('${asMap(widget.student)['id']}');
    return id != null && id > 0 ? '$id' : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.isParent && _studentId == null) {
      setState(() {
        _loading = false;
        _error = 'Belum ada data siswa yang tertaut dengan akun ini.';
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

  int _count(String status) =>
      _records.where((record) => _status(record) == status).length;

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

  @override
  Widget build(BuildContext context) {
    final studentName = widget.isParent
        ? (asMap(widget.student)['fullname']?.toString() ?? 'Siswa')
        : widget.user.fullname;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isParent ? 'Presensi Anak' : 'Presensi Saya'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ScpColors.blue),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ScpEmpty(
                  message: _error!,
                  icon: Icons.cloud_off_outlined,
                ),
              ),
            )
          : RefreshIndicator(
              color: ScpColors.blue,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    studentName,
                    style: const TextStyle(
                      color: ScpColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isParent
                        ? 'Pantau catatan kehadiran anak di sekolah.'
                        : 'Pantau catatan kehadiran Anda di sekolah.',
                    style: const TextStyle(color: ScpColors.muted),
                  ),
                  const SizedBox(height: 16),
                  _todayStatusCard(),
                  const SizedBox(height: 16),
                  const ScpSectionHeader(title: 'Ringkasan Presensi'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard('Hadir', Icons.check_circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard('Alpa', Icons.cancel_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard('Izin', Icons.assignment_outlined),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard('Sakit', Icons.healing_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const ScpSectionHeader(title: 'Riwayat Presensi'),
                  const SizedBox(height: 8),
                  if (_records.isEmpty)
                    const ScpEmpty(
                      message: 'Belum ada catatan presensi. Status Alpa hanya muncul setelah dicatat oleh sekolah.',
                      icon: Icons.fact_check_outlined,
                    )
                  else
                    for (final record in _records) _attendanceTile(record),
                ],
              ),
            ),
    );
  }

  Widget _todayStatusCard() {
    final todayRecords = _records
        .where((record) => _date(record).startsWith(todayIso()))
        .toList();
    final todayStatuses = todayRecords.map(_status).toSet().toList();
    final label = todayStatuses.isEmpty
        ? 'Belum ada presensi tercatat hari ini'
        : todayStatuses.join(' • ');
    final color = todayStatuses.length == 1
        ? _statusColor(todayStatuses.single)
        : ScpColors.muted;
    final background = todayStatuses.length == 1
        ? _statusBackground(todayStatuses.single)
        : ScpColors.surfaceAlt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.today_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status hari ini',
                  style: TextStyle(
                    color: ScpColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String status, IconData icon) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusBackground(status),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_count(status)}',
                  style: const TextStyle(
                    color: ScpColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTile(Map<String, dynamic> record) {
    final schedule = asMap(asMap(record['journal'])['schedule']);
    final subject =
        schedule['subject']?.toString() ??
        record['subject']?.toString() ??
        'Presensi';
    final status = _status(record);
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScpColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusBackground(status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fact_check_outlined, color: color, size: 21),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatShortDate(_date(record)),
                  style: const TextStyle(color: ScpColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

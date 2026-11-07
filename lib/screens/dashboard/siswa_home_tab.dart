import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import 'attendance_history_screen.dart';
import '../edit_profile_screen.dart';
import '../ortu/create_leave_ortu_screen.dart';
import '../siswa/create_leave_screen.dart';

class SiswaHomeTab extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int>? onNavigateTab;
  final bool isParent;
  final int? selectedStudentId;
  final ValueChanged<int>? onSelectStudent;
  final ValueChanged<List<Map<String, dynamic>>>? onChildrenUpdated;
  final ValueChanged<UserModel>? onProfileUpdated;
  final ApiService? api;

  const SiswaHomeTab({
    super.key,
    required this.user,
    this.onNavigateTab,
    this.isParent = false,
    this.selectedStudentId,
    this.onSelectStudent,
    this.onChildrenUpdated,
    this.onProfileUpdated,
    this.api,
  });

  @override
  State<SiswaHomeTab> createState() => _SiswaHomeTabState();
}

class _SiswaHomeTabState extends State<SiswaHomeTab> {
  late final ApiService _api;
  bool _loading = true;
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _dynamicChildren = [];
  int? _selectedStudentId;
  int _hadir = 0;
  bool _attendanceLoaded = false;
  String? _dashboardError;
  String? _attendanceError;
  String? _leaveError;

  List<Map<String, dynamic>> get _children =>
      _dynamicChildren.isNotEmpty ? _dynamicChildren : widget.user.children;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    if (widget.isParent) {
      _selectedStudentId = widget.selectedStudentId;
      if (_selectedStudentId == null) {
        for (final child in _children) {
          final childId = _readId(child['id']);
          if (childId != null) {
            _selectedStudentId = childId;
            break;
          }
        }
      }
    }
    LiveRefresh.leaves.addListener(_onPing);
    _load();
  }

  @override
  void didUpdateWidget(covariant SiswaHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStudentId != null &&
        widget.selectedStudentId != _selectedStudentId) {
      setState(() => _selectedStudentId = widget.selectedStudentId);
      _load();
    }
  }

  @override
  void dispose() {
    LiveRefresh.leaves.removeListener(_onPing);
    super.dispose();
  }

  void _onPing() {
    if (mounted) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    // Auto-fetch children if empty for parent
    if (widget.isParent && _children.isEmpty) {
      final childrenRes = await _api.get(ApiConfig.children);
      if (childrenRes['success'] == true) {
        final list = asList(childrenRes['data']).map(asMap).toList();
        if (mounted) {
          setState(() {
            _dynamicChildren = list;
            if (_selectedStudentId == null && list.isNotEmpty) {
              _selectedStudentId = _readId(list.first['id']);
              widget.onSelectStudent?.call(_selectedStudentId!);
            }
          });
          widget.onChildrenUpdated?.call(list);
        }
      }
    }

    final todayPath = widget.isParent && _selectedStudentId != null
        ? Uri(
            path: ApiConfig.dashboardToday,
            queryParameters: {'student_id': '$_selectedStudentId'},
          ).toString()
        : ApiConfig.dashboardToday;
    final hasStudentContext = !widget.isParent || _selectedStudentId != null;
    final attendancePath = widget.isParent && _selectedStudentId != null
        ? Uri(
            path: ApiConfig.myAttendances,
            queryParameters: {'student_id': '$_selectedStudentId'},
          ).toString()
        : ApiConfig.myAttendances;
    final results = await Future.wait([
      _api.get(ApiConfig.myLeaveRequests),
      if (hasStudentContext) _api.get(todayPath),
      if (hasStudentContext) _api.get(attendancePath),
    ]);
    if (!mounted) return;

    final leaveRows = <Map<String, dynamic>>[];
    final leaves = results[0];
    if (leaves['success'] == true) {
      for (final item in asList(leaves['data'])) {
        leaveRows.add(asMap(item));
      }
    }

    final scheduleRows = <Map<String, dynamic>>[];
    String? dashboardError;
    if (hasStudentContext) {
      final today = results[1];
      if (today['success'] == true) {
        scheduleRows.addAll(_todaySchedules(today['data']));
      } else {
        dashboardError = today['message']?.toString().isNotEmpty == true
            ? today['message'].toString()
            : 'Gagal memuat dashboard hari ini.';
      }
    }

    var hadir = 0;
    final attendanceRows = <Map<String, dynamic>>[];
    final attendance = hasStudentContext
        ? results[2]
        : {'success': false, 'message': 'Belum ada siswa yang tertaut.'};
    String? attendanceError;
    if (attendance['success'] == true) {
      for (final item in asList(attendance['data'])) {
        final row = asMap(item);
        attendanceRows.add(row);
        if (_attendanceStatusLabel(row['status']?.toString() ?? '') ==
            'Hadir') {
          hadir++;
        }
      }
    } else {
      attendanceError = attendance['message']?.toString().isNotEmpty == true
          ? attendance['message'].toString()
          : 'Gagal memuat histori presensi.';
    }

    setState(() {
      _loading = false;
      _leaves = leaveRows;
      _schedules = scheduleRows;
      _attendanceRecords = attendanceRows;
      _hadir = hadir;
      _attendanceLoaded = attendance['success'] == true;
      _dashboardError = dashboardError;
      _attendanceError = attendanceError;
      _leaveError = leaves['success'] == true
          ? null
          : (leaves['message']?.toString().isNotEmpty == true
                ? leaves['message'].toString()
                : 'Gagal memuat pengajuan izin.');
    });
  }

  List<Map<String, dynamic>> _todaySchedules(dynamic data) {
    if (data is List) return data.map(asMap).toList();
    final payload = asMap(data);
    final candidates = [
      payload['schedules'],
      payload['today'],
      payload['items'],
      payload['data'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) return candidate.map(asMap).toList();
    }
    return [];
  }

  int? _readId(dynamic value) {
    if (value is int && value > 0) return value;
    final parsed = int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int _countStatus(String status) {
    return _leaves.where((item) {
      final value = (item['status_approval'] ?? item['status'] ?? 'Pending')
          .toString();
      return value.toLowerCase() == status.toLowerCase();
    }).length;
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isParent
            ? const CreateLeaveOrtuScreen()
            : const CreateLeaveScreen(),
      ),
    );
    if (ok == true) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.isParent
        ? (widget.user.fullname.isNotEmpty
            ? widget.user.fullname
            : 'Orang Tua Siswa')
        : (widget.user.fullname.isEmpty ? 'Siswa' : widget.user.fullname);
    final approved = _countStatus('Approved');
    final pending = _countStatus('Pending');
    final percent = !_attendanceLoaded
        ? null
        : _attendanceRecords.isEmpty
        ? 0
        : ((_hadir / _attendanceRecords.length) * 100).round();

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: [
          ScpGreeting(
            line: greetingLine(),
            name: greetingName,
            roleName: widget.isParent ? 'Orang Tua' : 'Siswa',
            className: widget.isParent
                ? (_selectedChild != null
                    ? 'Wali dari $_selectedChildName'
                    : (widget.user.className ?? 'SMKN 1 Bantul'))
                : widget.user.className,
            onEditProfile: () async {
              final updated = await Navigator.push<UserModel>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    user: widget.user,
                    onProfileUpdated: widget.onProfileUpdated,
                  ),
                ),
              );
              if (updated != null) {
                widget.onProfileUpdated?.call(updated);
              }
            },
          ),
          const SizedBox(height: 14),

          if (widget.isParent && _children.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        Icons.family_restroom_rounded,
                        size: 18,
                        color: ScpColors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _children.length > 1
                            ? 'Pilih Siswa / Anak:'
                            : 'Data Siswa Terkait:',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ScpColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _children.map((child) {
                        final childId = _readId(child['id']);
                        final childName =
                            child['fullname']?.toString() ?? 'Siswa';
                        final childClass =
                            asMap(child['class'])['class_name']?.toString() ??
                            child['class_name']?.toString() ??
                            'Kelas';
                        final isSelected = childId == _selectedStudentId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.person_outline_rounded,
                                  size: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : ScpColors.text,
                                ),
                                const SizedBox(width: 6),
                                Text('$childName ($childClass)'),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: ScpColors.blue,
                            backgroundColor: ScpColors.surfaceAlt,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : ScpColors.text,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? ScpColors.blue
                                  : ScpColors.line,
                            ),
                            onSelected: (selected) {
                              if (selected &&
                                  childId != null &&
                                  childId != _selectedStudentId) {
                                setState(() => _selectedStudentId = childId);
                                widget.onSelectStudent?.call(childId);
                                _load();
                              }
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

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: ScpColors.blue),
              ),
            )
          else ...[
            if (widget.isParent && _children.isEmpty)
              const ScpEmpty(
                message: 'Backend belum menautkan anak ke akun ini.',
                icon: Icons.family_restroom_outlined,
              ),
            ScpHeroPager(
              pages: [
                ScpHeroData(
                  value: percent == null ? '—' : '$percent%',
                  label: 'Tingkat Kehadiran Presensi',
                  footerTitle: widget.isParent ? _selectedChildName : greetingName,
                  footerSubtitle: widget.isParent
                      ? _selectedChildClass
                      : widget.user.className ?? 'SMKN 1 Bantul',
                  gradient: ScpColors.primaryGradient,
                  icon: Icons.badge_outlined,
                ),
                ScpHeroData(
                  value: '$pending',
                  label: 'Pengajuan Izin Menunggu',
                  footerTitle: 'Status Perizinan',
                  footerSubtitle: todayLabel(),
                  gradient: ScpColors.tealGradient,
                  icon: Icons.assignment_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions
            const ScpSectionHeader(title: 'Aksi Cepat'),
            const SizedBox(height: 10),
            ScpQuickActionsGrid(
              items: [
                ScpQuickActionItem(
                  icon: Icons.fact_check_rounded,
                  title: 'Rekap\nPresensi',
                  color: ScpColors.blue,
                  bg: ScpColors.blueLight,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                ScpQuickActionItem(
                  icon: Icons.calendar_month_rounded,
                  title: 'Jadwal\nPelajaran',
                  color: ScpColors.teal,
                  bg: ScpColors.tealCard,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                ScpQuickActionItem(
                  icon: Icons.upload_file_rounded,
                  title: widget.isParent
                      ? 'Ajukan\nIzin Anak'
                      : 'Ajukan\nIzin Siswa',
                  color: ScpColors.purple,
                  bg: ScpColors.purpleCard,
                  onTap: _create,
                ),
                ScpQuickActionItem(
                  icon: Icons.description_outlined,
                  title: 'Riwayat\nIzin',
                  color: ScpColors.amber,
                  bg: ScpColors.amberCard,
                  onTap: () => widget.onNavigateTab?.call(3),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ScpSectionHeader(
              title: widget.isParent ? 'Status Izin Anak' : 'Status Izin Saya',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ScpStatCard(
                    label: 'Disetujui',
                    value: '$approved',
                    background: ScpColors.greenCard,
                    valueColor: ScpColors.green,
                    icon: Icons.check_circle_rounded,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ScpStatCard(
                    label: 'Menunggu',
                    value: '$pending',
                    background: ScpColors.amberCard,
                    valueColor: ScpColors.amber,
                    icon: Icons.hourglass_empty_rounded,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Today's Schedule Section
            Row(
              children: [
                const Text(
                  'Jadwal Pelajaran Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(2),
                  child: const Text(
                    'Buka Jadwal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_dashboardError != null)
              ScpEmpty(
                message: _dashboardError!,
                icon: Icons.cloud_off_outlined,
              )
            else if (widget.isParent && _selectedStudentId == null)
              const ScpEmpty(
                message: 'Tidak ada anak yang dapat dipilih.',
                icon: Icons.person_off_outlined,
              )
            else if (_schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: ScpEmpty(
                  message: 'Belum ada data dashboard hari ini',
                  icon: Icons.event_available_outlined,
                ),
              )
            else
              for (var i = 0; i < _schedules.length && i < 4; i++)
                _scheduleRow(_schedules[i], i),

            const SizedBox(height: 18),

            Row(
              children: [
                const Expanded(
                  child: ScpSectionHeader(title: 'Histori Presensi'),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab != null
                      ? widget.onNavigateTab!(1)
                      : Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttendanceHistoryScreen(
                              user: widget.user,
                              isParent: widget.isParent,
                              student: _selectedChild,
                              children: _children,
                              onSelectStudent: widget.onSelectStudent,
                              api: _api,
                            ),
                          ),
                        ),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_attendanceError != null)
              ScpEmpty(
                message: _attendanceError!,
                icon: Icons.cloud_off_outlined,
              )
            else if (_attendanceRecords.isEmpty)
              const ScpEmpty(
                message: 'Belum ada catatan presensi. Tingkat kehadiran 0%.',
                icon: Icons.fact_check_outlined,
              )
            else
              for (final item in _attendanceRecords.take(5))
                _attendanceRow(item),

            const SizedBox(height: 18),

            Row(
              children: [
                const Text(
                  'Izin Terakhir Diajukan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(3),
                  child: const Text(
                    'Semua Izin',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_leaveError != null)
              ScpEmpty(message: _leaveError!, icon: Icons.cloud_off_outlined)
            else if (_leaves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ScpEmpty(
                  message: 'Belum ada pengajuan izin. Klik "Ajukan Izin" untuk membuat pengajuan baru.',
                  icon: Icons.post_add_rounded,
                ),
              )
            else
              for (var i = 0; i < _leaves.length && i < 4; i++)
                _leaveRow(_leaves[i], i),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? get _selectedChild {
    if (_selectedStudentId == null) return null;
    for (final child in _children) {
      if (_readId(child['id']) == _selectedStudentId) {
        return child;
      }
    }
    return null;
  }

  String get _selectedChildName {
    return _selectedChild?['fullname']?.toString() ?? 'Siswa';
  }

  String get _selectedChildClass {
    final child = _selectedChild;
    return asMap(child?['class'])['class_name']?.toString() ??
        child?['class_name']?.toString() ??
        'Kelas';
  }

  Widget _attendanceRow(Map<String, dynamic> item) {
    final schedule = asMap(asMap(item['journal'])['schedule']);
    final subject =
        schedule['subject']?.toString() ??
        item['subject']?.toString() ??
        'Presensi';
    final date =
        item['date']?.toString() ??
        asMap(item['journal'])['date']?.toString() ??
        '-';
    final status = item['status']?.toString() ?? '-';
    return ScpActivityTile(
      icon: status.toLowerCase() == 'hadir'
          ? Icons.check_circle_outline_rounded
          : Icons.fact_check_outlined,
      iconBg: _attendanceStatusBackground(status),
      iconColor: _attendanceStatusColor(status),
      title: subject,
      subtitle: formatShortDate(date),
      trailing: _attendanceStatusLabel(status),
      trailingColor: _attendanceStatusColor(status),
    );
  }

  Color _attendanceStatusColor(String status) {
    switch (status.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'hadir':
      case 'present':
        return ScpColors.green;
      case 'alpa':
      case 'alpha':
      case 'absent':
      case 'tidakhadir':
        return ScpColors.red;
      case 'sakit':
        return ScpColors.purple;
      case 'izin':
        return ScpColors.amber;
      default:
        return ScpColors.muted;
    }
  }

  Color _attendanceStatusBackground(String status) {
    switch (_attendanceStatusColor(status)) {
      case ScpColors.green:
        return ScpColors.greenCard;
      case ScpColors.red:
        return ScpColors.redCard;
      case ScpColors.purple:
        return ScpColors.purpleCard;
      case ScpColors.amber:
        return ScpColors.amberCard;
      default:
        return ScpColors.surfaceAlt;
    }
  }

  String _attendanceStatusLabel(String status) {
    switch (status.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'alpha':
      case 'alpa':
      case 'absent':
      case 'tidakhadir':
        return 'Alpa';
      case 'hadir':
      case 'present':
        return 'Hadir';
      case 'sick':
        return 'Sakit';
      case 'excused':
        return 'Izin';
      default:
        return status;
    }
  }

  Widget _scheduleRow(Map<String, dynamic> item, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final subject = item['subject']?.toString() ?? '-';
    final start = formatTime(item['start_time']);
    final end = formatTime(item['end_time']);
    final room = item['room']?['room_name']?.toString() ?? '-';
    return ScpActivityTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: subject,
      subtitle: '$start - $end  •  Ruang $room',
      trailing: start,
      trailingColor: ScpColors.blue,
      onTap: () => widget.onNavigateTab?.call(1),
    );
  }

  Widget _leaveRow(Map<String, dynamic> item, int index) {
    final palette = activityPalette[(index + 2) % activityPalette.length];
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending')
        .toString();
    final start = formatShortDate((item['start_date'] ?? '').toString());
    final reason = item['reason']?.toString() ?? '-';
    final color = _statusColor(status);
    return ScpActivityTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: reason,
      subtitle: 'Tanggal: $start',
      trailing: _statusLabel(status),
      trailingColor: color,
      onTap: () => widget.onNavigateTab?.call(2),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return ScpColors.green;
      case 'rejected':
        return ScpColors.red;
      default:
        return ScpColors.amber;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }
}

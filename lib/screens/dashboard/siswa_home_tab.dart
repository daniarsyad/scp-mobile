import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import '../siswa/create_leave_screen.dart';

class SiswaHomeTab extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int>? onNavigateTab;

  const SiswaHomeTab({
    super.key,
    required this.user,
    this.onNavigateTab,
  });

  @override
  State<SiswaHomeTab> createState() => _SiswaHomeTabState();
}

class _SiswaHomeTabState extends State<SiswaHomeTab> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _schedules = [];
  int _hadir = 0;
  int _absenTotal = 0;

  @override
  void initState() {
    super.initState();
    LiveRefresh.leaves.addListener(_onPing);
    _load();
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

    final leaves = await _api.get(ApiConfig.myLeaveRequests);
    final today = await _api.get(ApiConfig.schedulesToday);
    final attendance = await _api.get(ApiConfig.myAttendances);
    if (!mounted) return;

    final leaveRows = <Map<String, dynamic>>[];
    if (leaves['success'] == true) {
      for (final item in asList(leaves['data'])) {
        leaveRows.add(asMap(item));
      }
    }

    final scheduleRows = <Map<String, dynamic>>[];
    if (today['success'] == true) {
      for (final item in asList(today['data'])) {
        scheduleRows.add(asMap(item));
      }
    }

    var hadir = 0;
    var total = 0;
    if (attendance['success'] == true) {
      for (final item in asList(attendance['data'])) {
        total++;
        if (asMap(item)['status']?.toString() == 'Hadir') hadir++;
      }
    }

    setState(() {
      _loading = false;
      _leaves = leaveRows;
      _schedules = scheduleRows;
      _hadir = hadir;
      _absenTotal = total;
    });
  }

  int _countStatus(String status) {
    return _leaves.where((item) {
      final value = (item['status_approval'] ?? item['status'] ?? 'Pending').toString();
      return value.toLowerCase() == status.toLowerCase();
    }).length;
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateLeaveScreen()),
    );
    if (ok == true) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullname.isEmpty ? 'Siswa' : widget.user.fullname;
    final approved = _countStatus('Approved');
    final pending = _countStatus('Pending');
    final percent = _absenTotal == 0 ? null : ((_hadir / _absenTotal) * 100).round();

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: [
          ScpGreeting(
            line: greetingLine(),
            name: name,
            roleName: 'Siswa',
            className: widget.user.className,
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: ScpColors.blue)),
            )
          else ...[
            ScpHeroPager(
              pages: [
                ScpHeroData(
                  value: percent == null ? '${_leaves.length}' : '$percent%',
                  label: percent == null ? 'Pengajuan Izin' : 'Tingkat Kehadiran Presensi',
                  footerTitle: name,
                  footerSubtitle: widget.user.className ?? 'SMKN 1 Bantul',
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
                  icon: Icons.upload_file_rounded,
                  title: 'Ajukan\nIzin Siswa',
                  color: ScpColors.blue,
                  bg: ScpColors.blueLight,
                  onTap: _create,
                ),
                ScpQuickActionItem(
                  icon: Icons.calendar_month_rounded,
                  title: 'Jadwal\nHari Ini',
                  color: ScpColors.teal,
                  bg: ScpColors.tealCard,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                ScpQuickActionItem(
                  icon: Icons.description_outlined,
                  title: 'Riwayat\nIzin',
                  color: ScpColors.purple,
                  bg: ScpColors.purpleCard,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                ScpQuickActionItem(
                  icon: Icons.refresh_rounded,
                  title: 'Segarkan\nData',
                  color: ScpColors.amber,
                  bg: ScpColors.amberCard,
                  onTap: () => _load(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stat Cards
            ScpSectionHeader(title: 'Status Izin Saya'),
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
                    onTap: () => widget.onNavigateTab?.call(2),
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
                    onTap: () => widget.onNavigateTab?.call(2),
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
                  onPressed: () => widget.onNavigateTab?.call(1),
                  child: const Text('Buka Jadwal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: ScpEmpty(
                  message: 'Belum ada jadwal pelajaran hari ini',
                  icon: Icons.event_available_outlined,
                ),
              )
            else
              for (var i = 0; i < _schedules.length && i < 4; i++)
                _scheduleRow(_schedules[i], i),

            const SizedBox(height: 18),

            // Recent Leaves Section
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
                  onPressed: () => widget.onNavigateTab?.call(2),
                  child: const Text('Semua Izin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_leaves.isEmpty)
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
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending').toString();
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

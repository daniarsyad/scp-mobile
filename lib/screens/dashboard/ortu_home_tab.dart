import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import '../ortu/create_leave_ortu_screen.dart';

class OrtuHomeTab extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int>? onNavigateTab;

  const OrtuHomeTab({
    super.key,
    required this.user,
    this.onNavigateTab,
  });

  @override
  State<OrtuHomeTab> createState() => _OrtuHomeTabState();
}

class _OrtuHomeTabState extends State<OrtuHomeTab> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _leaves = [];

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
    final children = await _api.get(ApiConfig.children);
    final leaves = await _api.get(ApiConfig.myLeaveRequests);
    if (!mounted) return;

    final childRows = <Map<String, dynamic>>[];
    if (children['success'] == true) {
      for (final item in asList(children['data'])) {
        childRows.add(asMap(item));
      }
    }
    final leaveRows = <Map<String, dynamic>>[];
    if (leaves['success'] == true) {
      for (final item in asList(leaves['data'])) {
        leaveRows.add(asMap(item));
      }
    }

    setState(() {
      _loading = false;
      _children = childRows;
      _leaves = leaveRows;
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
      MaterialPageRoute(builder: (_) => const CreateLeaveOrtuScreen()),
    );
    if (ok == true) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullname.isEmpty ? 'Orang Tua' : widget.user.fullname;
    final approved = _countStatus('Approved');
    final pending = _countStatus('Pending');
    final childName = _children.isEmpty
        ? 'Belum Ada Data Anak'
        : (_children.first['fullname']?.toString() ?? 'Anak');

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
            roleName: 'Orang Tua / Wali',
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
                  value: '${_children.length}',
                  label: 'Siswa / Anak Terdaftar',
                  footerTitle: childName,
                  footerSubtitle: 'Monitoring Pembelajaran',
                  gradient: ScpColors.amberGradient,
                  icon: Icons.family_restroom_rounded,
                ),
                ScpHeroData(
                  value: '${_leaves.length}',
                  label: 'Total Pengajuan Izin',
                  footerTitle: name,
                  footerSubtitle: todayLabel(),
                  gradient: ScpColors.navyGradient,
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
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Ajukan\nIzin Anak',
                  color: ScpColors.blue,
                  bg: ScpColors.blueLight,
                  onTap: _create,
                ),
                ScpQuickActionItem(
                  icon: Icons.family_restroom_rounded,
                  title: 'Data &\nJadwal Anak',
                  color: ScpColors.teal,
                  bg: ScpColors.tealCard,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                ScpQuickActionItem(
                  icon: Icons.refresh_rounded,
                  title: 'Segarkan\nStatus',
                  color: ScpColors.amber,
                  bg: ScpColors.amberCard,
                  onTap: () => _load(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stat Cards
            ScpSectionHeader(title: 'Ringkasan Izin Anak'),
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ScpStatCard(
                    label: 'Menunggu',
                    value: '$pending',
                    background: ScpColors.amberCard,
                    valueColor: ScpColors.amber,
                    icon: Icons.hourglass_top_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Children Summary Card
            Row(
              children: [
                const Text(
                  'Data Anak Anda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  child: const Text('Detail Anak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_children.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: ScpEmpty(
                  message: 'Belum ada data siswa yang tertaut dengan akun orang tua ini.',
                  icon: Icons.person_off_outlined,
                ),
              )
            else
              for (final child in _children)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ScpColors.line),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: ScpColors.amber.withValues(alpha: 0.15),
                        child: const Icon(Icons.school_rounded, color: ScpColors.amber, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child['fullname']?.toString() ?? 'Anak',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kelas: ${child['class']?['class_name'] ?? child['class_name'] ?? "-"} • NISN/Username: ${child['username'] ?? "-"}',
                              style: const TextStyle(color: ScpColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

            const SizedBox(height: 18),

            // Recent Leaves
            const ScpSectionHeader(title: 'Riwayat Pengajuan Izin'),
            const SizedBox(height: 8),

            if (_leaves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: ScpEmpty(
                  message: 'Belum ada pengajuan izin anak. Klik tombol "Ajukan Izin Anak" di atas.',
                  icon: Icons.assignment_outlined,
                ),
              )
            else
              for (var i = 0; i < _leaves.length && i < 5; i++)
                _leaveRow(_leaves[i], i),
          ],
        ],
      ),
    );
  }

  Widget _leaveRow(Map<String, dynamic> item, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending').toString();
    final student = item['student']?['fullname']?.toString() ?? 'Anak';
    final start = formatShortDate((item['start_date'] ?? '').toString());
    final reason = item['reason']?.toString() ?? '-';
    return ScpActivityTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: '$student  •  $reason',
      subtitle: 'Tanggal mulai: $start',
      trailing: _label(status),
      trailingColor: _color(status),
    );
  }

  Color _color(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return ScpColors.green;
      case 'rejected':
        return ScpColors.red;
      default:
        return ScpColors.amber;
    }
  }

  String _label(String status) {
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

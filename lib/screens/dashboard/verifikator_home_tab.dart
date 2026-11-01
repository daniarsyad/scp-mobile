import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../utils/media_url.dart';
import '../../widgets/dashboard_kit.dart';

class VerifikatorHomeTab extends StatefulWidget {
  final UserModel user;
  final bool isBk;
  final ValueChanged<int>? onNavigateTab;

  const VerifikatorHomeTab({
    super.key,
    required this.user,
    required this.isBk,
    this.onNavigateTab,
  });

  @override
  State<VerifikatorHomeTab> createState() => _VerifikatorHomeTabState();
}

class _VerifikatorHomeTabState extends State<VerifikatorHomeTab> {
  final _api = ApiService();
  bool _loading = true;
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
    final result = await _api.get(ApiConfig.pendingLeaves);
    if (!mounted) return;

    final rows = <Map<String, dynamic>>[];
    if (result['success'] == true) {
      for (final item in asList(result['data'])) {
        rows.add(asMap(item));
      }
    }
    setState(() {
      _loading = false;
      _leaves = rows;
    });
  }

  String _studentClassName(Map<String, dynamic> item) {
    final student = item['student'];
    if (student is Map) {
      final cls = student['class'];
      if (cls is Map) {
        final name = cls['class_name']?.toString();
        if (name != null && name.isNotEmpty) return name;
      }
      final direct = student['class_name']?.toString();
      if (direct != null && direct.isNotEmpty) return direct;
    }
    return item['class_name']?.toString() ?? 'Kelas Lain';
  }

  List<Map<String, dynamic>> _scopedLeaves() {
    if (widget.isBk) return _leaves;
    final target = widget.user.className;
    if (target == null || target.isEmpty) return _leaves;

    return _leaves.where((item) {
      final cls = _studentClassName(item);
      return cls.toLowerCase().contains(target.toLowerCase()) ||
          target.toLowerCase().contains(cls.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullname.isEmpty
        ? (widget.isBk ? 'Guru BK' : 'Wali Kelas')
        : widget.user.fullname;
    final role =
        widget.user.roleName ?? (widget.isBk ? 'Guru BK' : 'Wali Kelas');
    final scoped = _scopedLeaves();
    final missingSurat = scoped
        .where((item) => firstMedia(item, suratKeys) == null)
        .length;
    final withSurat = scoped.length - missingSurat;

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
            roleName: role,
            className: widget.user.className,
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: ScpColors.blue),
              ),
            )
          else ...[
            // Hero Card
            ScpHeroPager(
              pages: [
                ScpHeroData(
                  value: '${scoped.length}',
                  label: widget.isBk
                      ? 'Izin menunggu pemantauan (Semua Kelas)'
                      : 'Izin menunggu (Kelas ${widget.user.className ?? ""})',
                  footerTitle: name,
                  footerSubtitle: widget.isBk
                      ? 'Bimbingan & Konseling Siswa'
                      : 'Wali Kelas ${widget.user.className ?? ""}',
                  gradient: widget.isBk
                      ? ScpColors.purpleGradient
                      : ScpColors.tealGradient,
                  icon: Icons.verified_user_outlined,
                ),
                ScpHeroData(
                  value: '$withSurat',
                  label: 'Dilengkapi surat keterangan dokter',
                  footerTitle: 'Verifikasi Dokumen',
                  footerSubtitle: todayLabel(),
                  gradient: ScpColors.primaryGradient,
                  icon: Icons.medical_services_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions Section
            const ScpSectionHeader(title: 'Aksi Cepat'),
            const SizedBox(height: 10),
            if (widget.isBk)
              ScpQuickActionsGrid(
                items: [
                  ScpQuickActionItem(
                    icon: Icons.assessment_rounded,
                    title: 'Laporan\nPresensi',
                    color: ScpColors.purple,
                    bg: ScpColors.purpleCard,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.fact_check_rounded,
                    title: 'Monitoring\nIzin Siswa',
                    color: ScpColors.amber,
                    bg: ScpColors.amberCard,
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.edit_note_rounded,
                    title: 'Jurnal\n(Opsional)',
                    color: ScpColors.blue,
                    bg: ScpColors.blueLight,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.event_note_rounded,
                    title: 'Jadwal\nMengajar',
                    color: ScpColors.teal,
                    bg: ScpColors.tealCard,
                    onTap: () => widget.onNavigateTab?.call(4),
                  ),
                ],
              )
            else
              ScpQuickActionsGrid(
                items: [
                  ScpQuickActionItem(
                    icon: Icons.fact_check_rounded,
                    title: 'Verifikasi\nIzin Kelas',
                    color: ScpColors.teal,
                    bg: ScpColors.tealCard,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.menu_book_rounded,
                    title: 'Jurnal\nMengajar',
                    color: ScpColors.blue,
                    bg: ScpColors.blueLight,
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.assessment_rounded,
                    title: 'Presensi\nKelas Sendiri',
                    color: ScpColors.purple,
                    bg: ScpColors.purpleCard,
                    onTap: () => widget.onNavigateTab?.call(3),
                  ),
                  ScpQuickActionItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Jadwal\nKBM',
                    color: ScpColors.amber,
                    bg: ScpColors.amberCard,
                    onTap: () => widget.onNavigateTab?.call(4),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Stat Cards
            ScpSectionHeader(title: 'Ringkasan Antrian', chip: todayLabel()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ScpStatCard(
                    label: 'Total Menunggu',
                    value: '${scoped.length}',
                    background: ScpColors.amberCard,
                    valueColor: ScpColors.amber,
                    icon: Icons.hourglass_top_rounded,
                    onTap: () =>
                        widget.onNavigateTab?.call(widget.isBk ? 2 : 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ScpStatCard(
                    label: 'Ada Surat Dokter',
                    value: '$withSurat',
                    background: ScpColors.greenCard,
                    valueColor: ScpColors.green,
                    icon: Icons.assignment_turned_in_rounded,
                    onTap: () =>
                        widget.onNavigateTab?.call(widget.isBk ? 2 : 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ScpStatCard(
                    label: 'Tanpa Surat',
                    value: '$missingSurat',
                    background: ScpColors.redCard,
                    valueColor: ScpColors.red,
                    icon: Icons.error_outline_rounded,
                    onTap: () =>
                        widget.onNavigateTab?.call(widget.isBk ? 2 : 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Pending Queue List
            Row(
              children: [
                const Text(
                  'Perlu Ditinjau Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      widget.onNavigateTab?.call(widget.isBk ? 2 : 1),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (scoped.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ScpEmpty(
                  message: widget.isBk
                      ? 'Tidak ada pengajuan izin yang menunggu review'
                      : 'Tidak ada pengajuan izin pending untuk kelas ${widget.user.className ?? ""}',
                  icon: Icons.verified_outlined,
                ),
              )
            else
              for (var i = 0; i < scoped.length && i < 5; i++)
                _row(scoped[i], i),
          ],
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> item, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final student = asMap(item['student']);
    final studentName = student['fullname']?.toString() ?? 'Siswa';
    final reason = item['reason']?.toString() ?? '-';
    final start = formatShortDate((item['start_date'] ?? '').toString());
    final hasSurat = firstMedia(item, suratKeys) != null;
    final className = _studentClassName(item);

    return ScpActivityTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: '$studentName ($className)',
      subtitle: '$start  •  $reason',
      trailing: hasSurat ? 'Ada Surat' : 'Tanpa Surat',
      trailingColor: hasSurat ? ScpColors.green : ScpColors.amber,
      onTap: () => widget.onNavigateTab?.call(widget.isBk ? 2 : 1),
    );
  }
}

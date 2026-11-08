import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import '../attendance_report_screen.dart';
import '../guru/attendance_screen.dart';
import '../guru/create_journal_screen.dart';
import '../edit_profile_screen.dart';
import '../../services/journal_draft_store.dart';

class GuruHomeTab extends StatefulWidget {
  final UserModel user;
  final ValueChanged<Map<String, dynamic>?> onNextSchedule;
  final ValueChanged<int>? onNavigateTab;
  final int recapTabIndex;
  final int journalTabIndex;
  final int? attendanceTabIndex;
  final bool showRecapAction;
  final ValueChanged<UserModel>? onProfileUpdated;

  const GuruHomeTab({
    super.key,
    required this.user,
    required this.onNextSchedule,
    this.onNavigateTab,
    this.recapTabIndex = 1,
    this.journalTabIndex = 2,
    this.attendanceTabIndex,
    this.showRecapAction = true,
    this.onProfileUpdated,
  });

  @override
  State<GuruHomeTab> createState() => _GuruHomeTabState();
}

class _GuruHomeTabState extends State<GuruHomeTab> {
  final _api = ApiService();
  bool _loading = true;
  String? _cycle;
  bool _locked = false;
  List<Map<String, dynamic>> _today = [];
  int _hiddenCount = 0;
  final _draftStore = JournalDraftStore();
  Set<int> _draftScheduleIds = {};
  String? _draftError;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    LiveRefresh.journals.addListener(_onPing);
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    LiveRefresh.journals.removeListener(_onPing);
    super.dispose();
  }

  void _onPing() {
    if (mounted) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    final config = await _api.get(ApiConfig.systemConfig);
    final today = await _api.get(ApiConfig.schedulesToday);
    Set<int> draftScheduleIds = {};
    String? draftError;
    try {
      draftScheduleIds = (await _draftStore.loadAll(ownerId: widget.user.id))
          .where((draft) => draft.date == todayIso())
          .map((draft) => draft.scheduleId)
          .toSet();
    } catch (error) {
      draftError = 'Gagal memuat draf lokal: $error';
    }
    if (!mounted) return;

    final rows = <Map<String, dynamic>>[];
    if (today['success'] == true) {
      for (final item in asList(today['data'])) {
        rows.add(asMap(item));
      }
    }
    rows.sort(
      (a, b) => formatTime(a['start_time']).compareTo(formatTime(b['start_time'])),
    );

    String? cycle = _cycle;
    var locked = _locked;
    if (config['success'] == true && config['data'] is Map) {
      final data = asMap(config['data']);
      cycle = data['active_cycle']?.toString();
      locked =
          data['is_schedule_locked'] == true || data['is_schedule_locked'] == 1;
    }

    Map<String, dynamic>? next;
    for (final row in rows) {
      if (!scheduleNotStarted(row) && !journalFilledToday(row)) {
        next = row;
        break;
      }
    }

    setState(() {
      _loading = false;
      _today = rows;
      _hiddenCount = rows.where(scheduleNotStarted).length;
      _cycle = cycle;
      _locked = locked;
      _draftScheduleIds = draftScheduleIds;
      _draftError = draftError;
    });
    widget.onNextSchedule(next);
  }

  Future<void> _open(Map<String, dynamic> schedule) async {
    if (scheduleNotStarted(schedule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jurnal baru dapat diisi saat jam pelajaran dimulai.'),
        ),
      );
      return;
    }
    final filled = journalForToday(schedule);
    bool? saved;
    if (filled != null) {
      final journalId = asInt(filled['id'] ?? filled['journal_id']);
      if (journalId != 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              journalId: journalId,
              subject: schedule['subject']?.toString() ?? 'Pelajaran',
              className: asMap(schedule['class'])['class_name']?.toString() ?? '-',
            ),
          ),
        );
        return;
      }
      if (widget.onNavigateTab != null && widget.attendanceTabIndex != null) {
        widget.onNavigateTab!(widget.attendanceTabIndex!);
        return;
      }
      if (widget.user.isWaliKelas || widget.user.isGuruBK) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceReportScreen(
              isBk: widget.user.isGuruBK,
              user: widget.user,
            ),
          ),
        );
      } else if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(widget.journalTabIndex);
      }
      return;
    } else {
      saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreateJournalScreen(schedule: schedule, ownerId: widget.user.id),
        ),
      );
    }
    if (mounted) {
      _load(silent: true);
      if (saved == true && widget.attendanceTabIndex != null) {
        widget.onNavigateTab?.call(widget.attendanceTabIndex!);
      }
    }
  }

  List<Map<String, dynamic>> get _visibleToday =>
      _today.where((row) => !scheduleNotStarted(row)).toList();

  @override
  Widget build(BuildContext context) {
    final visible = _visibleToday;
    final filled = visible.where(journalFilledToday).length;
    final missing = visible.length - filled;
    final name = widget.user.fullname.isEmpty ? 'Guru' : widget.user.fullname;

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
            roleName: widget.user.roleName ?? 'Guru Pengajar',
            className: widget.user.displayClassName,
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
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: ScpColors.blue),
              ),
            )
          else ...[
            if (_draftError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _draftError!,
                  style: const TextStyle(color: ScpColors.red),
                ),
              ),
            ScpHeroPager(
              pages: [
                ScpHeroData(
                  value: '${visible.length}',
                  label: 'Jadwal Mengajar Hari Ini',
                  footerTitle: name,
                  footerSubtitle: todayDayName(),
                  gradient: ScpColors.primaryGradient,
                  icon: Icons.school_rounded,
                ),
                ScpHeroData(
                  value: _cycle == null || _cycle!.isEmpty
                      ? 'Reguler'
                      : 'Putaran $_cycle',
                  label: _locked
                      ? 'Status: Jadwal Terkunci'
                      : 'Status: Jadwal Terbuka',
                  footerTitle: 'Sistem Pembelajaran',
                  footerSubtitle: todayLabel(),
                  gradient: ScpColors.navyGradient,
                  icon: Icons.access_time_rounded,
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
                  icon: Icons.edit_note_rounded,
                  title: 'Isi Jurnal\nMengajar',
                  color: ScpColors.blue,
                  bg: ScpColors.blueLight,
                  onTap: () {
                    for (final row in visible) {
                      if (!journalFilledToday(row)) {
                        _open(row);
                        return;
                      }
                    }
                    if (visible.isNotEmpty) {
                      _open(visible.first);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Belum ada jadwal yang jamnya sudah dimulai',
                          ),
                        ),
                      );
                    }
                  },
                ),
                if (widget.showRecapAction)
                  ScpQuickActionItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Rekap\nKBM',
                    color: ScpColors.teal,
                    bg: ScpColors.tealCard,
                    onTap: () =>
                        widget.onNavigateTab?.call(widget.recapTabIndex),
                  ),
                ScpQuickActionItem(
                  icon: Icons.menu_book_rounded,
                  title: 'Riwayat\nJurnal',
                  color: ScpColors.purple,
                  bg: ScpColors.purpleCard,
                  onTap: () =>
                      widget.onNavigateTab?.call(widget.journalTabIndex),
                ),
                ScpQuickActionItem(
                  icon: Icons.refresh_rounded,
                  title: 'Muat\nUlang',
                  color: ScpColors.amber,
                  bg: ScpColors.amberCard,
                  onTap: () => _load(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stat Cards Section
            ScpSectionHeader(
              title: 'Progres Jurnal Hari Ini',
              chip: todayLabel(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ScpStatCard(
                    label: 'Sudah Terisi',
                    value: '$filled',
                    background: ScpColors.greenCard,
                    valueColor: ScpColors.green,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ScpStatCard(
                    label: 'Belum Terisi',
                    value: '$missing',
                    background: missing > 0
                        ? ScpColors.redCard
                        : ScpColors.surfaceAlt,
                    valueColor: missing > 0 ? ScpColors.red : ScpColors.muted,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                const Text(
                  'Jadwal KBM Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ScpColors.blueLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ScpColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Putaran ${_cycle ?? "2"} Aktif',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ScpColors.blue,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _hiddenCount > 0 ? '${visible.length} aktif ($_hiddenCount menunggu)' : '${visible.length} sesi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ScpColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ScpEmpty(
                  message: _hiddenCount > 0
                      ? 'Jadwal berikutnya akan tampil saat jam pelajarannya dimulai'
                      : (DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday
                          ? 'Hari ini libur akhir pekan (tidak ada jadwal mengajar)'
                          : 'Tidak ada jadwal mengajar pada hari ini'),
                  icon: (DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday)
                      ? Icons.weekend_outlined
                      : Icons.event_available_outlined,
                ),
              )
            else
              for (var i = 0; i < visible.length; i++) _row(visible[i], i),
              if (_hiddenCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ScpColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ScpColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, size: 18, color: ScpColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_hiddenCount sesi KBM lainnya belum masuk jam pelajaran dan akan muncul otomatis saat jamnya tiba.',
                          style: const TextStyle(fontSize: 12, color: ScpColors.muted),
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

  Widget _row(Map<String, dynamic> schedule, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final done = journalFilledToday(schedule);
    final hasDraft = !done && _draftScheduleIds.contains(asInt(schedule['id']));
    final subject = schedule['subject']?.toString() ?? '-';
    final className = schedule['class']?['class_name']?.toString() ?? '-';
    final roomName = schedule['room']?['room_name']?.toString();
    final start = formatTime(schedule['start_time']);
    final end = formatTime(schedule['end_time']);
    final roomSuffix = (roomName != null && roomName.isNotEmpty) ? '  •  Ruang $roomName' : '';

    return ScpActivityTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: subject,
      subtitle: hasDraft
          ? '$start - $end  •  Kelas $className$roomSuffix  •  🟡 Draf Presensi Tersimpan • Belum Selesai Jurnal'
          : '$start - $end  •  Kelas $className$roomSuffix',
      trailing: hasDraft
          ? 'Lanjutkan Jurnal »'
          : done
          ? 'Terisi'
          : 'Isi Jurnal',
      trailingColor: hasDraft
          ? ScpColors.amber
          : done
          ? ScpColors.green
          : ScpColors.blue,
      onTap: () => _open(schedule),
    );
  }
}

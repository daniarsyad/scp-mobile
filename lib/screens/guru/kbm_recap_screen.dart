import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import '../attendance_report_screen.dart';
import 'create_journal_screen.dart';

class KbmRecapScreen extends StatefulWidget {
  final bool embedded;
  final int ownerId;
  final UserModel? user;

  const KbmRecapScreen({
    super.key,
    this.embedded = false,
    this.ownerId = 0,
    this.user,
  });

  @override
  State<KbmRecapScreen> createState() => _KbmRecapScreenState();
}

class _KbmRecapScreenState extends State<KbmRecapScreen> {
  final _api = ApiService();
  bool _loading = true;
  int _kbmScope = 0; // 0: KBM Kelas Binaan (Wali Kelas), 1: KBM Mengajar Saya
  String? _activeCycle = '2';
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    LiveRefresh.journals.addListener(_onPing);
    _load();
  }

  @override
  void dispose() {
    LiveRefresh.journals.removeListener(_onPing);
    super.dispose();
  }

  void _onPing() {
    if (mounted) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final isWaliKelas = widget.user?.isWaliKelas == true;
    final String path;
    if (isWaliKelas && _kbmScope == 0) {
      final classId = widget.user?.classId;
      path = classId != null && classId > 0
          ? '${ApiConfig.schedules}?class_id=$classId'
          : ApiConfig.mySchedules;
    } else {
      path = ApiConfig.mySchedules;
    }
    final configFuture = _api.get(ApiConfig.systemConfig);
    final result = await _api.get(path);
    final configResult = await configFuture;
    if (!mounted) return;

    if (configResult['success'] == true && configResult['data'] is Map) {
      _activeCycle = configResult['data']['active_cycle']?.toString() ?? _activeCycle;
    }

    if (result['success'] == true) {
      final rows = <Map<String, dynamic>>[];
      for (final item in asList(result['data'])) {
        rows.add(asMap(item));
      }
      setState(() {
        _loading = false;
        _schedules = rows;
        _error = null;
      });
    } else if (!silent) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Gagal memuat rekap KBM';
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> schedule) async {
    final todayName = todayDayName().toLowerCase();
    final day = (schedule['day_of_week'] ?? '').toString().toLowerCase();
    final filled = day == todayName ? journalForToday(schedule) : null;
    if (filled != null && asInt(filled['id']) != 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceReportScreen(isBk: false, user: widget.user),
        ),
      );
      return;
    } else {
      if (scheduleNotStarted(schedule)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jurnal baru dapat diisi saat jam pelajaran dimulai.'),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreateJournalScreen(schedule: schedule, ownerId: widget.ownerId),
        ),
      );
    }
    if (mounted) _load(silent: true);
  }

  Widget _scopeSelector() {
    final className = widget.user?.className ?? 'Kelas Binaan';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScpColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text('🏫 Kelas $className', textAlign: TextAlign.center),
              ),
              selected: _kbmScope == 0,
              onSelected: (_) {
                if (_kbmScope != 0) {
                  setState(() => _kbmScope = 0);
                  _load();
                }
              },
              showCheckmark: false,
              selectedColor: ScpColors.blue,
              backgroundColor: Colors.transparent,
              labelStyle: TextStyle(
                color: _kbmScope == 0 ? Colors.white : ScpColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide.none,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ChoiceChip(
              label: const SizedBox(
                width: double.infinity,
                child: Text('👨‍🏫 Mengajar Saya', textAlign: TextAlign.center),
              ),
              selected: _kbmScope == 1,
              onSelected: (_) {
                if (_kbmScope != 1) {
                  setState(() => _kbmScope = 1);
                  _load();
                }
              },
              showCheckmark: false,
              selectedColor: ScpColors.blue,
              backgroundColor: Colors.transparent,
              labelStyle: TextStyle(
                color: _kbmScope == 1 ? Colors.white : ScpColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return ColoredBox(color: ScpColors.bg, child: body);
    return ScpPage(
      title: 'Rekap KBM',
      actions: [
        IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
      ],
      body: body,
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ScpColors.blue),
      );
    }
    if (_error != null) {
      return ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined);
    }

    final filledToday = _schedules.where((item) {
      final day = (item['day_of_week'] ?? '').toString().toLowerCase();
      return day == todayDayName().toLowerCase() && journalFilledToday(item);
    }).length;
    final todaySlots = _schedules.where((item) {
      return (item['day_of_week'] ?? '').toString().toLowerCase() ==
          todayDayName().toLowerCase();
    }).length;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _schedules) {
      final day = (item['day_of_week'] ?? 'Lainnya').toString();
      grouped.putIfAbsent(day, () => []).add(item);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final ra = dayNames.indexWhere(
          (d) => d.toLowerCase() == a.toLowerCase(),
        );
        final rb = dayNames.indexWhere(
          (d) => d.toLowerCase() == b.toLowerCase(),
        );
        return (ra < 0 ? 99 : ra).compareTo(rb < 0 ? 99 : rb);
      });

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ScpColors.blueLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ScpColors.blue.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: ScpColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Putaran Aktif: Putaran ${_activeCycle ?? "2"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ScpColors.blue,
                    ),
                  ),
                ),
                Text(
                  todayDayName(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ScpColors.blueDark,
                  ),
                ),
              ],
            ),
          ),
          if (widget.user?.isWaliKelas == true) ...[
            _scopeSelector(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ScpStatCard(
                  label: widget.user?.isWaliKelas == true && _kbmScope == 0
                      ? 'Total Jam Kelas'
                      : 'Jam Mengajar',
                  value: '${_schedules.length}',
                  background: ScpColors.greenCard,
                  valueColor: ScpColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ScpStatCard(
                  label: 'Belum hari ini',
                  value: '${todaySlots - filledToday}',
                  background: ScpColors.redCard,
                  valueColor: ScpColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (keys.isEmpty)
            const ScpEmpty(message: 'Belum ada jadwal KBM')
          else
            for (final day in keys) ...[
              const SizedBox(height: 6),
              Text(
                day,
                style: const TextStyle(
                  color: ScpColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (var i = 0; i < grouped[day]!.length; i++)
                _tile(grouped[day]![i], i, day),
            ],
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> schedule, int index, String day) {
    final palette = activityPalette[index % activityPalette.length];
    final subject = schedule['subject']?.toString() ?? '-';
    final className = schedule['class']?['class_name']?.toString() ?? '-';
    final room = schedule['room']?['room_name']?.toString() ?? '-';
    final teacher = schedule['teacher']?['fullname']?.toString();
    final start = formatTime(schedule['start_time']);
    final end = formatTime(schedule['end_time']);
    final isToday = day.toLowerCase() == todayDayName().toLowerCase();
    final done = isToday
        ? journalFilledToday(schedule)
        : journalTotal(schedule) > 0;
    final total = journalTotal(schedule);

    final isHomeroomClassMode = widget.user?.isWaliKelas == true && _kbmScope == 0;
    final teacherOrClass = isHomeroomClassMode
        ? (teacher != null && teacher.isNotEmpty ? 'Guru: $teacher' : 'Kelas $className')
        : 'Kelas $className';

    final subtitle = isToday
        ? '$start-$end  •  $teacherOrClass  •  Ruang $room  •  ${done ? 'Jurnal hari ini terisi' : 'Jurnal belum diisi'}'
        : '$start-$end  •  $teacherOrClass  •  Ruang $room  •  $total jurnal';

    return ScpCategoryTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: subject,
      subtitle: subtitle,
      progress: done ? 1 : (total > 0 ? 0.45 : 0.08),
      progressColor: done ? ScpColors.green : palette.fg,
      onTap: () => _open(schedule),
    );
  }
}

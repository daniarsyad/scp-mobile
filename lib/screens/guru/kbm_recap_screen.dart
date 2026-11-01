import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';
import 'attendance_screen.dart';
import 'create_journal_screen.dart';

class KbmRecapScreen extends StatefulWidget {
  final bool embedded;
  final int ownerId;

  const KbmRecapScreen({super.key, this.embedded = false, this.ownerId = 0});

  @override
  State<KbmRecapScreen> createState() => _KbmRecapScreenState();
}

class _KbmRecapScreenState extends State<KbmRecapScreen> {
  final _api = ApiService();
  bool _loading = true;
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
    final result = await _api.get(ApiConfig.mySchedules);
    if (!mounted) return;

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
          builder: (_) => AttendanceScreen(
            journalId: asInt(filled['id']),
            subject: schedule['subject']?.toString() ?? '-',
            className: schedule['class']?['class_name']?.toString() ?? '-',
          ),
        ),
      );
    } else {
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
          Row(
            children: [
              Expanded(
                child: ScpStatCard(
                  label: 'Jam KBM',
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
    final start = formatTime(schedule['start_time']);
    final end = formatTime(schedule['end_time']);
    final isToday = day.toLowerCase() == todayDayName().toLowerCase();
    final done = isToday
        ? journalFilledToday(schedule)
        : journalTotal(schedule) > 0;
    final total = journalTotal(schedule);
    final subtitle = isToday
        ? '$start-$end  •  $className  •  ${done ? 'Jurnal hari ini terisi' : 'Jurnal belum diisi'}'
        : '$start-$end  •  $className  •  $room  •  $total jurnal';

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

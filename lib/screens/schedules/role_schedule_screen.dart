import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard_kit.dart';

class RoleScheduleScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic>? child;
  final bool embedded;

  const RoleScheduleScreen({
    super.key,
    required this.user,
    this.child,
    this.embedded = false,
  });

  @override
  State<RoleScheduleScreen> createState() => _RoleScheduleScreenState();
}

class _RoleScheduleScreenState extends State<RoleScheduleScreen> {
  final _api = ApiService();
  bool _loading = true;
  int _selectedView = 0;
  String _day = '';
  List<Map<String, dynamic>> _todaySchedules = [];
  List<Map<String, dynamic>> _cycleOneSchedules = [];
  List<Map<String, dynamic>> _cycleTwoSchedules = [];
  String? _todayError;
  String? _cycleOneError;
  String? _cycleTwoError;

  bool get _isTeacher =>
      widget.child == null && (widget.user.isGuru || widget.user.isGuruBK);

  String get _className {
    final child = widget.child;
    if (child != null) {
      return asMap(child['class'])['class_name']?.toString() ??
          child['class_name']?.toString() ??
          'Kelas anak';
    }
    return widget.user.className ?? 'Kelas';
  }

  int? get _classId {
    final child = widget.child;
    if (child != null) {
      final nestedClassId = asMap(child['class'])['id'];
      return asInt(child['class_id'] ?? nestedClassId);
    }
    return widget.user.classId;
  }

  String get _title {
    if (_isTeacher) return 'Jadwal Mengajar';
    if (widget.child != null) {
      return 'Jadwal ${widget.child!['fullname']?.toString() ?? 'Anak'}';
    }
    if (widget.user.isWaliKelas) return 'Jadwal Kelas $_className';
    return 'Jadwal Pelajaran';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _schedulePath({String? cycle, bool today = false}) {
    final path = today
        ? ApiConfig.schedulesToday
        : (_isTeacher ? ApiConfig.mySchedules : ApiConfig.schedules);
    final query = <String, String>{};
    if (!_isTeacher) {
      final classId = _classId;
      if (classId != null && classId > 0) {
        query['class_id'] = '$classId';
      } else if (_className != 'Kelas' && _className != 'Kelas anak') {
        query['class_name'] = _className;
      }
    }
    if (cycle != null) query['cycle'] = cycle;
    return query.isEmpty
        ? path
        : Uri(path: path, queryParameters: query).toString();
  }

  Future<({List<Map<String, dynamic>> schedules, String? error, String? day})>
  _fetchSchedules({
    required String path,
    required String failureMessage,
  }) async {
    final result = await _api.get(path);
    if (result['success'] != true) {
      return (
        schedules: <Map<String, dynamic>>[],
        error: result['message']?.toString().isNotEmpty == true
            ? result['message'].toString()
            : failureMessage,
        day: result['day']?.toString(),
      );
    }
    final schedules = asList(result['data']).map(asMap).toList()
      ..sort(_compareSchedules);
    return (schedules: schedules, error: null, day: result['day']?.toString());
  }

  int _compareSchedules(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dayA = dayNames.indexWhere(
      (day) => day.toLowerCase() == a['day_of_week']?.toString().toLowerCase(),
    );
    final dayB = dayNames.indexWhere(
      (day) => day.toLowerCase() == b['day_of_week']?.toString().toLowerCase(),
    );
    final byDay = (dayA < 0 ? 99 : dayA).compareTo(dayB < 0 ? 99 : dayB);
    if (byDay != 0) return byDay;
    return formatTime(a['start_time']).compareTo(formatTime(b['start_time']));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _todayError = null;
      _cycleOneError = null;
      _cycleTwoError = null;
    });

    final results = await Future.wait([
      _fetchSchedules(
        path: _schedulePath(today: true),
        failureMessage: 'Gagal memuat jadwal hari ini',
      ),
      _fetchSchedules(
        path: _schedulePath(cycle: '1'),
        failureMessage: 'Gagal memuat jadwal Putaran 1',
      ),
      _fetchSchedules(
        path: _schedulePath(cycle: '2'),
        failureMessage: 'Gagal memuat jadwal Putaran 2',
      ),
    ]);
    if (!mounted) return;

    final todayResult = results[0];
    final cycleOneResult = results[1];
    final cycleTwoResult = results[2];
    setState(() {
      _loading = false;
      _day = todayResult.day ?? todayDayName();
      _todaySchedules = todayResult.schedules;
      _todayError = todayResult.error;
      _cycleOneSchedules = cycleOneResult.schedules;
      _cycleOneError = cycleOneResult.error;
      _cycleTwoSchedules = cycleTwoResult.schedules;
      _cycleTwoError = cycleTwoResult.error;
    });
  }

  List<Map<String, dynamic>> _forCycle(
    List<Map<String, dynamic>> schedules,
    String cycle,
  ) {
    return schedules
        .where((schedule) => _scheduleCycle(schedule) == cycle)
        .toList();
  }

  String? _scheduleCycle(Map<String, dynamic> schedule) {
    const cycleKeys = [
      'target_cycle',
      'target_rotation',
      'cycle',
      'rotation',
      'putaran',
      'putaran_ke',
      'cycle_number',
      'rotation_number',
      'cycle_name',
      'rotation_name',
      'cycle_type',
      'rotation_type',
      'cycle_id',
      'rotation_id',
      'putaran_id',
    ];

    for (final key in cycleKeys) {
      final cycle = _parseCycle(schedule[key]);
      if (cycle != null) return cycle;
    }
    return null;
  }

  String? _parseCycle(dynamic value) {
    if (value is Map) {
      for (final key in [
        'target_cycle',
        'cycle',
        'rotation',
        'putaran',
        'cycle_number',
        'rotation_number',
        'name',
        'label',
        'number',
        'value',
        'id',
      ]) {
        final cycle = _parseCycle(value[key]);
        if (cycle != null) return cycle;
      }
      return null;
    }

    if (value is num) {
      final number = value.toInt();
      return number == 1 || number == 2 ? '$number' : null;
    }
    if (value == null) return null;

    final text = value.toString().trim().toLowerCase();
    if (text == '1' || text == '2') return text;
    final match = RegExp(r'(?:putaran|rotation|cycle|p)\s*[-_. ]?\s*([12])')
        .firstMatch(text);
    return match?.group(1);
  }

  String? _missingCycleMetadataMessage(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty ||
        schedules.any((schedule) => _scheduleCycle(schedule) != null)) {
      return null;
    }
    return 'Data jadwal dari server belum menyertakan informasi putaran. '
        'Minta admin memperbaiki API jadwal agar mengirim putaran setiap jadwal.';
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) return ColoredBox(color: ScpColors.bg, child: body);
    return Scaffold(
      backgroundColor: ScpColors.bg,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: body,
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ScpColors.blue),
      );
    }

    final schedules = switch (_selectedView) {
      1 => _forCycle(_cycleOneSchedules, '1'),
      2 => _forCycle(_cycleTwoSchedules, '2'),
      _ => _todaySchedules,
    };
    final error = switch (_selectedView) {
      1 => _cycleOneError,
      2 => _cycleTwoError,
      _ => _todayError,
    };
    final cycleSchedules = _selectedView == 1
        ? _cycleOneSchedules
        : _cycleTwoSchedules;
    final displayError =
        error ??
        (_selectedView == 0
            ? null
            : _missingCycleMetadataMessage(cycleSchedules));

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          _viewSelector(),
          const SizedBox(height: 14),
          _summaryCard(schedules.length),
          const SizedBox(height: 14),
          if (displayError != null)
            ScpEmpty(
              message: displayError,
              icon: error != null
                  ? Icons.cloud_off_outlined
                  : Icons.info_outline_rounded,
            )
          else if (schedules.isEmpty)
            ScpEmpty(
              message: _selectedView == 0
                  ? 'Tidak ada jadwal pelajaran hari ini'
                  : 'Belum ada jadwal pada Putaran $_selectedView',
              icon: Icons.event_busy_outlined,
            )
          else
            for (var index = 0; index < schedules.length; index++)
              _scheduleCard(schedules[index], index),
        ],
      ),
    );
  }

  Widget _viewSelector() {
    const labels = ['Hari Ini', 'Putaran 1', 'Putaran 2'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScpColors.line),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(labels[index], textAlign: TextAlign.center),
                  ),
                  selected: _selectedView == index,
                  onSelected: (_) => setState(() => _selectedView = index),
                  showCheckmark: false,
                  selectedColor: ScpColors.blue,
                  backgroundColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: _selectedView == index
                        ? Colors.white
                        : ScpColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide.none,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(int count) {
    final subtitle = _selectedView == 0
        ? 'Hari ini: ${_day.isEmpty ? todayDayName() : _day}'
        : 'Jadwal lengkap kelas dan mata pelajaran';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ScpColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedView == 0
                      ? 'Jadwal Pelajaran Hari Ini'
                      : 'Jadwal Putaran $_selectedView',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> schedule, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final start = formatTime(schedule['start_time']);
    final end = formatTime(schedule['end_time']);
    final subject = schedule['subject']?.toString() ?? 'Mata pelajaran';
    final className =
        asMap(schedule['class'])['class_name']?.toString() ?? _className;
    final teacher = asMap(schedule['teacher'])['fullname']?.toString();
    final room = asMap(schedule['room'])['room_name']?.toString();
    final day = schedule['day_of_week']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScpColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  start,
                  style: TextStyle(
                    color: palette.fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  end,
                  style: const TextStyle(color: ScpColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (_selectedView != 0 && day != null && day.isNotEmpty)
                      day,
                    if (className.isNotEmpty) 'Kelas $className',
                    if (teacher != null && teacher.isNotEmpty) teacher,
                    if (room != null && room.isNotEmpty) 'Ruang $room',
                  ].join(' • '),
                  style: const TextStyle(color: ScpColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

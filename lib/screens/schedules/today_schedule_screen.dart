import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({super.key});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _day = '';
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.get(ApiConfig.schedulesToday);

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _day = (result['day'] ?? '').toString();
        final data = result['data'];
        _schedules = data is List ? data : [];
      } else {
        _error = result['message'] ?? 'Gagal memuat jadwal';
      }
    });
  }

  String _time(dynamic v) {
    final s = (v ?? '').toString();
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  /// Cek apakah jam sekarang ada di antara start - end
  bool _isOngoing(String start, String end) {
    try {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final sParts = start.split(':');
      final eParts = end.split(':');
      if (sParts.length < 2 || eParts.length < 2) return false;

      final startMinutes = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endMinutes = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);

      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } catch (_) {
      return false;
    }
  }

  Widget _infoChip({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_day.isEmpty ? 'Jadwal Hari Ini' : 'Jadwal $_day'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _schedules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _day.isEmpty
                                ? 'Tidak ada jadwal hari ini'
                                : 'Tidak ada jadwal untuk $_day',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Header hari
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Hari ini: ${_day.isEmpty ? '-' : _day}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  _time('${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          ..._schedules.map((s) {
                            final subject = (s['subject'] ?? '-').toString();
                            final start = _time(s['start_time']);
                            final end = _time(s['end_time']);
                            final room = s['room']?['room_name']?.toString() ?? '-';
                            final className = s['class']?['class_name']?.toString() ?? '-';
                            final teacher = s['teacher']?['fullname']?.toString() ?? '-';
                            final ongoing = _isOngoing(start, end);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ongoing
                                      ? const Color(0xFF16A34A)
                                      : Colors.grey.shade200,
                                  width: ongoing ? 2 : 1,
                                ),
                                boxShadow: ongoing
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF16A34A).withOpacity(0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badge sedang berlangsung
                                    if (ongoing)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Sedang berlangsung',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                    // Jam + Mapel (digabung)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 78,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: ongoing
                                                ? const Color(0xFF16A34A).withOpacity(0.12)
                                                : const Color(0xFF1D4ED8).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                start,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: ongoing
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(0xFF1D4ED8),
                                                ),
                                              ),
                                              Text(
                                                end,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              subject,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // Info terpisah: Ruang, Kelas, Guru
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _infoChip(
                                          icon: Icons.meeting_room_outlined,
                                          label: 'Ruang',
                                          value: room,
                                        ),
                                        _infoChip(
                                          icon: Icons.groups_outlined,
                                          label: 'Kelas',
                                          value: className,
                                        ),
                                        _infoChip(
                                          icon: Icons.person_outline,
                                          label: 'Guru',
                                          value: teacher,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}
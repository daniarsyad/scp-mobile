import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import 'create_journal_screen.dart';

class GuruSchedulesScreen extends StatefulWidget {
  const GuruSchedulesScreen({super.key});

  @override
  State<GuruSchedulesScreen> createState() => _GuruSchedulesScreenState();
}

class _GuruSchedulesScreenState extends State<GuruSchedulesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _schedules = [];
  
  final Color primaryColor = const Color(0xFF5B67CA);
  final Color bgColor = const Color(0xFFF8F9FE);

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

    final result = await _api.get(ApiConfig.mySchedules);

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        _schedules = data is List ? data : (data['data'] ?? []);
      } else {
        _error = result['message'] ?? 'Gagal memuat jadwal';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jadwal Mengajar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: primaryColor),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _schedules.isEmpty
                          ? const Center(child: Text('Belum ada jadwal', style: TextStyle(color: Colors.grey)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: primaryColor,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                itemCount: _schedules.length,
                                itemBuilder: (context, index) {
                                  final s = _schedules[index] as Map<String, dynamic>;
                                  final subject = s['subject'] ?? '-';
                                  final day = s['day_of_week'] ?? '-';

                                  String start = '-';
                                  String end = '-';
                                  final st = (s['start_time'] ?? '').toString();
                                  final et = (s['end_time'] ?? '').toString();
                                  if (st.length >= 5) start = st.substring(0, 5);
                                  if (et.length >= 5) end = et.substring(0, 5);

                                  final className = s['class']?['class_name'] ?? '-';
                                  final roomName = s['room']?['room_name'] ?? '-';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateJournalScreen(
                                                schedule: Map<String, dynamic>.from(s),
                                              ),
                                            ),
                                          );
                                          if (result == true) _load();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE8F5E9),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.calendar_month, color: Color(0xFF4CAF50), size: 28),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      subject,
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '$day, $start - $end',
                                                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Kls: $className • R: $roomName',
                                                      style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
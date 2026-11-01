import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/media_url.dart';
import '../../widgets/dashboard_kit.dart';

class JournalMonitorScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;

  const JournalMonitorScreen({
    super.key,
    required this.user,
    this.embedded = false,
  });

  @override
  State<JournalMonitorScreen> createState() => _JournalMonitorScreenState();
}

class _JournalMonitorScreenState extends State<JournalMonitorScreen> {
  final _api = ApiService();
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _journals = [];
  String _selectedClassId = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _load();
  }

  Future<void> _loadClasses() async {
    final result = await _api.get(ApiConfig.classes);
    if (!mounted || result['success'] != true) return;
    setState(() => _classes = asList(result['data']).map(asMap).toList());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = <String, String>{
      'from_date': _date(_range.start),
      'to_date': _date(_range.end),
      if (_selectedClassId.isNotEmpty) 'class_id': _selectedClassId,
    };
    final path = Uri(
      path: ApiConfig.journalMonitor,
      queryParameters: query,
    ).toString();
    final result = await _api.get(path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _journals = asList(result['data']).map(asMap).toList();
      } else {
        _error =
            result['message']?.toString() ?? 'Gagal memuat monitoring jurnal.';
      }
    });
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _selectRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _range,
    );
    if (range == null || !mounted) return;
    setState(() => _range = range);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) {
      return ColoredBox(color: ScpColors.bg, child: body);
    }
    return ScpPage(title: 'Monitoring Jurnal', body: body);
  }

  Widget _body() {
    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
        children: [
          ScpGreeting(
            line: greetingLine(),
            name: widget.user.fullname,
            roleName: widget.user.roleName ?? 'Waka Kurikulum',
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.date_range, color: ScpColors.blue),
                  title: const Text('Rentang tanggal'),
                  subtitle: Text(
                    '${formatShortDate(_date(_range.start))} - '
                    '${formatShortDate(_date(_range.end))}',
                  ),
                  onTap: _selectRange,
                ),
                if (_classes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Kelas',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua kelas'),
                        ),
                        for (final item in _classes)
                          DropdownMenuItem(
                            value: item['id']?.toString() ?? '',
                            child: Text(
                              item['class_name']?.toString() ?? 'Kelas',
                            ),
                          ),
                      ],
                      onChanged: (value) async {
                        setState(() => _selectedClassId = value ?? '');
                        await _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined)
          else if (_journals.isEmpty)
            const ScpEmpty(
              message: 'Belum ada jurnal terkirim pada rentang tanggal ini.',
              icon: Icons.menu_book_outlined,
            )
          else
            for (final journal in _journals) _journalCard(journal),
        ],
      ),
    );
  }

  Widget _journalCard(Map<String, dynamic> journal) {
    final schedule = asMap(journal['schedule']);
    final className = asMap(schedule['class'])['class_name']?.toString() ?? '-';
    final teacher =
        asMap(journal['teacher'])['fullname']?.toString() ??
        journal['teacher_name']?.toString() ??
        'Guru';
    final photoUrl = resolveMedia(journal['photo_path']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule['subject']?.toString() ?? 'Mata Pelajaran',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('$className • $teacher • ${journal['date'] ?? '-'}'),
            const SizedBox(height: 8),
            Text(journal['topic_description']?.toString() ?? '-'),
            if ((journal['activity_notes']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Catatan: ${journal['activity_notes']}'),
              ),
            if (photoUrl != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showMediaPreview(
                    context,
                    photoUrl,
                    title: 'Foto dokumentasi KBM',
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Lihat foto'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

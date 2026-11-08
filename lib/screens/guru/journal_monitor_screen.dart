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
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _singleDate = false;
  Map<String, dynamic> _filterOptions = {};
  List<Map<String, dynamic>> _journals = [];
  String _selectedClassId = '';
  String _selectedGrade = '';
  String _selectedMajor = '';
  String _selectedSection = '';
  String _selectedTeacherId = '';
  bool _loading = true;
  bool _filtersLoading = true;
  String? _error;
  String? _filterError;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  Future<void> _loadFilters() async {
    final result = await _api.get(ApiConfig.attendanceReportFilters);
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _filtersLoading = false;
        _filterError = result['message']?.toString().isNotEmpty == true
            ? result['message'].toString()
            : 'Gagal memuat opsi filter monitoring jurnal.';
      });
      return;
    }
    final data = asMap(result['data']);
    final filters = asMap(data['filters']).isNotEmpty
        ? asMap(data['filters'])
        : data;
    setState(() {
      _filtersLoading = false;
      _filterOptions = filters;
      _filterError = null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!widget.user.canMonitorJournals) {
      setState(() {
        _loading = false;
        _error = 'Role akun ini tidak memiliki akses monitoring jurnal.';
      });
      return;
    }
    final query = <String, String>{
      if (_singleDate)
        'date': _dateString(_date)
      else ...{
        'from_date': _dateString(_range.start),
        'to_date': _dateString(_range.end),
      },
      if (_selectedClassId.isNotEmpty) 'class_id': _selectedClassId,
      if (_selectedGrade.isNotEmpty) 'grade': _selectedGrade,
      if (_selectedMajor.isNotEmpty) 'major': _selectedMajor,
      if (_selectedSection.isNotEmpty) 'section': _selectedSection,
      if (_selectedTeacherId.isNotEmpty) 'teacher_id': _selectedTeacherId,
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

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _selectDates() async {
    if (_singleDate) {
      final selected = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (selected == null || !mounted) return;
      setState(() => _date = selected);
      await _load();
      return;
    }
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

  List<({String id, String name})> _options(List<String> keys) {
    dynamic values;
    for (final key in keys) {
      if (_filterOptions[key] != null) {
        values = _filterOptions[key];
        break;
      }
    }
    if (values is Map && values['data'] is List) values = values['data'];
    if (values is! List) return [];
    final result = <({String id, String name})>[];
    for (final value in values) {
      if (value is String || value is num) {
        result.add((id: '$value', name: '$value'));
        continue;
      }
      final item = asMap(value);
      final id =
          item['id']?.toString() ??
          item['value']?.toString() ??
          item['teacher_id']?.toString() ??
          item['class_id']?.toString() ??
          item['grade']?.toString() ??
          item['major']?.toString() ??
          item['section']?.toString();
      final name =
          item['class_name']?.toString() ??
          item['name']?.toString() ??
          item['label']?.toString() ??
          item['grade']?.toString() ??
          item['major']?.toString() ??
          item['section']?.toString() ??
          item['section_name']?.toString() ??
          item['major_name']?.toString() ??
          item['grade_name']?.toString() ??
          item['teacher_name']?.toString() ??
          item['fullname']?.toString();
      if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
        result.add((id: id, name: name));
      }
    }
    return result;
  }

  List<({String id, String name})> get _gradeOptions =>
      _options(['grades', 'grade'])
          .where((option) => const {'X', 'XI', 'XII'}.contains(option.id))
          .toList();

  Widget _filterDropdown({
    required String label,
    required List<({String id, String name})> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DropdownButtonFormField<String>(
        initialValue: options.any((item) => item.id == selected)
            ? selected
            : '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(value: '', child: Text('Semua $label')),
          for (final item in options)
            DropdownMenuItem(value: item.id, child: Text(item.name)),
        ],
        onChanged: (value) {
          onChanged(value ?? '');
          _load();
        },
      ),
    );
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Rentang')),
                      ButtonSegment(value: true, label: Text('Satu tanggal')),
                    ],
                    selected: {_singleDate},
                    onSelectionChanged: (selection) {
                      setState(() => _singleDate = selection.first);
                      _load();
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range, color: ScpColors.blue),
                  title: Text(_singleDate ? 'Tanggal' : 'Rentang tanggal'),
                  subtitle: Text(
                    _singleDate
                        ? formatShortDate(_dateString(_date))
                        : '${formatShortDate(_dateString(_range.start))} - '
                              '${formatShortDate(_dateString(_range.end))}',
                  ),
                  onTap: _selectDates,
                ),
                if (_filterError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      _filterError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_filtersLoading)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: LinearProgressIndicator(),
                  ),
                _filterDropdown(
                  label: 'Kelas',
                  options: _options(['classes', 'class']),
                  selected: _selectedClassId,
                  onChanged: (value) => _selectedClassId = value,
                ),
                _filterDropdown(
                  label: 'Tingkat',
                  options: _gradeOptions,
                  selected: _selectedGrade,
                  onChanged: (value) => _selectedGrade = value,
                ),
                _filterDropdown(
                  label: 'Jurusan',
                  options: _options(['majors', 'major']),
                  selected: _selectedMajor,
                  onChanged: (value) => _selectedMajor = value,
                ),
                _filterDropdown(
                  label: 'Rombel',
                  options: _options(['sections', 'section']),
                  selected: _selectedSection,
                  onChanged: (value) => _selectedSection = value,
                ),
                _filterDropdown(
                  label: 'Guru',
                  options: _options(['teachers', 'teacher']),
                  selected: _selectedTeacherId,
                  onChanged: (value) => _selectedTeacherId = value,
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
    final className =
        asMap(journal['class'])['class_name']?.toString() ??
        asMap(schedule['class'])['class_name']?.toString() ??
        '-';
    final teacher =
        asMap(journal['teacher'])['fullname']?.toString() ??
        asMap(schedule['teacher'])['fullname']?.toString() ??
        journal['teacher_name']?.toString() ??
        'Guru';
    final subject =
        journal['subject']?.toString() ??
        schedule['subject']?.toString() ??
        'Mata Pelajaran';
    final photoUrl = resolveMedia(journal['photo_path']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
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

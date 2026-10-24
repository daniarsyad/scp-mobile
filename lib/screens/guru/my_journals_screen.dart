import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../utils/media_url.dart';
import 'attendance_screen.dart';

class MyJournalsScreen extends StatefulWidget {
  const MyJournalsScreen({super.key});

  @override
  State<MyJournalsScreen> createState() => _MyJournalsScreenState();
}

class _MyJournalsScreenState extends State<MyJournalsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _journals = [];
  Timer? _timer;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    LiveRefresh.journals.addListener(_onJournalUpdate);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    LiveRefresh.journals.removeListener(_onJournalUpdate);
    super.dispose();
  }

  void _onJournalUpdate() {
    if (mounted) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final result = await _api.get(ApiConfig.myJournals);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        _journals = data is List ? data : (data['data'] ?? []);
      } else {
        _error = result['message'] ?? 'Gagal memuat riwayat jurnal';
      }
    });
  }

  void _openAttendance(Map j) {
    final rawId = j['id'];
    final journalId = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    if (journalId == 0) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          journalId: journalId,
          subject: j['schedule']?['subject']?.toString() ?? '-',
          className: j['schedule']?['class']?['class_name']?.toString() ?? '-',
        ),
      ),
    );
  }

  List<dynamic> _filteredJournals() {
    if (_search.isEmpty) return _journals;
    final q = _search.toLowerCase();
    return _journals.where((j) {
      if (j is! Map) return false;
      final subject = (j['schedule']?['subject'] ?? '').toString().toLowerCase();
      final className = (j['schedule']?['class']?['class_name'] ?? '').toString().toLowerCase();
      final topic = (j['topic_description'] ?? '').toString().toLowerCase();
      return subject.contains(q) || className.contains(q) || topic.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredJournals();

    return Scaffold(
      backgroundColor: ScpColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jurnal Mengajar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ScpColors.text,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          '${_journals.length} entri jurnal tercatat',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ScpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: ScpColors.blue),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _search = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Cari mapel, kelas, atau materi...',
                  hintStyle: const TextStyle(fontSize: 12, color: ScpColors.muted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Journal List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: ScpColors.blue))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_outlined, size: 36, color: ScpColors.red),
                                const SizedBox(height: 8),
                                Text(_error!, style: const TextStyle(color: ScpColors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: ScpColors.surfaceAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_outlined,
                                        size: 36,
                                        color: ScpColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _search.isNotEmpty
                                          ? 'Tidak ada jurnal yang cocok dengan "$_search"'
                                          : 'Belum ada riwayat jurnal mengajar',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: ScpColors.muted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: ScpColors.blue,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final j = filtered[index];
                                  final subject = j['schedule']?['subject'] ?? '-';
                                  final className = j['schedule']?['class']?['class_name'] ?? '-';
                                  final topic = j['topic_description'] ?? 'Tidak ada deskripsi materi';
                                  final date = (j['date'] ?? '').toString();
                                  final dateShort = formatShortDate(date);
                                  final photoUrl = firstMedia(
                                    Map<String, dynamic>.from(j as Map),
                                    photoKeys,
                                  );

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: ScpColors.line),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _openAttendance(j),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Photo / Icon
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: SizedBox(
                                                  width: 54,
                                                  height: 54,
                                                  child: photoUrl == null
                                                      ? Container(
                                                          color: ScpColors.blueLight,
                                                          child: const Icon(
                                                            Icons.menu_book_rounded,
                                                            color: ScpColors.blue,
                                                            size: 26,
                                                          ),
                                                        )
                                                      : Image.network(
                                                          photoUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => Container(
                                                            color: ScpColors.surfaceAlt,
                                                            child: const Icon(
                                                              Icons.broken_image_outlined,
                                                              color: ScpColors.muted,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),

                                              // Content
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      subject,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: ScpColors.text,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: ScpColors.tealCard,
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: ScpColors.tealBorder),
                                                          ),
                                                          child: Text(
                                                            className,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: ScpColors.teal,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          dateShort,
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: ScpColors.muted,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      topic,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: ScpColors.muted,
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              const SizedBox(width: 8),

                                              // Presensi Button Indicator
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: ScpColors.blueLight,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.how_to_reg_rounded, color: ScpColors.blue, size: 18),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Presensi',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: ScpColors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/media_url.dart';
import '../../widgets/dashboard_kit.dart';

class PendingLeavesScreen extends StatefulWidget {
  final String? targetClass;
  final bool isBk;
  final bool embedded;

  const PendingLeavesScreen({
    super.key,
    this.targetClass,
    this.isBk = false,
    this.embedded = false,
  });

  @override
  State<PendingLeavesScreen> createState() => _PendingLeavesScreenState();
}

class _PendingLeavesScreenState extends State<PendingLeavesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _leaves = [];
  String _selectedClassFilter = 'Semua Kelas';

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

    final result = await _api.get(ApiConfig.pendingLeaves);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        _leaves = data is List ? data : (data['data'] ?? []);
      } else {
        _error = result['message'] ?? 'Gagal memuat pengajuan izin';
      }
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

  List<dynamic> _filteredLeaves() {
    final target = widget.targetClass;
    return _leaves.where((item) {
      if (item is! Map) return false;
      final mapItem = Map<String, dynamic>.from(item);
      final cls = _studentClassName(mapItem);

      // 1. Wali Kelas: strictly their own class
      if (!widget.isBk && target != null && target.isNotEmpty) {
        if (!cls.toLowerCase().contains(target.toLowerCase()) &&
            !target.toLowerCase().contains(cls.toLowerCase())) {
          return false;
        }
      }

      // 2. Guru BK: class dropdown filter
      if (widget.isBk && _selectedClassFilter != 'Semua Kelas') {
        if (cls != _selectedClassFilter) return false;
      }

      return true;
    }).toList();
  }

  List<String> _getAvailableClasses() {
    final set = <String>{};
    for (final item in _leaves) {
      if (item is Map) {
        set.add(_studentClassName(Map<String, dynamic>.from(item)));
      }
    }
    return ['Semua Kelas', ...set.toList()..sort()];
  }

  Future<void> _verify(int id, String status, String studentName) async {
    final isApprove = status == 'Approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Setujui Pengajuan Izin?' : 'Tolak Pengajuan Izin?'),
        content: Text(
          isApprove
              ? 'Anda akan menyetujui pengajuan izin untuk siswa $studentName.'
              : 'Apakah Anda yakin ingin menolak pengajuan izin untuk siswa $studentName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isApprove ? ScpColors.green : ScpColors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isApprove ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _api.post('/leave-requests/$id/verify', {
      'status_approval': status,
    });

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Izin berhasil diverifikasi'),
          backgroundColor: isApprove ? ScpColors.green : Colors.grey.shade800,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal memproses verifikasi'),
          backgroundColor: ScpColors.red,
        ),
      );
    }
  }

  void _showDoctorLetter(String imageUrl, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Surat Dokter - $studentName',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Gagal menampilkan gambar surat dokter'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup Preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body();
    if (widget.embedded) {
      return ColoredBox(color: ScpColors.bg, child: body);
    }
    return Scaffold(
      backgroundColor: ScpColors.bg,
      appBar: AppBar(
        title: Text(widget.isBk
            ? 'Verifikasi Izin (Guru BK)'
            : 'Verifikasi Izin ${widget.targetClass ?? ""}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: body,
    );
  }

  Widget _body() {
    final filtered = _filteredLeaves();
    final availableClasses = _getAvailableClasses();

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
        children: [
          // Banner Status
          if (!widget.isBk && widget.targetClass != null && widget.targetClass!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScpColors.tealCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.tealBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ScpColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: ScpColors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verifikasi Izin Kelas ${widget.targetClass}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.teal,
                          ),
                        ),
                        const Text(
                          'Menampilkan antrian pengajuan izin dari siswa kelas bimbingan Anda.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF115E59)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (widget.isBk)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ScpColors.purpleCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ScpColors.purpleBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ScpColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: ScpColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verifikasi Izin Bimbingan Konseling',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ScpColors.purple,
                          ),
                        ),
                        Text(
                          'Guru BK dapat meninjau dan memverifikasi izin siswa dari semua kelas.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // BK Class Filter
          if (widget.isBk && availableClasses.length > 2) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ScpColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, size: 18, color: ScpColors.blue),
                  const SizedBox(width: 10),
                  const Text('Filter Kelas: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClassFilter,
                        isExpanded: true,
                        isDense: true,
                        items: availableClasses.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedClassFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Counter header
          Row(
            children: [
              Text(
                'Antrian Izin Menunggu (${filtered.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ScpColors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: ScpColors.amberCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ScpColors.amberBorder),
                ),
                child: Text(
                  '${filtered.length} Menunggu',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ScpColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: ScpColors.blue)),
            )
          else if (_error != null)
            ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined)
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ScpEmpty(
                message: widget.targetClass != null && widget.targetClass!.isNotEmpty
                    ? 'Tidak ada pengajuan izin yang menunggu verifikasi untuk kelas ${widget.targetClass}'
                    : 'Tidak ada pengajuan izin yang menunggu verifikasi',
                icon: Icons.check_circle_outline_rounded,
              ),
            )
          else
            for (final item in filtered) _leaveCard(Map<String, dynamic>.from(item as Map)),
        ],
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}') ?? 0;
    final student = asMap(item['student']);
    final studentName = student['fullname']?.toString() ?? 'Siswa';
    final className = _studentClassName(item);
    final reason = item['reason']?.toString() ?? '-';
    final start = (item['start_date'] ?? '').toString();
    final end = (item['end_date'] ?? '').toString();
    final startShort = formatShortDate(start);
    final endShort = formatShortDate(end);

    // Doctor letter check
    final suratUrl = firstMedia(item, suratKeys);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScpColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ScpColors.blueLight,
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: ScpColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ScpColors.text,
                        ),
                      ),
                      Text(
                        className,
                        style: const TextStyle(
                          color: ScpColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ScpColors.amberCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ScpColors.amberBorder),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: ScpColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ScpColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: ScpColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        '$startShort  s/d  $endShort',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ScpColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: ScpColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alasan: $reason',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ScpColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (suratUrl != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showDoctorLetter(suratUrl, studentName),
                icon: const Icon(Icons.attachment_rounded, size: 16),
                label: const Text('Lihat Surat Dokter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ScpColors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _verify(id, 'Rejected', studentName),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ScpColors.red,
                      side: const BorderSide(color: ScpColors.red, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _verify(id, 'Approved', studentName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ScpColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
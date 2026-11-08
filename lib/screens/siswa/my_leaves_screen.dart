import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/live_refresh.dart';
import '../../utils/media_url.dart';
import '../ortu/create_leave_ortu_screen.dart';
import 'create_leave_screen.dart';

class MyLeavesScreen extends StatefulWidget {
  final UserModel? user;
  final Map<String, dynamic>? selectedChild;

  const MyLeavesScreen({
    super.key,
    this.user,
    this.selectedChild,
  });

  @override
  State<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends State<MyLeavesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _leaves = [];

  final Color primaryColor = const Color(0xFF5B67CA);
  final Color bgColor = const Color(0xFFF8F9FE);

  @override
  void initState() {
    super.initState();
    LiveRefresh.leaves.addListener(_onRefreshSignal);
    _load();
  }

  @override
  void dispose() {
    LiveRefresh.leaves.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) _load();
  }

  List<dynamic> get _filteredLeaves {
    final childId = int.tryParse('${widget.selectedChild?['id'] ?? ''}');
    if (widget.user?.isOrangTua == true && childId != null && childId > 0) {
      return _leaves.where((raw) {
        if (raw is! Map) return false;
        final itemStudentId = int.tryParse(
          '${raw['student_id'] ?? (raw['student'] is Map ? raw['student']['id'] : '')}',
        );
        return itemStudentId == null || itemStudentId == childId;
      }).toList();
    }
    return _leaves;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.get(ApiConfig.myLeaveRequests);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];
        _leaves = data is List ? data : (data['data'] ?? []);
      } else {
        _error = result['message'] ?? 'Gagal memuat data izin';
      }
    });
  }

  Future<void> _createLeave() async {
    final childId = int.tryParse('${widget.selectedChild?['id'] ?? ''}');
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => (widget.user?.isOrangTua == true)
            ? CreateLeaveOrtuScreen(initialStudentId: childId)
            : const CreateLeaveScreen(),
      ),
    );
    if (ok == true) {
      LiveRefresh.pingLeaves();
      await _load();
    }
  }

  Future<void> _cancel(Map item) async {
    final id = int.tryParse('${item['id']}');
    if (id == null || id <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan izin?'),
        content: const Text(
          'Pengajuan yang dibatalkan tidak dapat diproses lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _api.post(ApiConfig.cancelLeave(id), {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Pengajuan berhasil dibatalkan.'
              : result['message']?.toString() ?? 'Gagal membatalkan pengajuan.',
        ),
      ),
    );
    if (result['success'] == true) {
      LiveRefresh.pingLeaves();
      await _load();
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return Colors.green;
      case 'rejected':
      case 'ditolak':
        return Colors.red;
      case 'cancelled':
      case 'canceled':
      case 'dibatalkan':
        return Colors.grey.shade600;
      default:
        return Colors.orange;
    }
  }

  bool _isCancelled(Map item) {
    final raw = item['cancelled_at'];
    return raw != null &&
        raw.toString().trim().isNotEmpty &&
        raw.toString() != 'null';
  }

  String _statusLabel(Map item) {
    if (_isCancelled(item)) return 'Dibatalkan';
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending')
        .toString();
    switch (status.toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return 'Disetujui';
      case 'rejected':
      case 'ditolak':
        return 'Ditolak';
      case 'cancelled':
      case 'canceled':
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return 'Menunggu';
    }
  }

  bool _canCancel(Map item) {
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending')
        .toString()
        .toLowerCase();
    return !_isCancelled(item) && status == 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLeave,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajukan Izin'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Izin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.refresh, color: primaryColor),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 56,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredLeaves.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.post_add_rounded,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada pengajuan izin',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.user?.isOrangTua == true
                                  ? 'Klik tombol di bawah untuk membuat pengajuan izin untuk anak Anda.'
                                  : 'Klik tombol di bawah untuk membuat pengajuan izin baru.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _createLeave,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Ajukan Izin Sekarang'),
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        itemCount: _filteredLeaves.length,
                        itemBuilder: (context, index) {
                          final item = _filteredLeaves[index] as Map;
                          final status = _statusLabel(item);
                          final reason = item['reason']?.toString() ?? '-';
                          final leaveType =
                              item['leave_type']?.toString() ?? 'Izin';
                          final start = (item['start_date'] ?? '').toString();
                          final end = (item['end_date'] ?? '').toString();
                          final startShort = start.length >= 10
                              ? start.substring(0, 10)
                              : start;
                          final endShort = end.length >= 10
                              ? end.substring(0, 10)
                              : end;
                          final rejectionReason = item['rejection_reason']
                              ?.toString();

                          final student = item['student'] is Map
                              ? item['student'] as Map
                              : null;
                          final studentName = student?['fullname']?.toString();
                          final studentClass = student?['class'] is Map
                              ? student!['class']['class_name']?.toString()
                              : student?['class_name']?.toString();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$startShort s/d $endShort',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (studentName != null &&
                                      studentName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 14,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Siswa: $studentName${studentClass != null && studentClass.isNotEmpty ? ' ($studentClass)' : ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text('Jenis: $leaveType'),
                                  Text(reason),
                                  Builder(
                                    builder: (ctx) {
                                      final docUrl = firstMedia(item, suratKeys);
                                      if (docUrl == null) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: OutlinedButton.icon(
                                          onPressed: () => showMediaPreview(
                                            ctx,
                                            docUrl,
                                            title: 'Lampiran Surat ($leaveType)',
                                          ),
                                          icon: const Icon(Icons.attachment_rounded, size: 16),
                                          label: const Text('Lihat Lampiran Surat'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryColor,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (rejectionReason != null &&
                                      rejectionReason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Alasan penolakan: $rejectionReason',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  if (item['verified_by'] != null &&
                                      (item['verified_by'] is Map ||
                                          item['verified_by_user'] is Map)) ...[
                                    Builder(
                                      builder: (_) {
                                        final v = item['verified_by'] is Map
                                            ? item['verified_by'] as Map
                                            : (item['verified_by_user'] as Map? ?? {});
                                        final vName = v['fullname']?.toString() ?? '';
                                        final vRole = (v['role'] is Map ? v['role']['role_name'] : null)?.toString() ?? 'Guru';
                                        if (vName.isEmpty) return const SizedBox();
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.verified_user_rounded,
                                                size: 14,
                                                color: _statusColor(status),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Diverifikasi: $vName ($vRole)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  if (_canCancel(item))
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _cancel(item),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Batalkan pengajuan'),
                                      ),
                                    ),
                                ],
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

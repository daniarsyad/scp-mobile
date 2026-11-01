import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/live_refresh.dart';

class MyLeavesScreen extends StatefulWidget {
  const MyLeavesScreen({super.key});

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
    _load();
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
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(Map item) {
    if (item['cancelled_at'] != null) return 'Dibatalkan';
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending')
        .toString();
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  bool _canCancel(Map item) {
    final status = (item['status_approval'] ?? item['status'] ?? 'Pending')
        .toString()
        .toLowerCase();
    return item['cancelled_at'] == null && status == 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
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
                  IconButton(
                    icon: Icon(Icons.refresh, color: primaryColor),
                    onPressed: _load,
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
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _leaves.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada pengajuan izin',
                        style: TextStyle(color: Colors.grey),
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
                        itemCount: _leaves.length,
                        itemBuilder: (context, index) {
                          final item = _leaves[index] as Map;
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
                                  const SizedBox(height: 6),
                                  Text('Jenis: $leaveType'),
                                  Text(reason),
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

import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
  
  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
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
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _leaves.isEmpty
                          ? const Center(child: Text('Belum ada pengajuan izin', style: TextStyle(color: Colors.grey)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: primaryColor,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                itemCount: _leaves.length,
                                itemBuilder: (context, index) {
                                  final item = _leaves[index];
                                  final status = (item['status_approval'] ?? item['status'] ?? 'Pending').toString();
                                  final reason = item['reason'] ?? '-';
                                  final start = (item['start_date'] ?? '').toString();
                                  final end = (item['end_date'] ?? '').toString();
                                  final startShort = start.length >= 10 ? start.substring(0, 10) : start;
                                  final endShort = end.length >= 10 ? end.substring(0, 10) : end;

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
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3E5F5),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.list_alt, color: Color(0xFF9C27B0), size: 28),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$startShort s/d $endShort',
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  reason,
                                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_statusIcon(status), color: _statusColor(status), size: 24),
                                              const SizedBox(height: 4),
                                              Text(
                                                status,
                                                style: TextStyle(
                                                  color: _statusColor(status),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          )
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
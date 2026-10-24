import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../widgets/dashboard_kit.dart';
import '../schedules/role_schedule_screen.dart';

class ChildrenTab extends StatefulWidget {
  final UserModel user;

  const ChildrenTab({super.key, required this.user});

  @override
  State<ChildrenTab> createState() => _ChildrenTabState();
}

class _ChildrenTabState extends State<ChildrenTab> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = [];

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
    final result = await _api.get(ApiConfig.children);
    if (!mounted) return;
    if (result['success'] == true) {
      final rows = <Map<String, dynamic>>[];
      for (final item in asList(result['data'])) {
        rows.add(asMap(item));
      }
      setState(() {
        _loading = false;
        _children = rows;
      });
    } else {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Gagal memuat data anak';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ScpColors.blue),
      );
    }
    if (_error != null) {
      return ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined);
    }
    if (_children.isEmpty) {
      return const ScpEmpty(
        message: 'Belum ada data anak',
        icon: Icons.family_restroom_outlined,
      );
    }

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          final name = child['fullname']?.toString() ?? '-';
          final className =
              child['class']?['class_name']?.toString() ??
              child['class_name']?.toString() ??
              'Kelas belum diisi';
          final gradient = index.isEven
              ? ScpColors.tealGradient
              : ScpColors.navyGradient;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  className,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Akun siswa',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  child['username']?.toString() ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleScheduleScreen(
                            user: widget.user,
                            child: child,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Lihat Jadwal Hari Ini & Putaran 1–2'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/scp_theme.dart';
import '../../utils/format.dart';
import '../../utils/live_refresh.dart';
import '../../widgets/dashboard_kit.dart';

class LeaveRecapTab extends StatefulWidget {
  const LeaveRecapTab({super.key});

  @override
  State<LeaveRecapTab> createState() => _LeaveRecapTabState();
}

class _LeaveRecapTabState extends State<LeaveRecapTab> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _leaves = [];

  @override
  void initState() {
    super.initState();
    LiveRefresh.leaves.addListener(_onPing);
    _load();
  }

  @override
  void dispose() {
    LiveRefresh.leaves.removeListener(_onPing);
    super.dispose();
  }

  void _onPing() {
    if (mounted) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await _api.get(ApiConfig.pendingLeaves);
    if (!mounted) return;

    final rows = <Map<String, dynamic>>[];
    if (result['success'] == true) {
      for (final item in asList(result['data'])) {
        rows.add(asMap(item));
      }
      setState(() {
        _loading = false;
        _leaves = rows;
        _error = null;
      });
    } else if (!silent) {
      setState(() {
        _loading = false;
        _error = result['message']?.toString() ?? 'Gagal memuat rekap';
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _classOf(Map<String, dynamic> item) {
    final student = item['student'];
    if (student is Map) {
      final direct = student['class_name'] ?? student['class'];
      if (direct is String && direct.isNotEmpty) return direct;
      if (direct is Map) {
        final name = direct['class_name']?.toString();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return 'Tanpa kelas';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ScpColors.blue));
    }
    if (_error != null) {
      return ScpEmpty(message: _error!, icon: Icons.cloud_off_outlined);
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _leaves) {
      grouped.putIfAbsent(_classOf(item), () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort();

    return RefreshIndicator(
      color: ScpColors.blue,
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (keys.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: ScpEmpty(message: 'Belum ada izin untuk direkap'),
            )
          else
            for (var g = 0; g < keys.length; g++) ...[
              if (g > 0) const SizedBox(height: 8),
              Text(
                keys[g],
                style: const TextStyle(
                  color: ScpColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < grouped[keys[g]]!.length; i++)
                _tile(grouped[keys[g]]![i], i),
            ],
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item, int index) {
    final palette = activityPalette[index % activityPalette.length];
    final student = item['student']?['fullname']?.toString() ?? '-';
    final reason = item['reason']?.toString() ?? '-';
    final start = formatShortDate((item['start_date'] ?? '').toString());
    final end = formatShortDate((item['end_date'] ?? '').toString());
    return ScpCategoryTile(
      icon: palette.icon,
      iconBg: palette.bg,
      iconColor: palette.fg,
      title: student,
      subtitle: '$reason  •  $start - $end',
      progress: 0.35,
      progressColor: palette.fg,
    );
  }
}

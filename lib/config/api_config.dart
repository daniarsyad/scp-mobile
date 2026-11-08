import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // ===========================================================================
  // KONFIGURASI BASE URL API
  // ===========================================================================
  // Pilih salah satu mode di bawah ini sesuai lingkungan pengujian:
  // - Mode Hosting: 'https://nama-domain-anda.com/api'
  // - Mode Emulator Android: 'http://10.0.2.2:8000/api'
  // - Mode HP Fisik (Wi-Fi Laptop): 'http://192.168.x.x:8000/api'
  // - Mode Web / Localhost: 'http://127.0.0.1:8000/api'
  
  static const String _defaultUrl = 'http://127.0.0.1:8000/api'; // Mode Lokal / Web

  static String? _customUrl;

  static String get baseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty) {
      return _customUrl!;
    }
    return const String.fromEnvironment(
      'SCP_API_BASE_URL',
      defaultValue: _defaultUrl,
    );
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_api_url');
      if (saved != null && saved.trim().isNotEmpty) {
        _customUrl = _cleanUrl(saved.trim());
      }
    } catch (_) {}
  }

  static Future<void> setCustomUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      _customUrl = null;
      await prefs.remove('custom_api_url');
    } else {
      final cleaned = _cleanUrl(url.trim());
      _customUrl = cleaned;
      await prefs.setString('custom_api_url', cleaned);
    }
  }

  static String _cleanUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) {
      url = '$url/api';
    }
    return url;
  }

  static Uri buildUri(String path) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    return Uri.parse('$base$cleanPath');
  }

  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String profile = '/profile';
  static const String register = '/register';
  static const String classes = '/classes';
  static const String roles = '/roles';
  static const String children = '/children';

  // Lupa password (OTP 3 langkah)
  static const String forgotRequest = '/forgot-password/request';
  static const String forgotVerify = '/forgot-password/verify-otp';
  static const String forgotReset = '/forgot-password/reset';

  static const String systemConfig = '/system/config';
  static const String schedules = '/schedules';
  static const String mySchedules = '/schedules/my';
  static const String schedulesToday = '/schedules/today';


  static const String journals = '/journals';
  static const String myJournals = '/journals/my';
  static const String journalMonitor = '/journals/monitor';
  static const String dashboardToday = '/dashboard/today';

  static const String leaveRequests = '/leave-requests';
  static const String myLeaveRequests = '/leave-requests/my';
  static const String pendingLeaves = '/leave-requests/pending';
  static String cancelLeave(int id) => '/leave-requests/$id/cancel';

  static const String attendanceByJournal = '/attendances/journal';
  static const String attendanceReport = '/attendances/report';
  static const String attendanceReportFilters = '/attendances/report/filters';
  static const String attendanceUpdate = '/attendances';
  static const String myAttendances = '/attendances/my';
}

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'SCP_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
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

  static const String leaveRequests = '/leave-requests';
  static const String myLeaveRequests = '/leave-requests/my';
  static const String pendingLeaves = '/leave-requests/pending';

  static const String attendanceByJournal = '/attendances/journal';
  static const String attendanceReport = '/attendances/report';
  static const String attendanceUpdate = '/attendances';
  static const String myAttendances = '/attendances/my';
}

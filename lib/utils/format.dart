const monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const dayNames = [
  '',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String greetingLine() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

String todayLabel() {
  final now = DateTime.now();
  return '${now.day.toString().padLeft(2, '0')} ${monthShort[now.month - 1]}';
}

String todayIso() => DateTime.now().toIso8601String().substring(0, 10);

String todayDayName() => dayNames[DateTime.now().weekday];

String formatShortDate(String raw) {
  final value = raw.length >= 10 ? raw.substring(0, 10) : raw;
  final parts = value.split('-');
  if (parts.length != 3) return value.isEmpty ? '-' : value;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) return value;
  return '${day.toString().padLeft(2, '0')} ${monthShort[month - 1]}';
}

String formatTime(dynamic value) {
  final text = (value ?? '').toString();
  if (text.length >= 5 && text[2] == ':') return text.substring(0, 5);
  return text.isEmpty ? '-' : text;
}

int asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

List<dynamic> asList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return const [];
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

bool journalFilledToday(Map schedule) {
  final journals = schedule['journals'];
  if (journals is! List || journals.isEmpty) return false;
  final today = todayIso();
  for (final item in journals) {
    if (item is! Map) continue;
    final dateStr = (item['date'] ?? '').toString();
    final createdStr = (item['created_at'] ?? '').toString();
    if (dateStr.startsWith(today) || createdStr.startsWith(today)) {
      return true;
    }
    try {
      final parsed = DateTime.tryParse(dateStr)?.toLocal();
      if (parsed != null &&
          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' == today) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

Map<String, dynamic>? journalForToday(Map schedule) {
  final journals = schedule['journals'];
  if (journals is! List || journals.isEmpty) return null;
  final today = todayIso();
  for (final item in journals) {
    if (item is! Map) continue;
    final dateStr = (item['date'] ?? '').toString();
    final createdStr = (item['created_at'] ?? '').toString();
    if (dateStr.startsWith(today) || createdStr.startsWith(today)) {
      return Map<String, dynamic>.from(item);
    }
    try {
      final parsed = DateTime.tryParse(dateStr)?.toLocal();
      if (parsed != null &&
          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' == today) {
        return Map<String, dynamic>.from(item);
      }
    } catch (_) {}
  }
  return null;
}

int journalTotal(Map schedule) {
  final journals = schedule['journals'];
  if (journals is List) return journals.length;
  return 0;
}
int? _minutesOfDay(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == '-') return null;
  final parts = text.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// True jika jam mulai jadwal belum tiba (jadwal belum boleh dilihat/diisi).
/// Mengambil start_time langsung atau dari objek period.
bool scheduleNotStarted(Map schedule, [DateTime? now]) {
  final dynamic rawStart = schedule['start_time'] ??
      (schedule['period'] is Map ? schedule['period']['start_time'] : null);
  final start = _minutesOfDay(rawStart);
  if (start == null) return false;
  final current = now ?? DateTime.now();
  return (current.hour * 60 + current.minute) < start;
}

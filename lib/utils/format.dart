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
  if (journals is! List) return false;
  final today = todayIso();
  for (final item in journals) {
    if (item is Map && (item['date'] ?? '').toString().startsWith(today)) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic>? journalForToday(Map schedule) {
  final journals = schedule['journals'];
  if (journals is! List) return null;
  final today = todayIso();
  for (final item in journals) {
    if (item is Map && (item['date'] ?? '').toString().startsWith(today)) {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

int journalTotal(Map schedule) {
  final journals = schedule['journals'];
  if (journals is List) return journals.length;
  return 0;
}

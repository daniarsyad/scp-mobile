import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class JournalDraft {
  const JournalDraft({
    required this.ownerId,
    required this.scheduleId,
    required this.date,
    required this.idempotencyKey,
    required this.topic,
    required this.activityNotes,
    required this.attendances,
    this.submissionAttempted = false,
    this.submissionUncertain = false,
    this.photoBase64,
    this.photoName,
    this.photoContentType,
  });

  final int ownerId;
  final int scheduleId;
  final String date;
  final String idempotencyKey;
  final String topic;
  final String activityNotes;
  final List<Map<String, dynamic>> attendances;
  final bool submissionAttempted;
  final bool submissionUncertain;
  final String? photoBase64;
  final String? photoName;
  final String? photoContentType;

  List<int>? get photoBytes =>
      photoBase64 == null ? null : base64Decode(photoBase64!);

  JournalDraft copyWith({
    String? idempotencyKey,
    String? topic,
    String? activityNotes,
    List<Map<String, dynamic>>? attendances,
    bool? submissionAttempted,
    bool? submissionUncertain,
    String? photoBase64,
    String? photoName,
    String? photoContentType,
    bool removePhoto = false,
  }) {
    return JournalDraft(
      ownerId: ownerId,
      scheduleId: scheduleId,
      date: date,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      topic: topic ?? this.topic,
      activityNotes: activityNotes ?? this.activityNotes,
      attendances: attendances ?? this.attendances,
      submissionAttempted: submissionAttempted ?? this.submissionAttempted,
      submissionUncertain: submissionUncertain ?? this.submissionUncertain,
      photoBase64: removePhoto ? null : photoBase64 ?? this.photoBase64,
      photoName: removePhoto ? null : photoName ?? this.photoName,
      photoContentType: removePhoto
          ? null
          : photoContentType ?? this.photoContentType,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner_id': ownerId,
    'schedule_id': scheduleId,
    'date': date,
    'idempotency_key': idempotencyKey,
    'topic_description': topic,
    'activity_notes': activityNotes,
    'attendances': attendances,
    'submission_attempted': submissionAttempted,
    'submission_uncertain': submissionUncertain,
    'photo_base64': photoBase64,
    'photo_name': photoName,
    'photo_content_type': photoContentType,
  };

  factory JournalDraft.fromJson(Map<String, dynamic> json) {
    final attendances = json['attendances'];
    if (attendances is! List) {
      throw const FormatException('Data presensi draf tidak valid.');
    }
    return JournalDraft(
      ownerId: _readInt(json['owner_id']),
      scheduleId: _readInt(json['schedule_id']),
      date: json['date']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      topic: json['topic_description']?.toString() ?? '',
      activityNotes: json['activity_notes']?.toString() ?? '',
      attendances: attendances.map((item) {
        if (item is! Map) {
          throw const FormatException('Baris presensi draf tidak valid.');
        }
        return Map<String, dynamic>.from(item);
      }).toList(),
      submissionAttempted: json['submission_attempted'] == true,
      submissionUncertain: json['submission_uncertain'] == true,
      photoBase64: json['photo_base64']?.toString(),
      photoName: json['photo_name']?.toString(),
      photoContentType: json['photo_content_type']?.toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}

class JournalDraftStore {
  static const _prefix = 'journal_draft_';

  String keyFor(int ownerId, int scheduleId, String date) =>
      '$_prefix${ownerId}_${scheduleId}_$date';

  String newIdempotencyKey() {
    final randomPart = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'scp-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  Future<JournalDraft?> load(int ownerId, int scheduleId, String date) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(keyFor(ownerId, scheduleId, date));
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Format draf jurnal tidak valid.');
    }
    return JournalDraft.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(JournalDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      keyFor(draft.ownerId, draft.scheduleId, draft.date),
      jsonEncode(draft.toJson()),
    );
    if (!saved) throw StateError('Draf jurnal tidak dapat disimpan.');
  }

  Future<void> delete(int ownerId, int scheduleId, String date) async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(keyFor(ownerId, scheduleId, date));
    if (!removed) {
      throw StateError('Draf jurnal tidak dapat dihapus setelah tersimpan.');
    }
  }

  Future<List<JournalDraft>> loadAll({int? ownerId}) async {
    final preferences = await SharedPreferences.getInstance();
    final drafts = <JournalDraft>[];
    final keyPrefix = ownerId == null ? _prefix : '$_prefix${ownerId}_';
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(keyPrefix),
    )) {
      final value = preferences.getString(key);
      if (value == null) continue;
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw FormatException('Format draf jurnal tidak valid: $key');
      }
      drafts.add(JournalDraft.fromJson(Map<String, dynamic>.from(decoded)));
    }
    return drafts;
  }
}

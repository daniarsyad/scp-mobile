import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scp_mobile/screens/guru/create_journal_screen.dart';
import 'package:scp_mobile/services/api_service.dart';
import 'package:scp_mobile/services/journal_draft_store.dart';
import 'package:scp_mobile/utils/format.dart';

void main() {
  final photoBytes = MockClient.pngResponse().bodyBytes;

  const schedule = {
    'id': 23,
    'subject': 'Matematika',
    'class': {
      'class_name': 'XII RPL 2',
      'students': [
        {'id': 100, 'fullname': 'Siswa Contoh', 'nisn': '00100'},
      ],
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('keeps the draft local until submitting a full journal', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/journals')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 81, 'attendances': []},
          }),
          201,
        );
      }
      if (request.url.path.endsWith('/attendances/journal/81')) {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      }
      return http.Response('Unexpected request', 500);
    });
    final store = JournalDraftStore();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateJournalScreen(
          schedule: schedule,
          ownerId: 7,
          api: ApiService(client: client),
          draftStore: store,
          pickImage: (_) async => XFile.fromData(
            photoBytes,
            mimeType: 'image/png',
            name: 'lesson.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    var draft = await store.load(7, 23, todayIso());
    expect(draft, isNotNull);
    expect(draft!.attendances.single['status'], 'Hadir');

    await tester.enterText(
      find.byKey(const ValueKey('journal-topic')),
      'Persamaan kuadrat',
    );
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Siswa Contoh'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sakit').last);
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    draft = await store.load(7, 23, todayIso());
    expect(draft!.attendances.single['status'], 'Sakit');
    expect(draft.topic, 'Persamaan kuadrat');
    expect(draft.photoBytes, photoBytes);

    await tester.scrollUntilVisible(
      find.text('Selesai & Simpan Jurnal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Selesai & Simpan Jurnal'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    final submit = requests.first;
    final submitBody = utf8.decode(submit.bodyBytes, allowMalformed: true);
    expect(submit.method, 'POST');
    expect(submit.url.path, endsWith('/journals'));
    expect(submit.headers['idempotency-key'], isNotEmpty);
    expect(submit.headers['content-type'], contains('multipart/form-data'));
    expect(submitBody, contains('attendances[0][student_id]'));
    expect(submitBody, contains('attendances[0][status]'));
    expect(submitBody, contains('Sakit'));
    expect(submitBody, contains('Persamaan kuadrat'));
    expect(_containsBytes(submit.bodyBytes, photoBytes), isTrue);
    expect(await store.load(7, 23, todayIso()), isNull);
  });

  testWidgets('retries uncertain submission using the same key and payload', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var submitCount = 0;
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/journals')) {
        submitCount++;
        if (submitCount == 1) {
          return http.Response(
            jsonEncode({'message': 'Status sesi belum dapat dipastikan'}),
            409,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'replayed': true,
            'data': {'id': 82, 'attendances': []},
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': []}), 200);
    });
    final store = JournalDraftStore();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateJournalScreen(
          schedule: schedule,
          ownerId: 7,
          api: ApiService(client: client),
          draftStore: store,
          pickImage: (_) async => XFile.fromData(
            photoBytes,
            mimeType: 'image/png',
            name: 'lesson.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-topic')),
      'Materi yang sama',
    );
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Selesai & Simpan Jurnal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Selesai & Simpan Jurnal'));
    await tester.pumpAndSettle();

    final persisted = await store.load(7, 23, todayIso());
    expect(persisted, isNotNull);
    expect(persisted!.submissionUncertain, isTrue);
    final key = requests.first.headers['idempotency-key'];
    final firstPayload = utf8.decode(
      requests.first.bodyBytes,
      allowMalformed: true,
    );
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(requests[1].headers['idempotency-key'], key);
    expect(
      utf8.decode(requests[1].bodyBytes, allowMalformed: true),
      contains('Materi yang sama'),
    );
    expect(_containsBytes(requests[1].bodyBytes, photoBytes), isTrue);
    expect(firstPayload, contains('Materi yang sama'));
    expect(await store.load(7, 23, todayIso()), isNull);
  });

  testWidgets('keeps draft after validation errors', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/journals')) {
        return http.Response(
          jsonEncode({
            'message': 'Data tidak valid',
            'errors': {
              'topic_description': ['Topik wajib diisi'],
            },
          }),
          422,
        );
      }
      return http.Response('Unexpected request', 500);
    });
    final store = JournalDraftStore();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateJournalScreen(
          schedule: schedule,
          ownerId: 7,
          api: ApiService(client: client),
          draftStore: store,
          pickImage: (_) async => XFile.fromData(
            photoBytes,
            mimeType: 'image/png',
            name: 'lesson.png',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-topic')),
      'Topik valid',
    );
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    final originalKey = (await store.load(7, 23, todayIso()))!.idempotencyKey;

    await tester.scrollUntilVisible(
      find.text('Selesai & Simpan Jurnal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Selesai & Simpan Jurnal'));
    await tester.pumpAndSettle();

    final afterFailure = await store.load(7, 23, todayIso());
    expect(afterFailure, isNotNull);
    expect(afterFailure!.submissionUncertain, isFalse);
    expect(afterFailure.photoBytes, photoBytes);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-topic')),
      'Topik diperbaiki',
    );
    await tester.pumpAndSettle();
    final editedDraft = await store.load(7, 23, todayIso());
    expect(editedDraft!.idempotencyKey, isNot(originalKey));
    expect(editedDraft.topic, 'Topik diperbaiki');
  });
}

bool _containsBytes(List<int> source, List<int> target) {
  for (var start = 0; start <= source.length - target.length; start++) {
    var match = true;
    for (var offset = 0; offset < target.length; offset++) {
      if (source[start + offset] != target[offset]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

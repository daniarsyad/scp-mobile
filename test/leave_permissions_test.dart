import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scp_mobile/screens/bk/pending_leaves_screen.dart';
import 'package:scp_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pendingRequest = {
    'id': 42,
    'leave_type': 'Sakit',
    'reason': 'Demam',
    'start_date': '2026-10-30',
    'end_date': '2026-10-30',
    'student': {
      'fullname': 'Siswa Contoh',
      'class': {'class_name': 'XII RPL 2'},
    },
  };

  testWidgets('Guru BK can monitor pending leave but cannot verify it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [pendingRequest],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: PendingLeavesScreen(isBk: true, api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Siswa Contoh'), findsOneWidget);
    expect(find.textContaining('XII RPL 2 • Sakit'), findsOneWidget);
    expect(find.text('Tolak'), findsNothing);
    expect(find.text('Setujui'), findsNothing);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
  });

  testWidgets('Wali Kelas must enter a rejection reason', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 42},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [pendingRequest],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PendingLeavesScreen(targetClass: 'XII RPL 2', api: api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan harus 3–500 karakter.'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextField), 'Tidak ada surat pendukung');
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();

    final verifyRequest = requests.singleWhere(
      (request) => request.method == 'POST',
    );
    expect(jsonDecode(verifyRequest.body), {
      'status_approval': 'Rejected',
      'rejection_reason': 'Tidak ada surat pendukung',
    });
  });
}

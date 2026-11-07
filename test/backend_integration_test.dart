import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scp_mobile/models/user_model.dart';
import 'package:scp_mobile/services/api_service.dart';
import 'package:scp_mobile/services/auth_service.dart';
import 'package:scp_mobile/screens/dashboard/attendance_history_screen.dart';
import 'package:scp_mobile/screens/dashboard/siswa_home_tab.dart';
import 'package:scp_mobile/screens/schedules/role_schedule_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parses additional roles without replacing the primary mobile role', () {
    final user = UserModel.fromJson({
      'id': 30,
      'username': 'guru-waka',
      'fullname': 'Guru dengan akses Waka',
      'role': 'Guru',
      'additional_roles': [
        {'role_name': 'Waka Kurikulum'},
      ],
    });

    expect(user.roleName, 'Guru');
    expect(user.isGuru, isTrue);
    expect(user.hasAdditionalRole('Waka Kurikulum'), isTrue);
    expect(user.isWaka, isFalse);
    expect(user.canMonitorJournals, isFalse);
  });

  test('parses multiple BK class assignments when supplied by the API', () {
    final user = UserModel.fromJson({
      'id': 31,
      'username': 'guru-bk',
      'fullname': 'Guru BK',
      'role': {'role_name': 'Guru BK'},
      'bk_classes': [
        {'id': 5, 'class_name': 'X RPL 1'},
        {'id': 6, 'class_name': 'X RPL 2'},
      ],
    });

    expect(user.isGuruBK, isTrue);
    expect(user.bkClasses, hasLength(2));
    expect(user.bkClasses.map((schoolClass) => schoolClass['class_name']), [
      'X RPL 1',
      'X RPL 2',
    ]);
  });

  test(
    'login sends identifier and legacy username without saving password',
    () async {
      late http.Request received;
      final service = AuthService(
        client: MockClient((request) async {
          received = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'token': 'sanctum-token',
                'user': {
                  'id': 12,
                  'username': 'parent',
                  'fullname': 'Orang Tua',
                  'role': 'Orang Tua',
                  'children': [
                    {'id': 44, 'fullname': 'Siswa Backend'},
                  ],
                },
              },
            }),
            200,
          );
        }),
      );

      final result = await service.login('2024001', 'password-orang-tua');
      final body = jsonDecode(received.body) as Map<String, dynamic>;
      final preferences = await SharedPreferences.getInstance();

      expect(received.method, 'POST');
      expect(received.url.path, endsWith('/api/login'));
      expect(body['identifier'], '2024001');
      expect(body['username'], '2024001');
      expect(body['password'], 'password-orang-tua');
      expect(result['success'], isTrue);
      expect(preferences.getString('token'), 'sanctum-token');
      expect(preferences.getKeys(), isNot(contains('password')));
      final user = result['user'] as UserModel;
      expect(user.isOrangTua, isTrue);
      expect(user.children.single['id'], 44);
    },
  );

  test(
    'GET attaches Bearer token and preserves dashboard student filter',
    () async {
      late http.Request received;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('token', 'token-123');
      final service = ApiService(
        client: MockClient((request) async {
          received = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'schedules': []},
            }),
            200,
          );
        }),
      );

      final result = await service.get('/dashboard/today?student_id=44');

      expect(result['success'], isTrue);
      expect(received.url.path, endsWith('/api/dashboard/today'));
      expect(received.url.queryParameters, {'student_id': '44'});
      expect(received.headers['authorization'], 'Bearer token-123');
    },
  );

  test('login surfaces validation messages returned by Laravel', () async {
    final service = AuthService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'identifier': ['NIS/NIP/username atau password salah.'],
            },
          }),
          422,
        );
      }),
    );

    final result = await service.login('invalid', 'bad');

    expect(result['success'], isFalse);
    expect(result['statusCode'], 422);
    expect(
      result['message'],
      contains('NIS/NIP/username atau password salah.'),
    );
  });

  test('multipart response retains validation status and errors', () async {
    late http.Request received;
    final service = ApiService(
      client: MockClient((request) async {
        received = request;
        return http.Response(
          jsonEncode({
            'message': 'Data tidak valid',
            'errors': {
              'attendances.0.status': ['Status tidak valid'],
            },
          }),
          422,
        );
      }),
    );

    final result = await service.postMultipart(
      path: '/journals',
      fields: {'attendances[0][status]': 'Alpha'},
      fileBytes: [1, 2, 3],
      fileField: 'photo',
      filename: 'journal.png',
      contentType: 'image/png',
      idempotencyKey: 'same-key',
    );

    expect(received.method, 'POST');
    expect(received.url.path, endsWith('/api/journals'));
    expect(received.headers['idempotency-key'], 'same-key');
    expect(result['statusCode'], 422);
    expect(result['success'], isFalse);
    expect(result['errors'], isA<Map>());
    expect(result['message'], contains('attendances.0.status'));
    expect(result['message'], contains('Status tidak valid'));
  });

  test(
    'schedule conflicts retain API details and are not successful',
    () async {
      final service = ApiService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Jadwal bentrok.',
              'conflict_with': {
                'subject': 'Bahasa Indonesia',
                'class': 'X RPL 1',
                'room': 'Ruang 2',
                'time': '08:00 - 09:00',
              },
            }),
            409,
          );
        }),
      );

      final result = await service.post('/schedules', {});

      expect(result['success'], isFalse);
      expect(result['statusCode'], 409);
      expect(result['message'], contains('Jadwal bentrok.'));
      expect(result['message'], contains('Bahasa Indonesia'));
      expect(result['message'], contains('08:00 - 09:00'));
    },
  );

  testWidgets('student dashboard requests today without student_id', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        final data = request.url.path.endsWith('/dashboard/today')
            ? {'schedules': []}
            : <dynamic>[];
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiswaHomeTab(
          user: UserModel(
            id: 1,
            username: 'siswa',
            fullname: 'Siswa',
            roleId: 1,
            roleName: 'Siswa',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final todayRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/dashboard/today'),
    );
    expect(todayRequest.url.queryParameters, isEmpty);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('parent opens child dashboard without a student selector', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        final data = request.url.path.endsWith('/dashboard/today')
            ? {'schedules': []}
            : <dynamic>[];
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiswaHomeTab(
            user: UserModel(
              id: 2,
              username: 'ortu',
              fullname: 'Orang Tua',
              roleId: 2,
              roleName: 'Orang Tua',
              children: const [
                {'id': 44, 'fullname': 'Siswa Backend'},
              ],
            ),
            api: api,
            isParent: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final todayRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/dashboard/today'),
    );
    expect(todayRequest.url.queryParameters, {'student_id': '44'});
    final attendanceRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/attendances/my'),
    );
    expect(attendanceRequest.url.queryParameters, {'student_id': '44'});
    expect(find.text('Pilih anak'), findsNothing);
    expect(find.text('Pilih siswa'), findsNothing);
    expect(find.text('Siswa Backend'), findsWidgets);
  });

  testWidgets('parent attendance history shows the linked student records', (
    tester,
  ) async {
    late http.Request attendanceRequest;
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/attendances/my')) {
          attendanceRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 8,
                  'date': DateTime.now().toIso8601String().substring(0, 10),
                  'status': 'Alpha',
                  'journal': {
                    'schedule': {'subject': 'Matematika'},
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'data': <dynamic>[]}),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceHistoryScreen(
          user: UserModel(
            id: 2,
            username: 'ortu',
            fullname: 'Orang Tua',
            roleId: 2,
            roleName: 'Orang Tua',
          ),
          isParent: true,
          student: const {'id': 44, 'fullname': 'Siswa Backend'},
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(attendanceRequest.url.queryParameters, {'student_id': '44'});
    expect(find.text('Presensi Anak'), findsOneWidget);
    expect(find.text('Siswa Backend'), findsOneWidget);
    expect(find.text('Alpa'), findsWidgets);
    expect(find.text('Matematika'), findsOneWidget);
  });

  testWidgets('Guru BK schedules show every returned class and BK subject', (
    tester,
  ) async {
    final schedules = [
      {
        'id': 41,
        'subject': 'BK',
        'start_time': '08:00:00',
        'end_time': '08:45:00',
        'day_of_week': 'Senin',
        'cycle': 1,
        'class': {'id': 5, 'class_name': 'X RPL 1'},
      },
      {
        'id': 42,
        'subject': 'Bimbingan dan Konseling',
        'start_time': '09:00:00',
        'end_time': '09:45:00',
        'day_of_week': 'Senin',
        'cycle': 1,
        'class': {'id': 6, 'class_name': 'X RPL 2'},
      },
    ];
    final api = ApiService(
      client: MockClient((request) async {
        final data = request.url.path.endsWith('/schedules/today')
            ? schedules
            : <dynamic>[];
        return http.Response(
          jsonEncode({'success': true, 'day': 'Senin', 'data': data}),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleScheduleScreen(
          user: UserModel(
            id: 8,
            username: 'guru-bk',
            fullname: 'Guru BK',
            roleId: 3,
            roleName: 'Guru BK',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BK'), findsOneWidget);
    expect(find.text('Bimbingan dan Konseling'), findsOneWidget);
    expect(find.textContaining('Kelas X RPL 1'), findsOneWidget);
    expect(find.textContaining('Kelas X RPL 2'), findsOneWidget);
  });

  testWidgets('Orang Tua dashboard displays child info, switcher, and passes student_id', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final parentUser = UserModel(
      id: 100,
      username: 'ortu.17802',
      fullname: 'Bpk Orang Tua',
      roleId: 4,
      roleName: 'Orang Tua',
      children: [
        {
          'id': 16582,
          'fullname': 'Dani Arsyad Razak',
          'nis': '17802',
          'class_id': 6,
          'class_name': 'XII RPL 2',
        },
      ],
    );

    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.contains('/leave-requests/my')) {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }
        if (request.url.path.contains('/dashboard/today')) {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }
        if (request.url.path.contains('/attendances/my')) {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiswaHomeTab(
            user: parentUser,
            isParent: true,
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Bpk Orang Tua'), findsOneWidget);
    expect(find.textContaining('Dani Arsyad Razak'), findsWidgets);
    expect(find.textContaining('XII RPL 2'), findsWidgets);
    expect(find.byType(ChoiceChip), findsOneWidget);
  });
}

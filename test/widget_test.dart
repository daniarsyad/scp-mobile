// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui' show Size;

import 'package:flutter/material.dart' show FadeTransition, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:scp_mobile/main.dart';

void main() {
  testWidgets('Responsive splash transitions to login screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ScpApp());

    expect(find.text('SCP School'), findsOneWidget);
    expect(find.text('Sistem Informasi & Presensi Digital'), findsOneWidget);
    expect(find.text('SMK NEGERI 1 BANTUL'), findsOneWidget);
    expect(find.text('Memuat aplikasi...'), findsOneWidget);
    expect(find.text('PORTAL SEKOLAH DIGITAL'), findsNothing);
    expect(tester.takeException(), isNull);

    final initialTextOpacity = tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('loading-text-pulse')),
        )
        .opacity
        .value;
    await tester.pump(const Duration(milliseconds: 250));
    final animatedTextOpacity = tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('loading-text-pulse')),
        )
        .opacity
        .value;
    expect(animatedTextOpacity, isNot(initialTextOpacity));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Akun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scp_mobile/services/app_theme_controller.dart';

void main() {
  final controller = AppThemeController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await controller.load();
  });

  test('defaults to light mode when no preference is saved', () {
    expect(controller.themeMode, ThemeMode.light);
  });

  test('loads legacy system preference as light mode', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'system'});

    await controller.load();

    expect(controller.themeMode, ThemeMode.light);
  });

  test('converts system mode requests to light mode', () async {
    await controller.setThemeMode(ThemeMode.system);

    expect(controller.themeMode, ThemeMode.light);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_theme_mode'), 'light');
  });

  test('allows dark mode when explicitly selected', () async {
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.themeMode, ThemeMode.dark);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_theme_mode'), 'dark');
  });
}

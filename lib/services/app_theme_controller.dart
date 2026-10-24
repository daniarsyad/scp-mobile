import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final instance = AppThemeController._();
  static const _preferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_preferenceKey);
    _themeMode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final previousMode = _themeMode;
    _themeMode = themeMode;
    notifyListeners();

    final savedMode = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_preferenceKey, savedMode);
      if (!saved) throw StateError('Preferensi tema tidak dapat disimpan.');
    } catch (_) {
      _themeMode = previousMode;
      notifyListeners();
      rethrow;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final instance = AppThemeController._();
  static const _preferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_preferenceKey);
    _themeMode = switch (savedMode) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final previousMode = _themeMode;
    final selectedMode = themeMode == ThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    _themeMode = selectedMode;
    notifyListeners();

    final savedMode = selectedMode == ThemeMode.dark ? 'dark' : 'light';
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

import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/app_theme_controller.dart';
import 'theme/scp_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScpApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppThemeController.instance.load());
  });
}

class ScpApp extends StatelessWidget {
  const ScpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'SCP School',
        debugShowCheckedModeBanner: false,
        theme: scpTheme(),
        darkTheme: scpDarkTheme(),
        themeMode: AppThemeController.instance.themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/app_theme_controller.dart';
import 'theme/scp_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  runApp(const ScpApp());
}

class ScpApp extends StatelessWidget {
  const ScpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'SCP School',
        debugShowCheckedModeBanner: false,
        theme: scpTheme(),
        darkTheme: scpDarkTheme(),
        themeMode: AppThemeController.instance.themeMode,
        home: const LoginScreen(),
      ),
    );
  }
}

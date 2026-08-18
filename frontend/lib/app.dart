import 'package:flutter/material.dart';

import 'package:magang_titc/screens/auth/login_screen.dart';
import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/theme_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TITC Indonesia',
          theme: ThemeData(
            colorScheme: .fromSeed(seedColor: const Color(0xFF1E5AF5)),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E5AF5),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: mode,
          home: AuthService.isLoggedIn
              ? const MainShell()
              : const LoginScreen(),
        );
      },
    );
  }
}

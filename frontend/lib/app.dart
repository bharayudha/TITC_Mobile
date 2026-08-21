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
          // `MediaQuery.platformBrightness` mengikuti setelan OS device,
          // BUKAN toggle dark mode kita — dua sinyal yang independen. Ini
          // membuat widget yang membaca `platformBrightness` sebagai
          // fallback (mis. `GlassContentAwareBrightness` di
          // `MainShellGlassBar`, dipakai untuk warna teks "Indonesia")
          // salah tebak brightness saat toggle kita menyala tapi OS device
          // tetap di mode terang — teks jadi nyaris tak terlihat karena
          // warnanya dihitung untuk latar terang padahal aplikasi gelap.
          // Override di sini menyamakan `platformBrightness` dengan mode
          // kita sendiri untuk SELURUH subtree aplikasi, bukan tambal di
          // satu widget saja.
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                platformBrightness: mode == ThemeMode.dark
                    ? Brightness.dark
                    : Brightness.light,
              ),
              child: child!,
            );
          },
          home: AuthService.isLoggedIn
              ? const MainShell()
              : const LoginScreen(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'package:magang_titc/screens/auth/login_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TITC Indonesia',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: const Color(0xFF1E5AF5)),
      ),
      home: const LoginScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:magang_titc/app.dart';
import 'package:magang_titc/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const App());
}

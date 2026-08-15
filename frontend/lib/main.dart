import 'package:flutter/material.dart';

import 'package:magang_titc/app.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/messages_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  // Dimuat DI SINI (bukan dari `initState` tombol chat) supaya badge
  // unread punya nilai yang benar SEBELUM frame pertama digambar sama
  // sekali — lihat catatan lengkap di
  // `MessagesService.preloadCachedUnreadCount`.
  await MessagesService.preloadCachedUnreadCount();
  runApp(const App());
}

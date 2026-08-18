import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:magang_titc/app.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/messages_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:magang_titc/services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm shader Liquid Glass DI SINI (sebelum runApp) — kalau tidak,
  // kompilasi shader (bisa 100-800ms di GLES Android) jalan pas frame
  // pertama, berisiko ANR "Input dispatching timed out" (lihat dokumentasi
  // LiquidGlassWidgets.initialize di package liquid_glass_widgets).
  await LiquidGlassWidgets.initialize();
  await AuthService.init();
  // Dimuat DI SINI (bukan dari `initState` tombol chat) supaya badge
  // unread punya nilai yang benar SEBELUM frame pertama digambar sama
  // sekali — lihat catatan lengkap di
  // `MessagesService.preloadCachedUnreadCount`.
  await MessagesService.preloadCachedUnreadCount();
  
  try {
    await Firebase.initializeApp();
    await FirebaseMessagingService.init();
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(
    LiquidGlassWidgets.wrap(
      // `Theme.maybeBrightnessOf` menjembatani `ThemeMode` MaterialApp ke
      // sistem brightness milik package ini (package ini sengaja tidak
      // import flutter/material.dart sama sekali).
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const App(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:magang_titc/app.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/messages_service.dart';

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
  runApp(
    LiquidGlassWidgets.wrap(
      // `Theme.maybeBrightnessOf` menjembatani `ThemeMode` MaterialApp ke
      // sistem brightness milik package ini (package ini sengaja tidak
      // import flutter/material.dart sama sekali).
      brightnessResolver: Theme.maybeBrightnessOf,
      // Tanpa ini, tiap widget kaca (GlassTabBar.bottom di bottom nav,
      // GlassAppBar di MainShellGlassBar, dst) jatuh ke default masing-
      // masing — dan defaultnya TIDAK konsisten: `GlassTabBar.bottom`
      // fallback ke `GlassQuality.premium` (shader refraksi penuh +
      // chromatic aberration), padahal ia SELALU tampil & ikut animasi
      // scroll-hide/scroll-list — persis skenario yang di peringatkan
      // dokumentasi package ini sebagai "jangan pakai premium". Terbukti:
      // `GlassPerformanceMonitor` bawaan package mencatat 7-9 permukaan
      // premium aktif bersamaan dengan raster frame >16ms (di bawah 60fps)
      // sejak sesi awal, dan device fisik tim masih terasa berat. `standard`
      // = shader ringan, aman untuk widget yang scroll/animasi terus-
      // menerus, di semua platform — fitur visualnya sama, cuma kualitas
      // shader-nya diturunkan.
      theme: GlassThemeData.simple(quality: GlassQuality.standard),
      child: const App(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi light/dark mode user, disimpan lokal lewat `SharedPreferences`
/// — pola sama dengan `MessagesService.unreadCountNotifier` (ValueNotifier
/// + preload sebelum `runApp` supaya tidak ada kedipan tema saat cold start).
///
/// Baru infrastruktur ThemeMode-nya saja: layar-layar lain masih banyak
/// pakai warna hardcode (`Colors.white`, dst) yang belum theme-aware, jadi
/// efek visualnya baru terlihat penuh di widget yang sudah baca
/// `Theme.of(context)` — retrofit per-layar dikerjakan bertahap.
class ThemeService {
  ThemeService._();

  static const _kIsDarkKey = 'is_dark_mode';

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Dipanggil sekali di `main()` sebelum `runApp`, sama seperti
  /// `AuthService.init()`/`MessagesService.preloadCachedUnreadCount()`.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kIsDarkKey) ?? false;
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool isDark) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsDarkKey, isDark);
  }
}

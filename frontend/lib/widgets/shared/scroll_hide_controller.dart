import 'package:flutter/widgets.dart';

/// Sembunyikan/tampilkan [MainShellGlassBar] berdasarkan JARAK scroll
/// kumulatif, bukan langsung begitu arah scroll berbalik.
///
/// Versi sebelumnya memakai `UserScrollNotification.direction` — bereaksi
/// pada gerakan sekecil apa pun begitu arahnya berbalik, jadi bar terasa
/// "kedip" saat user scroll sedikit/ragu-ragu (mis. baru geser beberapa
/// piksel lalu balik lagi). Dipakai bersama oleh `MainShell` dan
/// `MessagesListScreen`, jadi diangkat ke sini alih-alih disalin dua kali —
/// pola yang sama dengan `WebViewCookieHelper`/`portal_navigator.dart`.
class ScrollHideController {
  ScrollHideController({this.hideThreshold = 24.0, this.showThreshold = 24.0})
    : visible = ValueNotifier<bool>(true);

  /// `true` = bar tampil, `false` = disembunyikan. Diteruskan langsung ke
  /// parameter `visible` milik `MainShellGlassBar`.
  final ValueNotifier<bool> visible;

  /// Jarak scroll ke BAWAH (piksel logis) yang harus terlampaui sebelum bar
  /// disembunyikan.
  final double hideThreshold;

  /// Jarak scroll ke ATAS yang harus terlampaui sebelum bar ditampilkan lagi.
  final double showThreshold;

  double _accumulated = 0;

  /// Pasang sebagai `onNotification` milik
  /// `NotificationListener<ScrollNotification>`.
  bool onNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    final delta = notification.scrollDelta;
    if (delta == null || delta == 0) return false;

    // Reset akumulasi begitu arah berbalik — tanpa ini, progres dari arah
    // SEBELUMNYA ikut menambah/mengurangi arah yang BARU, sehingga threshold
    // efektif jadi tidak konsisten (kadang lebih gampang, kadang lebih susah
    // terpicu tergantung riwayat scroll sebelumnya).
    if ((delta > 0 && _accumulated < 0) || (delta < 0 && _accumulated > 0)) {
      _accumulated = 0;
    }
    _accumulated += delta;

    // scrollDelta positif = offset scroll bertambah = isi bergerak ke ATAS
    // (user scroll ke BAWAH) → sembunyikan. Negatif = isi bergerak ke BAWAH
    // (user scroll ke ATAS) → tampilkan.
    if (_accumulated > hideThreshold) {
      visible.value = false;
      _accumulated = 0;
    } else if (_accumulated < -showThreshold) {
      visible.value = true;
      _accumulated = 0;
    }
    return false;
  }

  void dispose() {
    visible.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/services/messages_service.dart';

const double kChatFabSize = 56;
const double _kFabMargin = 16;

/// Jarak geser (piksel) yang masih dianggap ketukan, bukan seretan.
const double _kTapThreshold = 8;

/// Lama animasi menempel ke tepi setelah jari dilepas.
const Duration _kSnapDuration = Duration(milliseconds: 100);

class ChatFabButton extends StatelessWidget {
  const ChatFabButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Diluruskan lagi: BUKAN lingkaran kaca DI LUAR ikon — kaca harus jadi
    // ISI bubble-nya sendiri. Tapi `LiquidShape` package (sealed class,
    // cuma Oval/RoundedRectangle/RoundedSuperellipse) tidak bisa dibentuk
    // persis siluet bubble+ekor, jadi shader refraksi sungguhan (dipakai
    // `GlassIconButton`) tidak bisa mengisi bentuk ini secara langsung.
    //
    // Solusinya: `ShaderMask` — gradasi kaca (highlight putih di kiri-atas
    // memudar ke biru tint di kanan-bawah, meniru refleksi cahaya kaca)
    // dilukis HANYA pada piksel ikon yang solid (memakai alpha glyph-nya
    // sebagai mask), jadi bentuknya tetap persis bubble+ekor+tiga titik,
    // tanpa lingkaran/latar tambahan apa pun di sekelilingnya.
    return SizedBox(
      width: kChatFabSize,
      height: kChatFabSize,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: MessagesService.unreadCountNotifier,
          builder: (context, unreadCount, child) {
            return GlassBadge(count: unreadCount, child: child!);
          },
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              // Meniru gradasi kaca dock bawah (`kBottomBarGlassDefaults`:
              // dasar putih translucent + `lightAngle` 135° kiri-atas) —
              // highlight putih terang di kiri-atas (arah cahaya sama),
              // memudar ke tint biru pucat, lalu ke `AppColors.primary`
              // pekat di kanan-bawah untuk kesan kedalaman/refraksi.
              return LinearGradient(
                begin: const Alignment(-0.6, -0.9),
                end: const Alignment(0.9, 0.9),
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFBBD6FF).withValues(alpha: 0.85),
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.primaryDark,
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ).createShader(bounds);
            },
            child: const PhosphorIcon(
              PhosphorIconsFill.chatCircleDots,
              color: Colors.white,
              size: 46,
            ),
          ),
        ),
      ),
    );
  }
}

/// Membungkus [ChatFabButton] agar bisa digeser ke mana saja di dalam area
/// induknya, lalu menempel ke tepi kiri/kanan terdekat saat dilepas.
/// Posisi terakhir diingat selama shell hidup, jadi tidak kembali ke sudut
/// ketika berpindah tab.
///
/// Harus dipasang sebagai `Positioned.fill` di dalam sebuah [Stack].
class DraggableChatFab extends StatefulWidget {
  const DraggableChatFab({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<DraggableChatFab> createState() => _DraggableChatFabState();
}

class _DraggableChatFabState extends State<DraggableChatFab> {
  @override
  void initState() {
    super.initState();
    // Pemilik badge yang menyalakan sumber datanya sendiri — pola yang sama
    // dipakai `TitcAppBar` untuk badge lonceng. Aman dipanggil berulang:
    // pemanggilan kedua diabaikan selama timer sebelumnya masih hidup.
    //
    // Timer-nya sengaja TIDAK dimatikan di dispose: FAB ini ikut hidup-mati
    // bersama shell saat berpindah tab, sementara badge harus tetap terbaru
    // sepanjang sesi. Yang mematikannya adalah logout, lewat
    // `stopUnreadPolling()`.
    MessagesService.startUnreadPolling();
  }

  /// Kunci area induk, dipakai mengubah koordinat jari (global) menjadi
  /// koordinat lokal di dalam area geser.
  final GlobalKey _areaKey = GlobalKey();

  /// Posisi sudut kiri-atas tombol. Null berarti belum pernah digeser,
  /// sehingga dipakai posisi bawaan di sudut kanan bawah.
  Offset? _position;

  /// Titik pegangan jari relatif terhadap sudut kiri-atas tombol, direkam
  /// saat jari menyentuh. Membuat tombol tidak "melompat" ke tengah jari.
  Offset _grabOffset = Offset.zero;

  bool _isDragging = false;
  bool _snapping = false;

  /// Total jarak jari bergerak sejak menyentuh, untuk membedakan tap vs geser.
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = constraints.maxWidth - kChatFabSize;
        final maxY = constraints.maxHeight - kChatFabSize;

        final current =
            _position ?? Offset(maxX - _kFabMargin, maxY - _kFabMargin);

        // Dijepit ulang setiap build supaya tombol tetap terlihat walau
        // ukuran layar berubah, misalnya saat keyboard muncul atau rotasi.
        final clamped = _clamp(current, maxX, maxY);

        return Stack(
          key: _areaKey,
          children: [
            AnimatedPositioned(
              // Saat jari masih menempel, durasinya nol supaya tombol
              // mengikuti jari tanpa jeda sedikit pun.
              duration: _snapping ? _kSnapDuration : Duration.zero,
              curve: Curves.easeOutCubic,
              left: clamped.dx,
              top: clamped.dy,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                // Listener dipakai (bukan GestureDetector) agar tombol
                // langsung bergerak sejak piksel pertama, tanpa menunggu
                // ambang batas geser bawaan Flutter.
                onPointerDown: (event) {
                  _dragDistance = 0;
                  _grabOffset = event.localPosition;
                },
                onPointerMove: (event) {
                  _dragDistance += event.delta.distance;
                  // Posisi dihitung dari koordinat jari saat ini, bukan dari
                  // penjumlahan delta. Event pointer datang lebih rapat
                  // daripada frame, jadi cara akumulatif akan kehilangan
                  // sebagian gerakan dan tombol tertinggal di belakang jari.
                  final target = _localOf(event.position) - _grabOffset;
                  setState(() {
                    _snapping = false;
                    _isDragging = true;
                    _position = _clamp(target, maxX, maxY);
                  });
                },
                onPointerUp: (_) {
                  // Gerakan sangat kecil dianggap ketukan biasa.
                  if (_dragDistance < _kTapThreshold) {
                    setState(() => _isDragging = false);
                    widget.onTap?.call();
                    return;
                  }
                  _snapToNearestEdge(maxX, maxY);
                },
                onPointerCancel: (_) => _snapToNearestEdge(maxX, maxY),
                child: AnimatedScale(
                  // Sedikit membesar saat digeser sebagai umpan balik sentuhan.
                  scale: _isDragging ? 1.1 : 1,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: const ChatFabButton(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Mengubah koordinat global jari menjadi koordinat di dalam area geser.
  Offset _localOf(Offset globalPosition) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return globalPosition;
    return box.globalToLocal(globalPosition);
  }

  Offset _clamp(Offset value, double maxX, double maxY) {
    return Offset(
      value.dx.clamp(_kFabMargin, maxX - _kFabMargin).toDouble(),
      value.dy.clamp(_kFabMargin, maxY - _kFabMargin).toDouble(),
    );
  }

  /// Menempelkan tombol ke tepi kiri atau kanan, mana yang lebih dekat.
  void _snapToNearestEdge(double maxX, double maxY) {
    final from = _position ?? Offset(maxX - _kFabMargin, maxY - _kFabMargin);
    final isLeftHalf = from.dx + kChatFabSize / 2 < (maxX + kChatFabSize) / 2;
    setState(() {
      _isDragging = false;
      _snapping = true;
      _position = Offset(
        isLeftHalf ? _kFabMargin : maxX - _kFabMargin,
        from.dy,
      );
    });
  }
}

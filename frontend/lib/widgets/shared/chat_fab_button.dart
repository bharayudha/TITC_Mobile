import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Ikon "ChatCircleDots" dari Phosphor, sesuai layer di Figma.
      // Kotak 56x56 dipertahankan supaya area sentuhnya tetap nyaman.
      child: SizedBox(
        width: kChatFabSize,
        height: kChatFabSize,
        child: Center(
          // Widget `Badge` bawaan Material dilepas — posisinya (kombinasi
          // `alignment` + `offset`) terbukti tidak bisa didekatkan ke ikon
          // sekencang apa pun offset-nya diubah (sudah dicoba beberapa
          // nilai, tetap ada jarak). Diganti `Stack` + `Positioned` manual
          // supaya badge-nya benar2 nempel di pojok kanan-atas GLYPH ikon
          // (bukan pojok kotak sentuh 56px), sesuai gaya badge notifikasi
          // umum (mis. WhatsApp).
          child: ValueListenableBuilder<int>(
            valueListenable: MessagesService.unreadCountNotifier,
            builder: (context, unreadCount, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (unreadCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        // Angka besar dipendekkan jadi "99+" supaya badge
                        // tidak melebar sampai menutupi ikonnya sendiri.
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            // Ikon dibuat di luar builder karena isinya tidak bergantung
            // pada angka unread — jadi tidak perlu dibangun ulang tiap
            // badge berubah.
            child: const PhosphorIcon(
              PhosphorIconsRegular.chatCircleDots,
              color: Colors.black87,
              size: 34,
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

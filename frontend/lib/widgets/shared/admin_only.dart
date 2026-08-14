import 'package:flutter/material.dart';
import 'package:magang_titc/services/auth_service.dart';

/// Bungkus konten supaya hanya dirender saat user yang login adalah
/// admin/manager komunitas FCOM ([AuthService.isCurrentUserAdmin]). Untuk
/// user biasa, widget ini tidak menggambar apa pun ([SizedBox.shrink]) —
/// tidak ada perubahan tampilan sama sekali dibanding sebelum fitur admin
/// ditambahkan. Pola yang sama persis dengan gating tombol Settings di
/// `side_drawer.dart`, diangkat jadi satu widget supaya tidak diduplikasi
/// tiap kali layar lain butuh fitur khusus admin.
///
/// Status admin di-cache di memori oleh [AuthService] sendiri, jadi widget
/// ini aman dipakai berkali-kali (mis. tiap kali layar dibangun ulang) tanpa
/// memicu request jaringan berulang.
class AdminOnly extends StatelessWidget {
  const AdminOnly({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return builder(context);
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Kartu putih bersudut membulat dengan bayangan lembut, dipakai sebagai
/// pembungkus bagian-bagian konten di halaman berlatar abu-abu.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 12),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kShadowDown,
      ),
      child: child,
    );
  }
}

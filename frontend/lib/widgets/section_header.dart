import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Tinggi tetap untuk header tiap tab supaya konsisten antar halaman.
const double sectionHeaderHeight = 66;

/// Header judul halaman (Feed, Spaces, Courses, All Members) dengan tinggi
/// seragam. [trailing] diisi aksi di sisi kanan bila ada.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: sectionHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: kShadowDown,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

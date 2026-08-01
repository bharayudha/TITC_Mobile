import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/app_colors.dart';

/// Menampilkan mode pencarian: bilah pencarian menimpa app bar, sementara
/// seluruh konten di belakangnya diredupkan. Ditutup dengan menekan panah
/// kembali, mengetuk area redup, atau tombol back perangkat.
Future<String?> showSearchOverlay(BuildContext context) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup pencarian',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SearchOverlay();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Bilah pencarian yang menempel di atas layar saat mode pencarian aktif.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? query]) {
    Navigator.of(context).pop(query);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: kShadowDown,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 12),
                  _buildScopeButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.arrowLeft,
              color: Colors.black87,
            ),
            onPressed: _close,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              // Keyboard langsung terbuka begitu mode pencarian aktif.
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _close,
              decoration: const InputDecoration(
                hintText: 'Search here...',
                hintStyle: TextStyle(color: Colors.black54, fontSize: 17),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(fontSize: 17, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildScopeButton() {
    return GestureDetector(
      // TODO: tampilkan pilihan cakupan pencarian (All Post, Members, dll).
      onTap: () {},
      child: const Text(
        'ALL Post',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

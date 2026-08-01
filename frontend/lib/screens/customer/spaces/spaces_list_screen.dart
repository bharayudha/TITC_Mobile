import 'package:flutter/material.dart';

import 'package:magang_titc/widgets/shared/section_header.dart';

/// Konten tab Spaces. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class SpacesListScreen extends StatefulWidget {
  const SpacesListScreen({super.key});

  @override
  State<SpacesListScreen> createState() => _SpacesListScreenState();
}

class _SpacesListScreenState extends State<SpacesListScreen> {
  bool _showAllSpaces = true;

  @override
  Widget build(BuildContext context) {
    // Stack dipakai supaya header digambar paling akhir dan drop shadow-nya
    // tidak tertutup konten di bawahnya.
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFD9D9D9))),
          Align(
            alignment: Alignment.topCenter,
            child: _buildSpacesHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesHeader() {
    return SectionHeader(
      title: 'Spaces',
      trailing: Row(
        children: [
          _buildFilterChip('All Spaces', selected: _showAllSpaces),
          const SizedBox(width: 8),
          _buildFilterChip('My Spaces', selected: !_showAllSpaces),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _showAllSpaces = label == 'All Spaces'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E5AF5) : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

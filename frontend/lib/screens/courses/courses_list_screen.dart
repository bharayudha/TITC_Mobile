import 'package:flutter/material.dart';

import '../../widgets/section_header.dart';

/// Konten tab Courses. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  bool _showAllCourses = true;

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
            child: _buildCoursesHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesHeader() {
    return SectionHeader(
      title: 'Courses',
      trailing: Row(
        children: [
          _buildFilterChip('All Courses', selected: _showAllCourses),
          const SizedBox(width: 8),
          _buildFilterChip('My Courses', selected: !_showAllCourses),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _showAllCourses = label == 'All Courses'),
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

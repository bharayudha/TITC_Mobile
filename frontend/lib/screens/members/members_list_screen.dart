import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants/app_colors.dart';
import '../../widgets/section_header.dart';

/// Konten tab Members. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Stack dipakai supaya blok header digambar paling akhir dan drop
    // shadow-nya tidak tertutup konten di bawahnya.
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFEEF0F3))),
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMembersHeader(),
                _buildSearchBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersHeader() {
    return const SectionHeader(title: 'All Members');
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: kShadowDown,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Members...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.magnifyingGlass,
                color: Colors.grey,
                size: 20,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Sort by: ',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const Text(
                'Last Activity',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const PhosphorIcon(
                PhosphorIconsRegular.caretDown,
                size: 16,
                color: Colors.black54,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Konten tab Spaces. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class SpacesListScreen extends StatefulWidget {
  const SpacesListScreen({super.key});

  @override
  State<SpacesListScreen> createState() => _SpacesListScreenState();
}

class _SpacesListScreenState extends State<SpacesListScreen> {
  bool _showAllSpaces = true;
  late Future<List<SpaceModel>> _spacesFuture;

  @override
  void initState() {
    super.initState();
    _spacesFuture = ApiService.fetchSpaces();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFD9D9D9))),
          
          // Data List
          Positioned.fill(
            top: 70, // Beri jarak untuk SectionHeader
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _spacesFuture = ApiService.fetchSpaces();
                });
              },
              child: FutureBuilder<List<SpaceModel>>(
                future: _spacesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Belum ada space.'));
                  }

                  // Filter berdasarkan tab (All vs My Spaces)
                  final filteredSpaces = snapshot.data!.where((space) {
                    if (_showAllSpaces) return true;
                    return space.isJoined; // Asumsi: isJoined menandakan 'My Spaces'
                  }).toList();

                  if (filteredSpaces.isEmpty) {
                     return const Center(child: Text('Tidak ada space di kategori ini.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSpaces.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildSpaceCard(filteredSpaces[index]);
                    },
                  );
                },
              ),
            ),
          ),

          // Header diletakkan di atas agar shadow tidak tertutup list
          Align(
            alignment: Alignment.topCenter,
            child: _buildSpacesHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceCard(SpaceModel space) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              image: space.coverPhotoUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(space.coverPhotoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    image: space.logoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(space.logoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: space.logoUrl.isEmpty
                      ? const Center(child: PhosphorIcon(PhosphorIconsRegular.users, color: Colors.grey))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.public, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(space.privacy, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(width: 12),
                          PhosphorIcon(PhosphorIconsRegular.users, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${space.membersCount}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Simple HTML strip for description
                      Text(
                        space.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

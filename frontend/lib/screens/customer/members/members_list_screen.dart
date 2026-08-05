import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/member_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/constants/app_colors.dart';

/// Konten tab Members. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchController = TextEditingController();
  late Future<List<MemberModel>> _membersFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _membersFuture = ApiService.fetchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _membersFuture = ApiService.fetchMembers(search: _searchQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFEEF0F3))),
          
          // Data List
          Positioned.fill(
            top: 140, // Beri jarak untuk Header + SearchBar
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _membersFuture = ApiService.fetchMembers(search: _searchQuery);
                });
              },
              child: FutureBuilder<List<MemberModel>>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Belum ada member.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildMemberCard(snapshot.data![index]);
                    },
                  );
                },
              ),
            ),
          ),

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

  Widget _buildMemberCard(MemberModel member) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: member.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(member.avatarUrl) : null,
                  child: member.avatarUrl.isEmpty
                      ? const PhosphorIcon(PhosphorIconsRegular.user, color: Colors.grey)
                      : null,
                ),
                if (member.status == 'online')
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.lastActivity.isNotEmpty ? 'Active $member.lastActivity' : 'No activity',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E5AF5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              child: const Text('Follow', style: TextStyle(color: Color(0xFF1E5AF5), fontSize: 12)),
            )
          ],
        ),
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
            onSubmitted: _onSearchChanged,
            textInputAction: TextInputAction.search,
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

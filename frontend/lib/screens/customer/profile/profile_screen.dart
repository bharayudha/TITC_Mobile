import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/widgets/shared/app_card.dart';
import 'package:magang_titc/widgets/shared/profile_header.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';
import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/screens/customer/profile/notification_settings_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:magang_titc/services/auth_service.dart';

const Color _chipBorder = Color(0xFFDDDDDD);

/// Latar kotak tulis postingan.
const Color _composerFill = Color(0xFFEDF1F7);

/// Posisi tab Members pada bottom navigation di [MainShell].
const int kMembersTabIndex = 3;

/// Membuka daftar Members. Seluruh riwayat halaman dibersihkan agar tidak
/// menumpuk beberapa shell saat berpindah lewat breadcrumb.
void openMembersTab(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const MainShell(initialIndex: kMembersTabIndex),
    ),
    (route) => false,
  );
}

/// Halaman profil pengguna.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    // TODO: ambil dari user_model setelah auth_service tersambung.
    this.name = 'magang',
    this.username = 'magang_titc',
    this.followingCount = 0,
    this.followersCount = 0,
  });

  final String name;
  final String username;
  final int followingCount;
  final int followersCount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Pilihan urutan daftar postingan.
const List<String> _sortOptions = ['Latest', 'Oldest', 'Popular'];

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;
  String _sortBy = _sortOptions.first;

  void _openNotificationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          name: widget.name,
          username: widget.username,
          followingCount: widget.followingCount,
          followersCount: widget.followersCount,
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AuthenticatedWebViewScreen(
          url: 'https://titc.or.id/portal/account/',
          title: 'Account Settings',
        ),
      ),
    );
    // Refresh user profile data after returning from webview
    await AuthService.init();
    if (mounted) setState(() {});
  }

  Future<void> _openAvatarUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthenticatedWebViewScreen(
          url: 'https://titc.or.id/portal/u/${widget.username}/about',
          title: 'Edit Profile & Avatar',
        ),
      ),
    );
    // Refresh user profile data after returning from webview
    await AuthService.init();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfilePageBackground,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileBreadcrumb(
              onMembersTap: () => openMembersTab(context),
              onNotificationSettingsTap: _openNotificationSettings,
              onEditTap: _openEditProfile,
            ),
            const SizedBox(height: 12),
            ProfileIdentityCard(
              name: widget.name,
              username: widget.username,
              avatarUrl: AuthService.userAvatarUrl,
              followingCount: widget.followingCount,
              followersCount: widget.followersCount,
              onAvatarUploadTap: _openAvatarUpload,
            ),
            const SizedBox(height: 12),
            ProfileTabBar(
              selectedIndex: _selectedTab,
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
            const SizedBox(height: 12),
            if (_selectedTab == 0)
              _buildAboutCard()
            else if (_selectedTab == 1)
              _buildPostsTab()
            else
              _buildEmptyTab(kProfileTabs[_selectedTab]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildComposer(),
        const SizedBox(height: 16),
        _buildSortRow(),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: const Center(
            child: Text(
              'No posts found!',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  /// Kotak "What's happening" untuk membuat postingan baru.
  Widget _buildComposer() {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: AuthService.userAvatarUrl != null && AuthService.userAvatarUrl!.isNotEmpty
              ? NetworkImage(AuthService.userAvatarUrl!)
              : null,
          child: AuthService.userAvatarUrl == null || AuthService.userAvatarUrl!.isEmpty
              ? Text(
                  widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                )
              : null,
        ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              // TODO: buka form pembuatan postingan.
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _composerFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "What's happening, ${widget.name}",
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.divider, thickness: 1),
          ),
          const SizedBox(width: 12),
          const Text(
            'Sort by:',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sortBy,
            isDense: true,
            underline: const SizedBox.shrink(),
            icon: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: PhosphorIcon(
                PhosphorIconsRegular.caretDown,
                size: 14,
                color: Colors.black54,
              ),
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            items: _sortOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              // TODO: urutkan ulang daftar postingan lewat spaces_service.
              setState(() => _sortBy = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _openEditProfile,
                child: const PhosphorIcon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAddChip('Add your profile description'),
          const SizedBox(height: 16),
          _buildInfoRow(
            PhosphorIconsRegular.calendarBlank,
            'Joined 10 days ago',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            PhosphorIconsRegular.clock,
            'Last seen: a few seconds ago',
          ),
          const SizedBox(height: 16),
          _buildAddChip('Add social links'),
        ],
      ),
    );
  }

  Widget _buildAddChip(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _openEditProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: _chipBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '+ $label',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        PhosphorIcon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTab(String label) {
    return AppCard(
      child: SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Belum ada $label',
            style: const TextStyle(color: Colors.black45),
          ),
        ),
      ),
    );
  }
}

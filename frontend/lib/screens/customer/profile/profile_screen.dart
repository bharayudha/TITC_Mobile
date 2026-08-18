import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/widgets/shared/app_card.dart';
import 'package:magang_titc/widgets/shared/profile_header.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';
import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/screens/customer/profile/notification_settings_screen.dart';
import 'package:magang_titc/screens/customer/profile/profile_edit_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/api_service.dart';

const int kHomeTabIndex = 0;

/// Membuka halaman Home. Seluruh riwayat halaman dibersihkan agar tidak
/// menumpuk beberapa shell saat berpindah lewat breadcrumb.
void openHomeTab(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const MainShell(initialIndex: kHomeTabIndex),
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

  String get _currentName => AuthService.userName ?? widget.name;

  void _openNotificationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          name: _currentName,
          username: widget.username,
          followingCount: widget.followingCount,
          followersCount: widget.followersCount,
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final names = _currentName.split(' ');
    final firstName = names.isNotEmpty ? names.first : '';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          firstName: firstName,
          lastName: lastName,
          email: AuthService.userEmail ?? '',
          bio: '',
        ),
      ),
    );
    // Refresh user profile data after returning
    await AuthService.init();
    if (mounted) setState(() {});
  }

  Future<void> _openAvatarUpload() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // User canceled

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading photo... Please wait.'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await ApiService.uploadAvatar(File(pickedFile.path));

      if (success) {
        // Refresh user profile data to get the new avatar URL
        await AuthService.init();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update photo. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while picking the image.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await AuthService.init();
          if (mounted) setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileBreadcrumb(
                onHomeTap: () => openHomeTab(context),
                onNotificationSettingsTap: _openNotificationSettings,
                onEditTap: _openEditProfile,
              ),
              const SizedBox(height: 12),
              ProfileIdentityCard(
                name: _currentName,
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
          child: Center(
            child: Text(
              'No posts found!',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
            backgroundImage:
                AuthService.userAvatarUrl != null &&
                    AuthService.userAvatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(
                    AuthService.userAvatarUrl!,
                    headers: AuthService.imageAuthHeaders,
                    maxWidth: 72,
                    maxHeight: 72,
                  )
                : null,
            child:
                AuthService.userAvatarUrl == null ||
                    AuthService.userAvatarUrl!.isEmpty
                ? Text(
                    _currentName.isEmpty ? '?' : _currentName[0].toUpperCase(),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "What's happening, $_currentName",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
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
          Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sortBy,
            isDense: true,
            underline: const SizedBox.shrink(),
            icon: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: PhosphorIcon(
                PhosphorIconsRegular.caretDown,
                size: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
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
              Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: _openEditProfile,
                child: PhosphorIcon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
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
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '+ $label',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        PhosphorIcon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

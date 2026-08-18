import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/app_card.dart';

const Color kProfilePageBackground = Color(0xFFF0F2F5);
const Color _coverColor = Color(0xFFE4E6EB);

/// Daftar tab pada halaman profil.
const List<String> kProfileTabs = [
  'About',
  'Posts',
  'Spaces',
  'Courses',
  'Comments',
];

/// Bilah breadcrumb di atas halaman profil, lengkap dengan pintasan
/// Notification Settings dan tombol edit.
class ProfileBreadcrumb extends StatelessWidget {
  const ProfileBreadcrumb({
    super.key,
    this.onHomeTap,
    this.onNotificationSettingsTap,
    this.onEditTap,
  });

  final VoidCallback? onHomeTap;
  final VoidCallback? onNotificationSettingsTap;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: kShadowDown,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Digulir mendatar supaya tidak meluber di layar sempit.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onHomeTap,
                    child: const Text(
                      'Home',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Text('  /  ', style: TextStyle(color: Colors.black38)),
                  const Text(
                    'My Profile',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onNotificationSettingsTap,
                    child: const Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.arrowSquareOut,
                          size: 16,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Notification Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onEditTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const PhosphorIcon(
                PhosphorIconsRegular.pencilSimple,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu identitas: sampul, avatar, nama, username, dan jumlah pengikut.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.followingCount = 0,
    this.followersCount = 0,
    this.onAvatarUploadTap,
  });

  final String name;
  final String username;
  final String? avatarUrl;
  final int followingCount;
  final int followersCount;
  final VoidCallback? onAvatarUploadTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sampul dan avatar ditumpuk agar avatar menjorok ke bawah sampul.
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(height: 90, color: _coverColor),
                Positioned(left: 16, top: 30, child: _buildAvatar()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStat(followingCount, 'Following'),
                    const SizedBox(width: 16),
                    _buildStat(followersCount, 'Followers'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                        avatarUrl!,
                        headers: AuthService.imageAuthHeaders,
                        maxWidth: 360,
                        maxHeight: 360,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  )
                : null,
          ),
          // Lencana tingkat/level di kanan bawah avatar.
          Positioned(
            right: 4,
            bottom: 16,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Tombol unggah foto profil di kiri bawah avatar.
          Positioned(
            left: 0,
            bottom: 12,
            child: GestureDetector(
              onTap: onAvatarUploadTap,
              child: const PhosphorIcon(
                PhosphorIconsFill.cloudArrowUp,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(int count, String label) {
    return Row(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Baris tab profil. Beri [selectedIndex] bernilai -1 bila tidak ada tab yang
/// sedang aktif, misalnya saat membuka halaman Notification Settings.
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(kProfileTabs.length, (index) {
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAF1FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    kProfileTabs[index],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

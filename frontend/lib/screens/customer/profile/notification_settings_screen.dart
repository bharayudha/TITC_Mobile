import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/widgets/shared/app_card.dart';
import 'package:magang_titc/widgets/shared/profile_header.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';
import 'package:magang_titc/screens/customer/profile/profile_screen.dart';

/// Pilihan notifikasi email per space.
const List<String> _emailOptions = ['Email Disabled', 'Email Enabled'];

/// Satu baris space pada tabel notifikasi.
class _SpaceRow {
  const _SpaceRow({required this.emoji, required this.name});

  final String emoji;
  final String name;
}

/// Halaman pengaturan notifikasi milik pengguna.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
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
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _emailOnComment = false;
  bool _emailOnReply = false;
  bool _emailOnMention = false;
  bool _weeklyDigest = false;

  // TODO: ambil daftar space beserta setelannya dari members_service.
  static const List<_SpaceRow> _membershipAreas = [
    _SpaceRow(emoji: '🖥️', name: 'Institutional Prep Test'),
    _SpaceRow(emoji: '🔥', name: 'FREE Placement Test'),
  ];

  /// Setelan email per space, dikunci berdasarkan nama space.
  final Map<String, String> _spaceEmailSetting = {
    for (final space in _membershipAreas) space.name: _emailOptions.first,
  };

  void _saveChanges() {
    // TODO: kirim perubahan ke members_service.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perubahan disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileBreadcrumb(
              onHomeTap: () => openHomeTab(context),
              // Sudah berada di halaman ini, jadi tidak perlu aksi.
              onNotificationSettingsTap: null,
              onEditTap: () {},
            ),
            const SizedBox(height: 12),
            ProfileIdentityCard(
              name: widget.name,
              username: widget.username,
              followingCount: widget.followingCount,
              followersCount: widget.followersCount,
            ),
            const SizedBox(height: 12),
            // Tidak ada tab yang aktif di halaman ini; memilih tab akan
            // kembali ke halaman profil pada tab tersebut.
            ProfileTabBar(
              selectedIndex: -1,
              onSelected: (_) => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(
              icon: PhosphorIconsRegular.bellRinging,
              title: 'Global Email Notifications',
              subtitle:
                  "These settings will be applied across all spaces you're a "
                  'member of.',
            ),
            const SizedBox(height: 12),
            _buildGlobalEmailCard(),
            const SizedBox(height: 24),
            _buildSectionTitle(
              icon: PhosphorIconsRegular.users,
              title: 'New Posts Notifications',
              subtitle: 'Subscribe to new posts notifications by space',
            ),
            const SizedBox(height: 12),
            _buildSpacesTable(),
            const SizedBox(height: 20),
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalEmailCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildCheckboxRow(
            value: _emailOnComment,
            onChanged: (v) => setState(() => _emailOnComment = v),
            title: 'Email me when someone comments on my post',
            subtitle: 'No email will be sent for comments on your post.',
          ),
          _buildCheckboxRow(
            value: _emailOnReply,
            onChanged: (v) => setState(() => _emailOnReply = v),
            title: 'Email me when someone replies to my comments',
            subtitle:
                'No email will be sent when someone replies to your comments.',
          ),
          _buildCheckboxRow(
            value: _emailOnMention,
            onChanged: (v) => setState(() => _emailOnMention = v),
            title: 'Email me when someone mentions me in a post or comment',
            subtitle: 'No emails will be sent when someone mentions you.',
          ),
          _buildCheckboxRow(
            value: _weeklyDigest,
            onChanged: (v) => setState(() => _weeklyDigest = v),
            title: 'Weekly digest on Tuesday',
            subtitle: 'No digest email will be sent.',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: value,
                activeColor: AppColors.primary,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacesTable() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableHeader(),
          _buildGroupRow('MEMBERSHIP AREAS'),
          for (final space in _membershipAreas) _buildSpaceRow(space),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Space',
              style: TextStyle(fontSize: 13, color: mutedColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Notifications',
              style: TextStyle(fontSize: 13, color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupRow(String label) {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSpaceRow(_SpaceRow space) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // Lebar emoji berbeda antar perangkat, dikunci agar sejajar.
                SizedBox(
                  width: 24,
                  child: Text(space.emoji, style: emojiStyle(size: 16)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    space.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _buildEmailDropdown(space.name)),
        ],
      ),
    );
  }

  Widget _buildEmailDropdown(String spaceName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: _spaceEmailSetting[spaceName],
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        icon: PhosphorIcon(
          PhosphorIconsRegular.caretDown,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        items: _emailOptions
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _spaceEmailSetting[spaceName] = value);
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

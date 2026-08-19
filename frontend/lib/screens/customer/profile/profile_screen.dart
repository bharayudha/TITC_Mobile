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
import 'package:magang_titc/models/member_model.dart';
import 'package:magang_titc/models/activity_model.dart';
import 'package:magang_titc/models/space_model.dart';
import 'package:magang_titc/models/course_model.dart';
import 'package:magang_titc/widgets/customer/space_card.dart';
import 'package:magang_titc/widgets/customer/course_card.dart';
import 'dart:ui';

const Color _chipBorder = Color(0xFFDDDDDD);

/// Latar kotak tulis postingan.
const Color _composerFill = Color(0xFFEDF1F7);

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

  MemberModel? _memberProfile;
  List<ActivityModel>? _feeds;
  List<SpaceModel>? _spaces;
  List<CourseModel>? _courses;

  bool _isLoadingFeeds = false;
  bool _isLoadingSpaces = false;
  bool _isLoadingCourses = false;

  String get _currentName => AuthService.userName ?? widget.name;
  
  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final slug = AuthService.userSlug ?? widget.username;
    final profile = await ApiService.fetchMemberProfile(slug);
    if (mounted) {
      setState(() {
        _memberProfile = profile;
      });
      // Fetch data for the initially selected tab (About tab doesn't need extra fetch)
      _fetchTabData(_selectedTab);
    }
  }

  Future<void> _fetchTabData(int index) async {
    final slug = AuthService.userSlug ?? widget.username;
    if (index == 1 && _feeds == null) {
      setState(() => _isLoadingFeeds = true);
      final feeds = await ApiService.fetchUserFeeds(slug);
      if (mounted) setState(() { _feeds = feeds; _isLoadingFeeds = false; });
    } else if (index == 2 && _spaces == null) {
      setState(() => _isLoadingSpaces = true);
      final spaces = await ApiService.fetchUserSpaces(slug);
      if (mounted) setState(() { _spaces = spaces; _isLoadingSpaces = false; });
    } else if (index == 3 && _courses == null) {
      setState(() => _isLoadingCourses = true);
      final courses = await ApiService.fetchUserCourses(slug);
      if (mounted) setState(() { _courses = courses; _isLoadingCourses = false; });
    }
  }

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
          bio: _memberProfile?.bio ?? '',
          headline: _memberProfile?.headline ?? '',
          socialLinks: _memberProfile?.socialLinks ?? const {},
          username: _memberProfile?.username ?? AuthService.userSlug ?? '',
          userId: _memberProfile?.id ?? 0,
          status: _memberProfile?.status ?? 'active',
          isVerified: _memberProfile?.isVerified ?? 0,
          isFlagged: _memberProfile?.isFlagged ?? 'no',
          badgeSlugs: _memberProfile?.badgeSlugs ?? const [],
          customFields: _memberProfile?.customFields ?? const {},
        ),
      ),
    );
    // Refresh FCOM profile data after returning
    await _fetchProfileData();
    // Reset tab data so they refresh with fresh data
    if (mounted) setState(() {
      _feeds = null;
      _spaces = null;
      _courses = null;
    });
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
        const SnackBar(content: Text('Uploading photo... Please wait.'), duration: Duration(seconds: 2)),
      );

      final success = await ApiService.uploadAvatar(File(pickedFile.path));

      if (success) {
        // Refresh user profile data to get the new avatar URL
        await AuthService.init();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update photo. Please try again.')),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while picking the image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfilePageBackground,
      appBar: const TitcAppBar(),
      drawer: const SideDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await AuthService.init();
          await _fetchProfileData();
          if (mounted) setState(() {
             _feeds = null;
             _spaces = null;
             _courses = null;
          });
          await _fetchTabData(_selectedTab);
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
              onSelected: (index) {
                setState(() => _selectedTab = index);
                _fetchTabData(index);
              },
            ),
            const SizedBox(height: 12),
            if (_selectedTab == 0)
              _buildAboutCard()
            else if (_selectedTab == 1)
              _buildPostsTab()
            else if (_selectedTab == 2)
              _buildSpacesTab()
            else if (_selectedTab == 3)
              _buildCoursesTab()
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
        if (_isLoadingFeeds)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_feeds == null || _feeds!.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: const Center(
              child: Text(
                'No posts found!',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _feeds!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _buildActivityCard(_feeds![index]),
          ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    // Basic feed card implementation for profile
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // TODO: Open comment detail
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: activity.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  activity.avatarUrl,
                                  headers: AuthService.imageAuthHeaders,
                                )
                              : null,
                          child: activity.avatarUrl.isEmpty
                              ? Text(activity.authorName.isNotEmpty ? activity.authorName[0] : '?')
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 activity.authorName,
                                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                               ),
                               if (activity.date.isNotEmpty)
                                 Text(
                                   activity.date.split('T')[0],
                                   style: const TextStyle(fontSize: 12, color: Colors.black54),
                                 ),
                             ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activity.content,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacesTab() {
    if (_isLoadingSpaces) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_spaces == null || _spaces!.isEmpty) {
      return _buildEmptyTab('Spaces');
    }
    // Satu kolom, bukan grid 2 kolom — SpaceCard (cover 130px + logo +
    // deskripsi + tombol) butuh tinggi lebih dari yang muat di sel grid
    // sempit, dulu bikin kartu overflow dan tombol "View Space" terpotong.
    // Samakan dengan tab Spaces asli (`spaces_list_screen.dart`) yang juga
    // memakai daftar satu kolom.
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _spaces!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => SpaceCard(
        space: _spaces![index],
        onJoinPressed: () async {
          bool success = await ApiService.joinSpace(_spaces![index].slug);
          if (success) {
            _fetchTabData(_selectedTab);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Berhasil bergabung ke Space!')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gagal bergabung ke Space.')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildCoursesTab() {
    if (_isLoadingCourses) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_courses == null || _courses!.isEmpty) {
      return _buildEmptyTab('Courses');
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _courses!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => CourseCard(course: _courses![index]),
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
              ? CachedNetworkImageProvider(AuthService.userAvatarUrl!, headers: AuthService.imageAuthHeaders)
              : null,
          child: AuthService.userAvatarUrl == null || AuthService.userAvatarUrl!.isEmpty
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
                  color: _composerFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "What's happening, $_currentName",
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
    final bio = _memberProfile?.bio;
    final headline = _memberProfile?.headline;
    final socialLinks = _memberProfile?.socialLinks ?? {};
    
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
          if (headline != null && headline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                headline,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          if (bio != null && bio.isNotEmpty)
            Text(
              bio,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            )
          else
            _buildAddChip('Add your profile description'),
          const SizedBox(height: 16),
          if (_memberProfile != null && _memberProfile!.joinedAt.isNotEmpty) ...[
            _buildInfoRow(
              PhosphorIconsRegular.calendarBlank,
              'Joined ${_memberProfile!.joinedAt}',
            ),
            const SizedBox(height: 12),
          ],
          if (_memberProfile != null && _memberProfile!.lastActivity.isNotEmpty) ...[
            _buildInfoRow(
              PhosphorIconsRegular.clock,
              'Last seen: ${_memberProfile!.lastActivity}',
            ),
            const SizedBox(height: 16),
          ],
          if (socialLinks.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: socialLinks.entries.map((e) => _buildSocialIcon(e.key, e.value)).toList(),
            )
          else
            _buildAddChip('Add social links'),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(String provider, String url) {
    IconData iconData = PhosphorIconsRegular.link;
    switch (provider.toLowerCase()) {
      case 'instagram': iconData = PhosphorIconsRegular.instagramLogo; break;
      case 'youtube': iconData = PhosphorIconsRegular.youtubeLogo; break;
      case 'linkedin': iconData = PhosphorIconsRegular.linkedinLogo; break;
      case 'facebook': iconData = PhosphorIconsRegular.facebookLogo; break;
      case 'tiktok': iconData = PhosphorIconsRegular.tiktokLogo; break;
      case 'telegram': iconData = PhosphorIconsRegular.telegramLogo; break;
      case 'twitter':
      case 'x': iconData = PhosphorIconsRegular.twitterLogo; break;
    }
    return GestureDetector(
      onTap: () {
        // TODO: open URL
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: PhosphorIcon(iconData, size: 20, color: AppColors.primary),
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

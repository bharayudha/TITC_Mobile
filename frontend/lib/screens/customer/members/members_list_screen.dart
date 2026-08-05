import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/member_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/constants/app_colors.dart';

const Color _kAccent = Color(0xFF1E5AF5);

/// Konten tab Members. App bar, drawer, chat FAB, dan bottom nav dipasang oleh
/// [MainShell].
///
/// Meniru halaman `/portal/members` di web: judul "All Members (n)", kotak
/// pencarian, penanda urutan, lalu daftar kartu member berisi avatar, nama,
/// @username, waktu bergabung & terakhir aktif, bio singkat, ikon sosial,
/// dan tombol Follow. Karena jumlah member ribuan, daftarnya di-scroll tak
/// terbatas (halaman berikutnya diambil saat mendekati bawah).
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<MemberModel> _members = [];
  int _total = 0;
  int _nextPage = 1;
  bool _hasMore = true;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _error;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Muat halaman berikutnya sedikit sebelum benar-benar mentok di bawah
    // supaya scroll terasa mulus tanpa jeda.
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _error = null;
    });

    try {
      final page = await ApiService.fetchMembers(search: _searchQuery, page: 1);
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(page.members);
        _total = page.total;
        _nextPage = 2;
        _hasMore = page.hasMore;
        _isLoadingFirstPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoadingFirstPage = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoadingFirstPage) return;
    setState(() => _isLoadingMore = true);

    try {
      final page =
          await ApiService.fetchMembers(search: _searchQuery, page: _nextPage);
      if (!mounted) return;
      setState(() {
        _members.addAll(page.members);
        _total = page.total;
        _nextPage += 1;
        _hasMore = page.hasMore && page.members.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Gagal memuat halaman tambahan tidak boleh menghapus daftar yang
      // sudah tampil — cukup hentikan pemuatan berikutnya.
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _loadFirstPage();
    });
  }

  Future<void> _onFollowPressed(MemberModel member) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index == -1) return;

    final wantFollow = !_members[index].isFollowed;
    // Optimistic update supaya tombol terasa responsif.
    setState(() => _members[index] = _copyWithFollow(_members[index], wantFollow));

    final ok = await ApiService.toggleFollowMember(member.id, follow: wantFollow);
    if (!mounted) return;
    if (!ok) {
      setState(() => _members[index] = _copyWithFollow(_members[index], !wantFollow));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wantFollow ? 'Gagal mengikuti member.' : 'Gagal berhenti mengikuti.',
          ),
        ),
      );
    }
  }

  MemberModel _copyWithFollow(MemberModel m, bool isFollowed) => MemberModel(
        id: m.id,
        displayName: m.displayName,
        username: m.username,
        avatarUrl: m.avatarUrl,
        lastActivity: m.lastActivity,
        joinedAt: m.joinedAt,
        bio: m.bio,
        status: m.status,
        isFollowed: isFollowed,
        socialLinks: m.socialLinks,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF0F3),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // Judul mengikuti web: "All Members (2,256)". Angka baru ditampilkan
    // setelah data pertama masuk supaya tidak sempat terlihat "(0)".
    final title = _total > 0
        ? 'All Members (${_formatCount(_total)})'
        : 'All Members';
    return SectionHeader(title: title);
  }

  static String _formatCount(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Widget _buildBody() {
    if (_isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_members.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'Belum ada member.'
              : 'Tidak ada member yang cocok dengan "$_searchQuery".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _members.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _members.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildMemberCard(_members[index]);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(PhosphorIconsRegular.warningCircle,
            size: 40, color: Colors.grey.shade500),
        const SizedBox(height: 12),
        Text(
          'Gagal memuat members.\n$_error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: _loadFirstPage,
            child: const Text('Coba lagi'),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(MemberModel member) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(member),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${member.username}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _buildMetaLine(member),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildFollowButton(member),
            ],
          ),
          if (member.bio.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              member.bio.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (member.socialLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final entry in member.socialLinks.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PhosphorIcon(
                      _socialIcon(entry.key),
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Baris "Joined 2 months ago • Last seen 2 minutes ago" seperti di web.
  Widget _buildMetaLine(MemberModel member) {
    final parts = <String>[
      if (member.joinedAt.isNotEmpty) 'Joined ${member.joinedAt}',
      if (member.lastActivity.isNotEmpty) 'Last seen ${member.lastActivity}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  •  '),
      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
      maxLines: 2,
    );
  }

  Widget _buildAvatar(MemberModel member) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: member.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(
                  member.avatarUrl,
                  headers: AuthService.imageAuthHeaders,
                )
              : null,
          child: member.avatarUrl.isEmpty
              ? Text(
                  _initials(member.displayName),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                )
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
    );
  }

  /// Inisial dari nama, mengikuti gaya avatar kosong di web ("AR", "SP").
  static String _initials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Widget _buildFollowButton(MemberModel member) {
    // Diri sendiri tidak perlu tombol follow (web juga menyembunyikannya).
    if (member.username.isNotEmpty &&
        AuthService.userSlug != null &&
        member.username == AuthService.userSlug) {
      return const SizedBox.shrink();
    }

    final following = member.isFollowed;
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () => _onFollowPressed(member),
        style: OutlinedButton.styleFrom(
          backgroundColor: following ? _kAccent : Colors.white,
          side: const BorderSide(color: _kAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: TextStyle(
            color: following ? Colors.white : _kAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static IconData _socialIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'linkedin':
        return PhosphorIconsRegular.linkedinLogo;
      case 'facebook':
        return PhosphorIconsRegular.facebookLogo;
      case 'instagram':
        return PhosphorIconsRegular.instagramLogo;
      case 'twitter':
      case 'x':
        return PhosphorIconsRegular.twitterLogo;
      case 'youtube':
        return PhosphorIconsRegular.youtubeLogo;
      case 'github':
        return PhosphorIconsRegular.githubLogo;
      case 'tiktok':
        return PhosphorIconsRegular.tiktokLogo;
      default:
        return PhosphorIconsRegular.globe;
    }
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
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search Members...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const PhosphorIcon(
                PhosphorIconsRegular.magnifyingGlass,
                color: Colors.grey,
                size: 20,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
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
                borderSide: const BorderSide(color: _kAccent),
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

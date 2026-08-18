import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/member_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Filter Active/Pending/Blocked, khusus admin — lihat [_buildStatusFilter].
  /// Kosong berarti semua status, sama seperti sebelum filter ini ada.
  String _statusFilter = '';

  /// Urutan tampilan, dipilih lewat dropdown "Sort by:" — sortnya LOKAL
  /// (di antara member yang sudah termuat), bukan lewat server: endpoint
  /// `/members` belum terverifikasi mendukung parameter urutan apa pun
  /// (beda dari `search`/`status` yang sudah dikonfirmasi lewat cURL), jadi
  /// mengikuti pola yang sama dengan `_sortBy` di Courses/Spaces.
  String _sortBy = 'Last Activity';
  static const List<String> _sortOptions = [
    'Last Activity',
    'Display Name',
    'Joining Date',
  ];

  /// Dropdown sort kustom (bukan `PopupMenuButton` bawaan) — dipakai supaya
  /// menunya bisa benar-benar di-blur (`BackdropFilter`), yang tidak
  /// didukung `PopupMenuButton`. `_sortMenuLink` menempelkan overlay ini
  /// tepat di bawah tombol "Sort by:" lewat `CompositedTransformFollower`.
  final LayerLink _sortMenuLink = LayerLink();
  OverlayEntry? _sortMenuEntry;

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
    _closeSortMenu();
    super.dispose();
  }

  void _closeSortMenu() {
    _sortMenuEntry?.remove();
    _sortMenuEntry = null;
  }

  void _toggleSortMenu(BuildContext context) {
    if (_sortMenuEntry != null) {
      _closeSortMenu();
      return;
    }
    final overlay = Overlay.of(context);
    _sortMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Lapisan transparan penuh layar: tap di luar menu menutupnya.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeSortMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _sortMenuLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in _sortOptions)
                            InkWell(
                              onTap: () {
                                _closeSortMenu();
                                _onSortChanged(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: option == _sortBy
                                        ? _kAccent
                                        : Colors.black87,
                                    fontWeight: option == _sortBy
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_sortMenuEntry!);
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
      final page = await ApiService.fetchMembers(
        search: _searchQuery,
        page: 1,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(page.members);
        _applySort();
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
      final page = await ApiService.fetchMembers(
        search: _searchQuery,
        page: _nextPage,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _members.addAll(page.members);
        _applySort();
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

  void _onStatusFilterChanged(String status) {
    if (status == _statusFilter) return;
    setState(() => _statusFilter = status);
    _loadFirstPage();
  }

  void _onSortChanged(String sortBy) {
    if (sortBy == _sortBy) return;
    setState(() {
      _sortBy = sortBy;
      _applySort();
    });
  }

  /// Urutkan [_members] di tempat sesuai [_sortBy]. Terbaru/A-Z duluan untuk
  /// ketiga opsi, meniru urutan default web.
  void _applySort() {
    switch (_sortBy) {
      case 'Display Name':
        _members.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      case 'Joining Date':
        _members.sort(
          (a, b) => _parseDate(b.joinedAt).compareTo(_parseDate(a.joinedAt)),
        );
      case 'Last Activity':
      default:
        _members.sort(
          (a, b) =>
              _parseDate(b.lastActivity).compareTo(_parseDate(a.lastActivity)),
        );
    }
  }

  /// Nilainya bisa berupa timestamp mentah (mis. "2026-07-21 13:42:26") atau
  /// sudah teks relatif dari server — kalau tidak bisa di-parse, dianggap
  /// paling lama supaya tidak mengacaukan urutan yang bisa di-parse.
  static DateTime _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(value.replaceFirst(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _onFollowPressed(MemberModel member) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index == -1) return;

    final wantFollow = !_members[index].isFollowed;
    // Optimistic update supaya tombol terasa responsif.
    setState(
      () => _members[index] = _copyWithFollow(_members[index], wantFollow),
    );

    final ok = await ApiService.toggleFollowMember(
      member.id,
      follow: wantFollow,
    );
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _members[index] = _copyWithFollow(_members[index], !wantFollow),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wantFollow
                ? 'Gagal mengikuti member.'
                : 'Gagal berhenti mengikuti.',
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
    // Latar glassmorphism — palet & orb sama persis dengan
    // SpacesListScreen/HomeScreen/CoursesListScreen supaya konsisten antar
    // tab. Header/search bar/body di bawahnya (fetch/pagination/follow/dst)
    // TIDAK diubah logikanya sama sekali, cuma dipindah ke dalam Stack ini.
    //
    // MainShell memakai `extendBodyBehindAppBar: true` supaya
    // TitcAppBar(glass: true) bisa nge-blur latar ini — tanpa offset ini,
    // header akan mulai dari belakang app bar (tertutup).
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          // Header judul/search/sort ikut scroll bersama daftar (BUKAN
          // pinned) — cuma latarnya dibuat menyatu dengan halaman (putih
          // polos, tanpa kartu kaca/blur/shadow terpisah).
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: topInset)),
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_buildHeader(), _buildSearchBar()],
                    ),
                  ),
                  ..._buildBodySlivers(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _headerHeight = 66;

  /// Header Members — menyatu dengan latar putih halaman (bukan lagi kartu
  /// kaca melayang), ikut scroll bersama daftar seperti bagian lain dari
  /// halaman. Judul & filter status admin tidak diubah logikanya.
  Widget _buildHeader() {
    // Judul mengikuti web: "All Members (2,256)". Angka baru ditampilkan
    // setelah data pertama masuk supaya tidak sempat terlihat "(0)".
    final title = _total > 0
        ? 'All Members (${_formatCount(_total)})'
        : 'All Members';
    return Container(
      width: double.infinity,
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      // Filter status admin (dropdown Active/Pending/Blocked) SEMENTARA
      // dilepas dari sini — dikonfirmasi lewat debug bahwa kehadirannya
      // di Row ini (Flexible di dalam Flexible/DropdownButton) membuat
      // SELURUH header gagal ter-render (bukan cuma dropdown-nya, tapi
      // judul "All Members" di sebelahnya ikut hilang total) — kemungkinan
      // gagal LAYOUT (bukan exception biasa, sudah dicoba try-catch di
      // sekitar build-nya, tidak tertangkap). Perlu investigasi terpisah
      // sebelum dikembalikan.
      child: Center(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
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

  List<Widget> _buildBodySlivers() {
    if (_isLoadingFirstPage) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [_buildErrorState()];
    }

    if (_members.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Belum ada member.'
                  : 'Tidak ada member yang cocok dengan "$_searchQuery".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        sliver: SliverList.separated(
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
      ),
    ];
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            const Icon(
              PhosphorIconsRegular.warningCircle,
              size: 40,
              color: Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat members.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                onPressed: _loadFirstPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                ),
                child: const Text('Coba lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(MemberModel member) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: member.username.isNotEmpty
                ? () => _openMemberProfile(member)
                : null,
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                            padding: const EdgeInsets.only(right: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () =>
                                  _openSocialLink(entry.key, entry.value),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: PhosphorIcon(
                                  _socialIcon(entry.key),
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Buka profil member di WebView — URL profil FCOM: `/portal/u/{username}`.
  /// Pakai AuthenticatedWebViewScreen agar CSS-nya tidak menyembunyikan
  /// nav-tab profil (About/Posts/Spaces/Courses) yang di SpaceWebViewScreen
  /// ikut ter-hidden bersama `.fcom_desktop_only`.
  void _openMemberProfile(MemberModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthenticatedWebViewScreen(
          title: member.displayName,
          url: 'https://titc.or.id/portal/u/${member.username}',
          extraCss: _memberProfileCss,
        ),
      ),
    );
  }

  /// CSS khusus halaman profil member di Fluent Community.
  /// Menyembunyikan top-nav FCOM, sidebar kiri, footer WP,
  /// tapi MEMPERTAHANKAN tab profil (About/Posts/Spaces/Courses)
  /// dan kolom konten utama agar dapat di-scroll dan diklik.
  static const String _memberProfileCss = '''
    /* Sembunyikan top-nav FCOM */
    .fcom_top_menu, .fcom_mobile_menu, .fcom_space_opener_btn {
      display: none !important;
    }
    /* Sembunyikan sidebar kiri (daftar spaces) */
    .spaces, .space_contents, #fluent_community_sidebar_menu,
    .fcom_sidebar_wrap, .fcom_side_footer, .space_opener,
    aside.el-aside:not(.fcom_resp_side) {
      display: none !important;
      width: 0 !important;
    }
    /* Sembunyikan header & footer WordPress */
    header, .site-header, #masthead, footer, .site-footer,
    #colophon, .bb-mobile-panel, .bb-mobile-header {
      display: none !important;
    }
    /* Hapus padding-top sisa dari top-menu yang sudah disembunyikan */
    body {
      padding-top: 0 !important;
      margin-top: 0 !important;
      overflow-x: hidden !important;
      background: #f5f6f8 !important;
    }
    /* Buat semua wrapper jadi full-width */
    .fcom_wrap, .fluent_com, .fhr_content, #fluent_comminity_body, .fhr_wrap {
      max-width: 100% !important;
      width: 100% !important;
      padding: 0 !important;
      margin: 0 !important;
      box-sizing: border-box !important;
    }
    .el-container {
      display: flex !important;
      flex-direction: column !important;
      width: 100% !important;
    }
    .el-main {
      width: 100% !important;
      padding: 0 !important;
      overflow: visible !important;
    }
    /* Profil: banner foto cover */
    .fcom_cover_photo_wrap {
      width: 100% !important;
      max-height: 160px !important;
      overflow: hidden !important;
    }
    /* Konten profil utama */
    .fcom_profile_wrap, .fcom_profile_content {
      width: 100% !important;
      max-width: 100% !important;
      padding: 0 12px 80px !important;
      box-sizing: border-box !important;
    }
    /* Tab navigasi profil (About/Posts/Spaces/Courses) — JANGAN disembunyikan */
    .fcom_profile_nav, .fcom_profile_tabs, .fcom-tabs {
      display: flex !important;
      overflow-x: auto !important;
      -webkit-overflow-scrolling: touch !important;
    }
    /* Kembalikan button ke inline agar tombol Follow/Message tidak full-width */
    button {
      width: auto !important;
      display: inline-flex !important;
      margin-top: 0 !important;
    }
    /* Right sidebar (Recent Activities) tampil di bawah konten utama */
    .fcom_resp_side, aside.fcom_resp_side {
      display: block !important;
      width: 100% !important;
    }
  ''';

  /// Baris "Joined 2 months ago • Last seen 2 minutes ago" seperti di web.
  Widget _buildMetaLine(MemberModel member) {
    final joined = _humanizeTime(member.joinedAt);
    final lastSeen = _humanizeTime(member.lastActivity);
    final parts = <String>[
      if (joined.isNotEmpty) 'Joined $joined',
      if (lastSeen.isNotEmpty) 'Last seen $lastSeen',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  •  '),
      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
      maxLines: 2,
    );
  }

  /// Ubah timestamp API (mis. "2026-07-21 13:42:26") jadi teks relatif ala
  /// web ("15 days ago"). Kalau nilainya memang sudah berupa teks relatif
  /// dari server, dipakai apa adanya.
  static String _humanizeTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;

    final diff = DateTime.now().difference(parsed);
    if (diff.isNegative) return 'just now';

    if (diff.inSeconds < 60) return 'a few seconds ago';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
    final years = (diff.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
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
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: () => _onFollowPressed(member),
            style: OutlinedButton.styleFrom(
              backgroundColor: following
                  ? _kAccent.withValues(alpha: 0.08)
                  : _kAccent,
              side: BorderSide(
                color: following ? _kAccent.withValues(alpha: 0.4) : _kAccent,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              following ? 'Following' : 'Follow',
              style: TextStyle(
                color: following ? _kAccent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Buka tautan sosial di browser/aplikasi luar. Sengaja tidak dibuka di
  /// WebView internal karena WebView di app ini menyuntikkan CSS khusus
  /// portal FCOM yang akan merusak tampilan situs luar seperti LinkedIn.
  Future<void> _openSocialLink(String provider, String rawValue) async {
    final url = _normalizeSocialUrl(provider, rawValue);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tautan $provider tidak valid: "$rawValue"')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak bisa membuka $url')));
    }
  }

  /// FCOM sering menyimpan profil sosial sebagai **username saja**
  /// (mis. `titc.indonesia`) atau domain tanpa skema (`www.instagram.com/x`),
  /// bukan URL lengkap. Fungsi ini melengkapinya jadi URL yang bisa dibuka.
  static String? _normalizeSocialUrl(String provider, String rawValue) {
    var value = rawValue.trim();
    if (value.isEmpty) return null;

    // Sudah URL lengkap -> pakai apa adanya.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    // Domain tanpa skema (www.instagram.com/..., instagram.com/...).
    if (value.contains('.') && value.contains('/')) {
      return 'https://$value';
    }
    if (value.startsWith('www.')) return 'https://$value';

    // Sisanya dianggap username/handle. Buang '@' dan '/' di depan.
    value = value.replaceFirst(RegExp(r'^[@/]+'), '');
    if (value.isEmpty) return null;

    switch (provider.toLowerCase()) {
      case 'instagram':
        return 'https://www.instagram.com/$value';
      case 'linkedin':
        // Handle personal maupun company page sama-sama valid lewat /in/.
        return 'https://www.linkedin.com/in/$value';
      case 'facebook':
        return 'https://www.facebook.com/$value';
      case 'twitter':
      case 'x':
        return 'https://x.com/$value';
      case 'youtube':
        return 'https://www.youtube.com/@$value';
      case 'github':
        return 'https://github.com/$value';
      case 'tiktok':
        return 'https://www.tiktok.com/@$value';
      default:
        // Provider tidak dikenal & bukan URL: kalau mirip domain, coba buka.
        return value.contains('.') ? 'https://$value' : null;
    }
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Members...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              PhosphorIconsRegular.x,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: _kAccent, width: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerRight,
              // Dropdown kaca kustom (bukan `PopupMenuButton`) — lihat
              // `_toggleSortMenu`/`_sortMenuLink` untuk alasannya:
              // `PopupMenuButton` tidak mendukung `BackdropFilter` sungguhan.
              // `CompositedTransformTarget` menandai posisi tombol ini supaya
              // overlay-nya (di `_toggleSortMenu`) bisa menempel tepat di
              // bawahnya lewat `CompositedTransformFollower`.
              child: CompositedTransformTarget(
                link: _sortMenuLink,
                child: GestureDetector(
                  onTap: () => _toggleSortMenu(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort by: ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _sortBy,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretDown,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Filter status member dipindah ke SectionHeader (Top Tabs)
        ],
      ),
    );
  }

  /// Dropdown filter status member — dulu dipasang di [_buildHeader] lewat
  /// [AdminOnly], SEMENTARA DILEPAS dari sana (lihat catatan di
  /// [_buildHeader]) karena kehadirannya di situ membuat seluruh header
  /// gagal ter-render. Fungsinya sendiri (nilai cocok dengan parameter
  /// `status` di [ApiService.fetchMembers]) masih utuh, tinggal dipasang
  /// ulang di tempat lain setelah akar masalahnya ditemukan.
  Widget _buildStatusFilterRow() {
    const options = <(String, String)>[
      ('', 'All Members'),
      ('active', 'Active'),
      ('pending', 'Pending'),
      ('blocked', 'Blocked'),
    ];

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _statusFilter,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kAccent,
        ),
        selectedItemBuilder: (_) => [
          for (final (_, label) in options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kAccent,
                ),
              ),
            ),
        ],
        items: [
          for (final (value, label) in options)
            DropdownMenuItem<String>(value: value, child: Text(label)),
        ],
        onChanged: (v) => _onStatusFilterChanged(v ?? ''),
      ),
    );
  }
}

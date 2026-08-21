import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/constants/fcom_post_dialog_css.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:magang_titc/services/portal_navigator.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import '../../../models/activity_model.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../spaces/space_webview_screen.dart';

/// Satu fitur berbentuk ikon di bawah header Announcement.
class _QuickLink {
  /// Tujuannya halaman WordPress biasa.
  const _QuickLink.page(this.asset, this.label, this.url) : spaceTitle = null;

  /// Tujuannya Space di portal FCOM. Yang disimpan judulnya, bukan slug —
  /// slug aslinya dicari lewat API saat diketuk (lihat [PortalNavigator]).
  const _QuickLink.space(this.asset, this.label, this.spaceTitle) : url = null;

  final String asset;
  final String label;
  final String? url;
  final String? spaceTitle;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ActivityModel> _activities = [];
  final ScrollController _scrollController = ScrollController();

  /// Feed yang tampil ter-like, dipakai untuk optimistic UI update tombol
  /// Like — lihat [_toggleLike]. Diisi dari DUA sumber:
  ///
  /// 1. Cache lokal persisten ([_seedLikedFromLocalCache],
  ///    `ApiService.getLikedFeedIdsCache`) — sumber UTAMA & yang paling bisa
  ///    diandalkan, karena field "sudah di-like" dari server (`/feeds`)
  ///    belum diketahui namanya dan ternyata tidak konsisten. Inilah yang
  ///    membuat status like tetap benar setelah hot restart.
  /// 2. `ActivityModel.isLikedByMe` dari server ([_seedLikedFromServer]) —
  ///    sumber TAMBAHAN, berguna kalau field-nya kebetulan cocok atau akun
  ///    yang sama login di perangkat lain (cache lokal tidak ikut).
  final Set<int> _likedFeedIds = {};

  /// Tandai feed yang tersimpan LOKAL di perangkat sebagai sudah di-like —
  /// lihat catatan lengkap di [_likedFeedIds]. Dipanggil sekali di
  /// [initState], berjalan independen dari pemuatan feed itu sendiri.
  Future<void> _seedLikedFromLocalCache() async {
    final ids = await ApiService.getLikedFeedIdsCache();
    if (!mounted || ids.isEmpty) return;
    setState(() => _likedFeedIds.addAll(ids));
  }

  /// Tandai feed yang menurut SERVER sudah di-like user saat ini. Dipanggil
  /// setiap kali daftar feed baru masuk (initial load, refresh, load more).
  void _seedLikedFromServer(List<ActivityModel> activities) {
    for (final activity in activities) {
      if (activity.isLikedByMe) _likedFeedIds.add(activity.id);
    }
  }

  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _seedLikedFromLocalCache();
    final cached = ApiService.cachedActivities;
    if (cached != null) {
      // Tampilkan data lama dulu supaya tidak loading dari nol tiap kali
      // tab ini dibuka lagi, lalu diam-diam refresh di belakang layar.
      _activities.addAll(cached);
      _seedLikedFromServer(cached);
      _isLoadingFirstPage = false;
      _nextPage = 2;
      ApiService.fetchActivities()
          .then((fresh) {
            if (!mounted) return;
            setState(() {
              _activities
                ..clear()
                ..addAll(fresh);
              _seedLikedFromServer(fresh);
              _nextPage = 2;
              _hasMore = fresh.length >= ApiService.feedsPerPage;
            });
          })
          .catchError((_) {});
    } else {
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      final page = await ApiService.fetchActivitiesPage(page: 1);
      if (!mounted) return;
      setState(() {
        _activities
          ..clear()
          ..addAll(page);
        _seedLikedFromServer(page);
        _nextPage = 2;
        _hasMore = page.length >= ApiService.feedsPerPage;
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
      final page = await ApiService.fetchActivitiesPage(page: _nextPage);
      if (!mounted) return;
      setState(() {
        _activities.addAll(page);
        _seedLikedFromServer(page);
        _nextPage += 1;
        _hasMore = page.length >= ApiService.feedsPerPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Gagal memuat halaman tambahan tidak boleh menghapus feed yang sudah
      // tampil — cukup hentikan pemuatan berikutnya.
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  /// Menu "⋮" di header Feed (admin-only, lihat [AdminOnly] di atas) —
  /// dulu tombol mati (`onPressed: () {}`). Web-nya sendiri dua langkah:
  /// klik "⋮" dulu untuk buka dropdown, baru klik "Welcome Banner"/
  /// "Manage Links" di dalamnya. Karena pemicunya ikon polos tanpa teks,
  /// dipakai [WebViewClickHelper.clickDotMenuThenText] (lewat
  /// `autoClickDotMenuThenText`) — bukan `autoClickText` biasa yang cuma
  /// bisa cari 1 elemen berteks.
  void _openFeedManageMenu(String menuItemText) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthenticatedWebViewScreen(
          title: menuItemText,
          url: 'https://titc.or.id/portal/',
          autoClickDotMenuThenText: menuItemText,
          extraCss: _feedManageDialogCss,
        ),
      ),
    );
  }

  /// "Welcome Banner" & "Manage Links" ternyata bukan modal/dialog sama
  /// sekali — Vue router pindah ke HALAMAN baru di dalam SPA yang sama
  /// (dikonfirmasi: MODAL_PROBE selalu 0x0 untuk semua kandidat
  /// `.el-dialog`/`.el-drawer`/dst, karena memang tidak ada modal yang
  /// perlu dicari). CSS dasar `AuthenticatedWebViewScreen` sudah cukup
  /// untuk merapikan halaman itu; hanya baris "Manage Links" (badge
  /// "enabled" + tombol Edit/Delete) yang berantakan, dikonfirmasi lewat
  /// ROW_PROBE: badge `.el-tag` ternyata menyatu di dalam paragraf judul
  /// (`.fcom_heading_item`, lebar cuma 174px), jadi judul panjang + badge
  /// berebut ruang sempit. Baris utamanya (`.fcom_section_item`) dipaksa
  /// jadi flex row rapi, judul dikasih ruang fleksibel, badge & tombol
  /// Edit/Delete dikumpulkan tetap ringkas di ujung.
  static const String _feedManageDialogCss = '''
    button {
      width: auto !important;
      display: inline-flex !important;
      margin-top: 0 !important;
    }
    .fcom_section_item {
      display: flex !important;
      align-items: center !important;
      flex-wrap: nowrap !important;
      gap: 8px !important;
      padding: 10px 8px !important;
    }
    .fcom_section_item_title {
      flex: 1 1 auto !important;
      min-width: 0 !important;
    }
    .fcom_heading_item {
      display: flex !important;
      align-items: center !important;
      flex-wrap: wrap !important;
      gap: 6px !important;
      margin: 0 !important;
    }
    .fcom_section_item .el-button {
      width: auto !important;
      flex-shrink: 0 !important;
      padding: 6px 10px !important;
      font-size: 12px !important;
      margin: 0 !important;
    }
  ''';

  /// Like/unlike optimistic: tampilan berubah seketika, lalu dikirim ke
  /// server. Kalau server menolak, tampilan dikembalikan seperti semula
  /// (revert) supaya app tidak pernah berbohong soal status like sesungguhnya
  /// — inilah yang membuat like "terkoneksi realtime dengan web", bukan
  /// cuma efek visual lokal.
  Future<void> _toggleLike(ActivityModel activity) async {
    final wasLiked = _likedFeedIds.contains(activity.id);
    final wantLike = !wasLiked;

    setState(() {
      if (wantLike) {
        _likedFeedIds.add(activity.id);
      } else {
        _likedFeedIds.remove(activity.id);
      }
    });

    final ok = await ApiService.toggleFeedLike(activity.id, like: wantLike);
    if (!mounted || ok) return;

    setState(() {
      if (wasLiked) {
        _likedFeedIds.add(activity.id);
      } else {
        _likedFeedIds.remove(activity.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wantLike ? 'Gagal menyukai post.' : 'Gagal batal menyukai post.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Latar glassmorphism — palet & orb sama persis dengan SpacesListScreen
    // supaya berpindah tab Home <-> Spaces terasa konsisten. Konten di
    // bawahnya (RefreshIndicator/ListView/fetch/handler/urutan/padding)
    // TIDAK diubah sama sekali — header "Announcement" TETAP ikut scroll
    // bersama konten seperti semula, bukan dijadikan bar melayang di atas
    // (sempat dicoba, ternyata mengubah posisi konten dan diminta dibalik).
    //
    // MainShell memakai `extendBodyBehindAppBar: true` supaya
    // TitcAppBar(glass: true) bisa nge-blur latar ini — tanpa offset ini,
    // konten akan mulai dari belakang app bar (tertutup).
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 16),
                children: [
                  // 1. Promo Banner (Mock)
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade900,
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                          'https://titc.or.id/wp-content/uploads/2025/07/cropped-TORC.png', // Placeholder
                          headers: AuthService.imageAuthHeaders,
                          maxWidth: 1080,
                          maxHeight: 400,
                        ),
                        fit: BoxFit.cover,
                        colorFilter: const ColorFilter.mode(
                          Colors.black54,
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Header Feed — ikut scroll bersama konten, posisi &
                  // urutan sama seperti sebelum restyle kaca.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Announcement',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      AdminOnly(
                        builder: (context) => PopupMenuButton<String>(
                          icon: PhosphorIcon(
                            PhosphorIconsRegular.dotsThreeVertical,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          onSelected: _openFeedManageMenu,
                          offset: const Offset(0, 36),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (context) {
                            final iconColor = Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6);
                            return [
                              PopupMenuItem(
                                value: 'Welcome Banner',
                                height: 44,
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsRegular.image,
                                      size: 18,
                                      color: iconColor,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Welcome Banner'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Manage Links',
                                height: 44,
                                child: Row(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsRegular.link,
                                      size: 18,
                                      color: iconColor,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Manage Links'),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  _buildQuickLinks(context),

                  // 5. Activity Feed — dimuat bertahap (infinite scroll). `/feeds`
                  // cuma mengembalikan sejumlah item per panggilan, jadi feed di web
                  // yang jumlahnya lebih banyak baru bisa disamakan kalau app terus
                  // meminta halaman berikutnya saat user scroll ke bawah.
                  if (_isLoadingFirstPage)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Center(
                      child: Text(
                        'Error: $_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    )
                  else if (_activities.isEmpty)
                    Center(
                      child: Text(
                        'Belum ada aktivitas.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else ...[
                    for (final activity in _activities) ...[
                      _buildActivityCard(activity),
                      const SizedBox(height: 12),
                    ],
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Catatan URL yang mudah salah:
  /// - Daftar Tes TOEFL ITP Resmi ETS memakai landing page Fluent Forms
  ///   (`?ff_landing=21`), bukan halaman biasa seperti `/toefl-itp`.
  ///   Dikonfirmasi langsung oleh user.
  /// - Daftar Preparation Test Online mengarah ke
  ///   `/institutional-preparation-test/` (diubah dari `?ff_landing=15`).
  /// - Certificate Tracking mengarah ke `/certificate-distribution/`;
  ///   `/certificate-tracking/` tidak ada (404).
  static const List<_QuickLink> _quickLinks = [
    _QuickLink.page(
      'assets/images/toefl-itp.png',
      'Daftar Tes TOEFL ITP Resmi ETS',
      'https://titc.or.id/?ff_landing=21',
    ),
    _QuickLink.page(
      'assets/images/preptest.png',
      'Daftar Preparation Test Online',
      'https://titc.or.id/institutional-preparation-test/',
    ),
    _QuickLink.page(
      'assets/images/check-readiness.png',
      'Check Readiness',
      'https://titc.or.id/check-readiness/',
    ),
    _QuickLink.page(
      'assets/images/certificate-tracking.png',
      'Certificate Tracking',
      'https://titc.or.id/certificate-distribution/',
    ),
    _QuickLink.page(
      'assets/images/ept.png',
      'EPT Certificate Verification',
      'https://titc.or.id/certificate-verification/',
    ),
    _QuickLink.space('assets/images/free-placement.png', 'FREE Placement Test', 'FREE Placement Test'),
  ];

  Widget _buildQuickLinks(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _quickLinks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final link = _quickLinks[index];
            return InkWell(
              onTap: () => _onQuickLinkTap(link),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.onSurface.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: link.asset.endsWith('.svg')
                          ? SvgPicture.asset(link.asset)
                          : Image.asset(link.asset),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    link.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _onQuickLinkTap(_QuickLink link) {
    final url = link.url;
    if (url != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AuthenticatedWebViewScreen(url: url, title: link.label),
        ),
      );
      return;
    }
    // Space di portal: slug-nya dicari lewat judul, sama seperti menu drawer.
    PortalNavigator.openSpaceByTitle(
      navigator: Navigator.of(context),
      messenger: ScaffoldMessenger.of(context),
      title: link.spaceTitle!,
    );
  }

  void _openComments(ActivityModel activity) {
    if (activity.permalink == null || activity.permalink!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link komentar tidak tersedia.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpaceWebViewScreen(
          overrideUrl: activity.permalink!,
          title: 'Komentar',
          extraCss: kFcomPostDialogCss,
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    final isLiked = _likedFeedIds.contains(activity.id);
    // `activity.likeCount` datang dari server dan tidak berubah sendiri;
    // hasil like/unlike lokal ditambahkan di atasnya sebagai selisih, bukan
    // memutasi model.
    final displayedLikeCount = activity.likeCount + (isLiked ? 1 : 0);
    final likeColor = isLiked ? const Color(0xFFE0245E) : Colors.grey.shade600;

    // Seluruh kartu bisa diketuk untuk membuka post + komentar, meniru web.
    // Bungkus glass (ClipRRect+BackdropFilter) sama seperti kartu Space —
    // Card putih polos diganti kaca supaya konsisten dengan latar
    // berwarna, isinya (avatar/teks/tombol like/comment) tidak diubah
    // fungsinya sama sekali.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openComments(activity),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.06),
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
                                  maxWidth: 100,
                                  maxHeight: 100,
                                )
                              : null,
                          child: activity.avatarUrl.isEmpty
                              ? Text(activity.authorName[0])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.authorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              if (activity.date.isNotEmpty)
                                Text(
                                  activity.date.split('T')[0],
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      // Simple strip HTML
                      activity.content.replaceAll(RegExp(r'<[^>]*>'), ''),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // GestureDetector opaque: tombol Like ada DI DALAM kartu
                        // yang seluruhnya sudah bisa diketuk untuk buka komentar.
                        // Tanpa opaque + onTap sendiri di sini, tap like akan ikut
                        // "ditelan" InkWell kotak utama dan malah membuka komentar.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleLike(activity),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  isLiked
                                      ? PhosphorIconsFill.heart
                                      : PhosphorIconsRegular.heart,
                                  size: 20,
                                  color: likeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$displayedLikeCount',
                                  style: TextStyle(color: likeColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openComments(activity),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsRegular.chatCircle,
                                  size: 20,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${activity.commentCount}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}

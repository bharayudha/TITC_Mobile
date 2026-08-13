import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';
import 'package:magang_titc/services/portal_navigator.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import '../../../models/activity_model.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../spaces/space_webview_screen.dart';

/// Satu link cepat di bawah header Feed, meniru deretan link di Home web.
class _QuickLink {
  /// Tujuannya halaman WordPress biasa.
  const _QuickLink.page(this.emoji, this.label, this.url) : spaceTitle = null;

  /// Tujuannya Space di portal FCOM. Yang disimpan judulnya, bukan slug —
  /// slug aslinya dicari lewat API saat diketuk (lihat [PortalNavigator]).
  const _QuickLink.space(this.emoji, this.label, this.spaceTitle) : url = null;

  final String emoji;
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

  /// Feed yang di-like OLEH USER di sesi ini, dipakai untuk optimistic UI
  /// update tombol Like — lihat [_toggleLike]. `/feeds` tidak mengembalikan
  /// status "sudah di-like atau belum" per user, jadi status awal semua
  /// item selalu dianggap belum di-like (sama seperti tampilan awal
  /// sebelumnya, bukan regresi).
  final Set<int> _likedFeedIds = {};

  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final cached = ApiService.cachedActivities;
    if (cached != null) {
      // Tampilkan data lama dulu supaya tidak loading dari nol tiap kali
      // tab ini dibuka lagi, lalu diam-diam refresh di belakang layar.
      _activities.addAll(cached);
      _isLoadingFirstPage = false;
      _nextPage = 2;
      ApiService.fetchActivities().then((fresh) {
        if (!mounted) return;
        setState(() {
          _activities
            ..clear()
            ..addAll(fresh);
          _nextPage = 2;
          _hasMore = fresh.length >= ApiService.feedsPerPage;
        });
      }).catchError((_) {});
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
      SnackBar(content: Text(wantLike ? 'Gagal menyukai post.' : 'Gagal batal menyukai post.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
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
                ),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            child: const Center(
              child: Text(
                'COMING SOON\nTOEFL iBT',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Header Feed
          SectionHeader(
            title: 'Feed',
            trailing: IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.dotsThreeVertical, color: Colors.black54),
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 4),

          // 4. Deretan link cepat, mengikuti Home web: satu baris di bawah
          // header Feed yang bisa digulir mendatar.
          _buildQuickLinks(context),
          const SizedBox(height: 12),

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
            Center(child: Text('Error: $_error'))
          else if (_activities.isEmpty)
            const Center(child: Text('Belum ada aktivitas.'))
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
      '⭐',
      'Daftar Tes TOEFL ITP Resmi ETS',
      'https://titc.or.id/?ff_landing=21',
    ),
    _QuickLink.page(
      '⚡',
      'Daftar Preparation Test Online',
      'https://titc.or.id/institutional-preparation-test/',
    ),
    _QuickLink.page(
      '💻',
      'Check Readiness',
      'https://titc.or.id/check-readiness/',
    ),
    _QuickLink.page(
      '🎫',
      'Certificate Tracking',
      'https://titc.or.id/certificate-distribution/',
    ),
    _QuickLink.page(
      '✔️',
      'EPT Certificate Verification',
      'https://titc.or.id/certificate-verification/',
    ),
    _QuickLink.space('💡', 'FREE Placement Test', 'FREE Placement Test'),
  ];

  Widget _buildQuickLinks(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickLinks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final link = _quickLinks[index];
          return InkWell(
            onTap: () => _onQuickLinkTap(link),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Text(link.emoji, style: emojiStyle(size: 14)),
                  const SizedBox(width: 6),
                  Text(
                    link.label,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onQuickLinkTap(_QuickLink link) {
    final url = link.url;
    if (url != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AuthenticatedWebViewScreen(
            url: url,
            title: link.label,
          ),
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
          extraCss: _commentsExtraCss,
        ),
      ),
    );
  }

  /// Post + komentar dibuka lewat modal Element Plus (`.el-dialog` di dalam
  /// `.el-overlay`) di atas halaman Space. Tanpa CSS ini modalnya tampil
  /// sebagai kotak kecil melayang di atas latar gelap (persis versi
  /// desktop-nya) alih-alih memenuhi layar seperti halaman native.
  static const String _commentsExtraCss = '''
    .el-overlay {
      background: transparent !important;
      position: fixed !important;
      inset: 0 !important;
    }
    .el-overlay-dialog {
      padding: 0 !important;
      display: block !important;
    }
    .el-dialog {
      width: 100% !important;
      max-width: 100% !important;
      height: 100vh !important;
      max-height: 100vh !important;
      margin: 0 !important;
      border-radius: 0 !important;
      box-shadow: none !important;
      display: flex !important;
      flex-direction: column !important;
      box-sizing: border-box !important;
    }
    .el-dialog__header {
      flex: none !important;
      padding: 12px 16px !important;
    }
    .el-dialog__body {
      flex: 1 1 auto !important;
      overflow-y: auto !important;
      -webkit-overflow-scrolling: touch !important;
      padding: 12px 16px !important;
    }
    .el-dialog__footer {
      flex: none !important;
      padding: 12px 16px !important;
    }
    /* Aturan tombol full-width dari style dasar tidak cocok untuk modal ini:
       like/reply/emoji/kirim-gambar/post-comment harus tetap tombol kecil
       sejajar, bukan block penuh lebar layar. */
    .el-dialog button {
      width: auto !important;
      display: inline-flex !important;
      margin-top: 0 !important;
    }
    /* Style dasar SpaceWebViewScreen menyembunyikan .fcom_dot_menu secara
       total (opacity 0 + pointer-events none) supaya HANYA bisa dipicu
       lewat tombol "⋮" kustom di app bar Flutter -- itu didesain untuk
       SATU dot-menu per halaman Space. Tapi di modal komentar, kelas yang
       sama dipakai ulang untuk tombol "⋮" milik SETIAP komentar (punya
       sendiri maupun punya orang lain), jadi aturan sembunyi-total itu ikut
       mematikan semuanya. Kembalikan tampil & bisa diklik normal di sini.
    */
    .el-dialog .fcom_dot_menu {
      opacity: 1 !important;
      pointer-events: auto !important;
      position: static !important;
      top: auto !important;
      right: auto !important;
    }
  ''';

  Widget _buildActivityCard(ActivityModel activity) {
    final isLiked = _likedFeedIds.contains(activity.id);
    // `activity.likeCount` datang dari server dan tidak berubah sendiri;
    // hasil like/unlike lokal ditambahkan di atasnya sebagai selisih, bukan
    // memutasi model.
    final displayedLikeCount = activity.likeCount + (isLiked ? 1 : 0);
    final likeColor = isLiked ? const Color(0xFFE0245E) : Colors.grey.shade600;

    // Seluruh kartu bisa diketuk untuk membuka post + komentar, meniru web.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openComments(activity),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
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
                    backgroundImage: activity.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(activity.avatarUrl, headers: AuthService.imageAuthHeaders) : null,
                    child: activity.avatarUrl.isEmpty ? Text(activity.authorName[0]) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (activity.date.isNotEmpty)
                          Text(activity.date.split('T')[0], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                // Simple strip HTML
                activity.content.replaceAll(RegExp(r'<[^>]*>'), ''),
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
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                            size: 20,
                            color: likeColor,
                          ),
                          const SizedBox(width: 4),
                          Text('$displayedLikeCount', style: TextStyle(color: likeColor)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openComments(activity),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(PhosphorIconsRegular.chatCircle, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${activity.commentCount}', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

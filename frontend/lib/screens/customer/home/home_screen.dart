import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
import '../../../models/activity_model.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../spaces/space_webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ActivityModel>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    final cached = ApiService.cachedActivities;
    if (cached != null) {
      // Tampilkan data lama dulu supaya tidak loading dari nol tiap kali
      // tab ini dibuka lagi, lalu diam-diam refresh di belakang layar.
      _activitiesFuture = Future.value(cached);
      ApiService.fetchActivities()
          .then((fresh) {
            if (mounted) setState(() => _activitiesFuture = Future.value(fresh));
          })
          .catchError((_) {});
    } else {
      _activitiesFuture = ApiService.fetchActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _activitiesFuture = ApiService.fetchActivities();
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Shortcut Menus (Mock)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildShortcutItem('TOEFL ITP', PhosphorIconsRegular.fileText),
                _buildShortcutItem('Prep Test', PhosphorIconsRegular.desktop),
                _buildShortcutItem('Readiness', PhosphorIconsRegular.checkCircle),
                _buildShortcutItem('Tracking', PhosphorIconsRegular.mapPin),
                _buildShortcutItem('Placement', PhosphorIconsRegular.student),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 2. Promo Banner (Mock)
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
          const SizedBox(height: 8),
          
          // 4. Activity Feed (FutureBuilder)
          FutureBuilder<List<ActivityModel>>(
            future: _activitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Belum ada aktivitas.'));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final activity = snapshot.data![index];
                  return _buildActivityCard(activity);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem(String title, IconData icon) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            radius: 24,
            child: PhosphorIcon(icon, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
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
    return Card(
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
                PhosphorIcon(PhosphorIconsRegular.heart, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${activity.likeCount}', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
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
    );
  }
}

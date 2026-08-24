import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:magang_titc/screens/main_shell.dart';
import 'package:magang_titc/services/webview_click_helper.dart';
import 'package:magang_titc/services/webview_cookie_helper.dart';
import 'package:magang_titc/models/message_model.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/messages_service.dart';
import 'package:magang_titc/screens/customer/preparation_test/preparation_test_webview_screen.dart';
import 'package:magang_titc/screens/customer/messages/chat_detail_screen.dart';
import 'package:magang_titc/widgets/customer/customer_bottom_nav_bar.dart';
import 'package:magang_titc/widgets/customer/main_shell_glass_bar.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/services/theme_service.dart';
import 'package:magang_titc/widgets/shared/scroll_hide_controller.dart';

const Color _kAccent = Color(0xFF1E5AF5);

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final _searchController = TextEditingController();
  late Future<ChatThreadsResult> _threadsFuture;

  // Web-nya bisa buka/tutup tiap section (COMMUNITIES/GROUPS/DIRECT
  // MESSAGES) lewat panah di sebelah judulnya — defaultnya semua terbuka,
  // sama seperti tampilan app sebelum fitur ini ditambahkan.
  bool _communitiesExpanded = true;
  bool _groupsExpanded = true;
  bool _directExpanded = true;

  // Sama seperti `MainShell._scrollHide` — lihat [ScrollHideController]
  // untuk aturan threshold jaraknya.
  final _scrollHide = ScrollHideController();

  @override
  void initState() {
    super.initState();
    _threadsFuture = MessagesService.fetchThreads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollHide.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreparationTestWebviewScreen()),
      );
      return;
    }
    // Kembali ke shell utama pada tab yang dipilih, tanpa menumpuk halaman.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(initialIndex: index)),
      (route) => false,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _threadsFuture = MessagesService.fetchThreads();
    });
    await _threadsFuture;
  }

  /// Tampilkan compose "New message" sebagai dialog MENGAMBANG di atas
  /// layar Messages (persis seperti web), bukan halaman baru. Isinya WebView
  /// ke `/portal/chat` dengan tombol "New message" diklik otomatis — belum
  /// ada endpoint "buat thread baru" yang terverifikasi lewat cURL, jadi
  /// alurnya diserahkan ke JS/UI asli web, hanya wadahnya (dialog kecil,
  /// bukan Scaffold penuh) yang native.
  void _openNewMessage() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _NewMessageDialog(),
    );
  }

  void _openThread(ChatThreadModel thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          threadId: thread.id,
          title: thread.title,
          avatarUrl: thread.avatarUrl,
          canSendMessage: thread.canSendMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Glassmorphism — palet/orb & mekanisme app bar+bottom nav kaca sama
    // persis dengan MainShell (lihat main_shell_glass_bar.dart untuk alasan
    // kenapa bar-nya widget body biasa, bukan Scaffold.appBar).
    final topInset = MainShellGlassBar.heightOf(context);
    return GlassContentAwareScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        drawer: const SideDrawer(),
        body: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            Positioned.fill(
              child: GlassContentAwareContent(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _scrollHide.onNotification,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topInset),
                          // Blok header + search — kaca, mengikuti resep header
                          // Spaces/Courses/Members.
                          ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.7),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.06),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildMessagesHeader(),
                                    _buildSearchBar(),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FutureBuilder<ChatThreadsResult>(
                            future: _threadsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Center(
                                    child: Text(
                                      'Gagal memuat: ${snapshot.error}',
                                    ),
                                  ),
                                );
                              }

                              final result = snapshot.data!;
                              final query = _searchController.text
                                  .trim()
                                  .toLowerCase();
                              final communities = _filterThreads(
                                result.communityThreads,
                                query,
                              );
                              // Dulu digabung jadi satu section "DIRECT MESSAGES" —
                              // padahal `result.groupThreads` sudah terpisah sendiri
                              // dari `result.directThreads` di model. Web-nya punya 3
                              // section (COMMUNITIES/GROUPS/DIRECT MESSAGES), bukan 2.
                              final groups = _filterThreads(
                                result.groupThreads,
                                query,
                              );
                              final directs = _filterThreads(
                                result.directThreads,
                                query,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionLabel(
                                    'COMMUNITIES',
                                    expanded: _communitiesExpanded,
                                    onToggle: () => setState(
                                      () => _communitiesExpanded =
                                          !_communitiesExpanded,
                                    ),
                                  ),
                                  if (_communitiesExpanded) ...[
                                    const SizedBox(height: 12),
                                    _buildThreadSection(
                                      communities,
                                      'Belum ada percakapan komunitas.',
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionLabel(
                                    'GROUPS',
                                    expanded: _groupsExpanded,
                                    onToggle: () => setState(
                                      () => _groupsExpanded = !_groupsExpanded,
                                    ),
                                  ),
                                  if (_groupsExpanded) ...[
                                    const SizedBox(height: 12),
                                    _buildThreadSection(
                                      groups,
                                      'Belum ada grup.',
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionLabel(
                                    'DIRECT MESSAGES',
                                    expanded: _directExpanded,
                                    onToggle: () => setState(
                                      () => _directExpanded = !_directExpanded,
                                    ),
                                  ),
                                  if (_directExpanded) ...[
                                    const SizedBox(height: 12),
                                    _buildThreadSection(
                                      directs,
                                      'Belum ada pesan langsung.',
                                    ),
                                  ],
                                  // Cukup tinggi untuk melewati bottom nav bar
                                  // kaca — `extendBody: true` membuat body
                                  // meluas ke belakangnya, jadi tanpa ini item
                                  // "Direct Messages" paling bawah tertutup
                                  // nav bar walau sudah discroll mentok.
                                  SizedBox(
                                    height:
                                        kBottomNavBarContentHeight +
                                        14 +
                                        MediaQuery.of(context).padding.bottom,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bar "TITC Indonesia" versi kaca, dengan tap-judul-untuk-pulang
            // aktif (layar ini di-push di atas MainShell).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MainShellGlassBar(
                homeTapEnabled: true,
                visible: _scrollHide.visible,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          // Samakan dengan MainShell — tanpa ini dock nempel persis di batas
          // bawah body Scaffold, beda posisi dengan tab Home/Spaces/dst.
          padding: const EdgeInsets.only(bottom: 14),
          child: BottomNavBar(
            currentIndex: -1,
            onTap: _onNavTap,
            isSpacesTab: true,
          ),
        ),
      ),
    );
  }

  List<ChatThreadModel> _filterThreads(
    List<ChatThreadModel> threads,
    String query,
  ) {
    if (query.isEmpty) return threads;
    return threads.where((t) => t.title.toLowerCase().contains(query)).toList();
  }

  Widget _buildMessagesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MESSAGES',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.paperPlaneTilt,
                  color: _kAccent,
                ),
                tooltip: 'New message',
                onPressed: _openNewMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search conversations',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(
                PhosphorIconsRegular.magnifyingGlass,
                color: Colors.grey.shade600,
              ),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
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
    );
  }

  Widget _buildSectionLabel(
    String label, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            // Panah menghadap bawah saat terbuka, ke kanan saat tertutup
            // — meniru gaya chevron accordion di web.
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadSection(
    List<ChatThreadModel> threads,
    String emptyMessage,
  ) {
    if (threads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            emptyMessage,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final thread in threads) ...[
            _buildThreadTile(thread),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildThreadTile(ChatThreadModel thread) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openThread(thread),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: thread.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(
                            thread.avatarUrl,
                            headers: AuthService.imageAuthHeaders,
                            maxWidth: 96,
                            maxHeight: 96,
                          )
                        : null,
                    child: thread.avatarUrl.isEmpty
                        ? Text(
                            thread.title.isNotEmpty
                                ? thread.title[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: Colors.grey.shade700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (thread.lastMessagePreview.isNotEmpty)
                          Text(
                            thread.lastMessagePreview,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (thread.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5AF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${thread.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog mengambang berisi WebView compose "New message" — dibuat berdiri
/// sendiri (bukan lewat `AuthenticatedWebViewScreen`) karena widget itu
/// selalu membungkus dengan `Scaffold` + `AppBar` sendiri untuk kebutuhan
/// halaman penuh; di sini yang dibutuhkan justru sebaliknya, WebView polos
/// di dalam kartu kecil mengambang seperti modal aslinya di web.
///
/// Fitur messaging FCOM ternyata komponen Svelte custom (BEM naming:
/// `new-message-modal__header`, dst), BUKAN Element Plus (`.el-dialog`/
/// `.el-drawer`) seperti bagian portal lain — jadi seluruh CSS/JS di sini
/// ditarget khusus untuk struktur itu, bukan pola admin drawer biasa.
class _NewMessageDialog extends StatefulWidget {
  const _NewMessageDialog();

  @override
  State<_NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends State<_NewMessageDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Kartu modal aslinya jauh lebih pendek daripada tebakan awal — diukur
  // dinamis dari tinggi kartu sungguhan (lihat channel `MODAL_HEIGHT`).
  // 420 cuma nilai awal sebelum pengukuran pertama tiba. TIDAK dikunci ke
  // satu nilai (tidak seperti versi sebelumnya) — diukur ulang tiap kali
  // DOM berubah (lihat `cleanup()`), supaya kotaknya ikut menyesuaikan
  // saat user pindah tab "Direct Messages" ↔ "New Group" (tingginya beda).
  double _webViewHeight = 900;

  // Penjaga supaya `Navigator.pop()` di 'MODAL_CLOSED' cuma jalan SEKALI.
  // Tanpa ini, kalau sinyal itu sampai lebih dari sekali (mis. observer
  // MutationObserver di web sempat terpicu dua kali untuk satu peristiwa
  // tutup), pop kedua bisa menutup halaman Messages itu sendiri (bukan
  // cuma dialog-nya) — user jadi terlempar balik ke Home, bukan tetap di
  // Messages.
  bool _hasClosed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      // CSS `background: transparent` di HTML/body cuma mengatur apa yang
      // digambar HALAMANNYA — widget WebView Android sendiri (native View
      // di baliknya) tetap punya latar putih bawaan terpisah, yang
      // mengintip lewat celah manapun yang tidak sempat dilukis halaman
      // (mis. selisih kecil antara `_webViewHeight` yang dikunci dan
      // tinggi kartu sungguhan). Transparansi harus diset di LEVEL
      // WEBVIEW-NYA SENDIRI lewat API ini, bukan cuma lewat CSS.
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'TitcDebug',
        onMessageReceived: (message) {
          // Tombol × di modal cuma menutup modal MILIK WEB — WebView kita
          // tidak otomatis tahu itu terjadi, jadi kotak dialog Flutter
          // tetap terbuka kalau tidak disinkronkan manual. MutationObserver
          // di bawah mendeteksi saat modal hilang dari DOM lalu melapor
          // lewat prefix ini, supaya dialog Flutter ikut ditutup bersamaan.
          if (message.message == 'MODAL_CLOSED') {
            if (!_hasClosed && mounted && Navigator.of(context).canPop()) {
              _hasClosed = true;
              Navigator.of(context).pop();
            }
            return;
          }
          if (message.message.startsWith('MODAL_HEIGHT:')) {
            // Tidak dikunci lagi sesudah pengukuran pertama — dulu dikunci
            // karena formula pengukuran lama (`top*2 + height`) muter balik
            // ke diri sendiri kalau diukur berulang. Formula sekarang cuma
            // pakai `mr.height` langsung (tidak bergantung posisi/centering
            // backdrop), jadi aman diukur ulang tiap tab berganti (mis.
            // "Direct Messages" ↔ "New Group" tingginya beda) — kotaknya
            // ikut menyesuaikan alih-alih menyisakan ruang kosong di bawah.
            final raw = message.message
                .substring('MODAL_HEIGHT:'.length)
                .trim();
            final measured = double.tryParse(raw);
            if (measured != null && mounted) {
              final clamped = measured.clamp(280.0, 600.0);
              if ((clamped - _webViewHeight).abs() > 2) {
                setState(() => _webViewHeight = clamped);
              }
            }
            return;
          }
          // ignore: avoid_print
          print('WEBVIEW_DOM: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.navigate,
          onPageFinished: (_) async {
            final isDark =
                ThemeService.themeModeNotifier.value == ThemeMode.dark;
            await _controller.runJavaScript('''
              (function() {
                var s = document.createElement('style');
                s.id = 'titc-new-message-styles';
                s.textContent = `$_dialogCss${isDark ? _darkModeCss : ''}`;
                document.head.appendChild(s);
                // Dibaca `cleanup()` di bawah (raw string, tidak bisa
                // interpolasi Dart langsung) supaya filter dark mode ikut
                // dipaksa ulang lewat style API setiap kali cleanup jalan —
                // jaring pengaman kalau style tag di atas kalah/tersapu,
                // pola yang sama dengan perbaikan lain di cleanup().
                window.__titcDarkMode = $isDark;
              })();
            ''');
            // Bersihkan elemen yang ikut "bocor" ke dalam wadah modal —
            // dikonfirmasi lewat probe DOM langsung, bukan tebakan:
            // 1. `.show_on_light` (logo "TITC Indonesia") — CSS
            //    `display:none` TERBUKTI kalah (specificity war lawan
            //    selector scoped Vue), jadi dihapus lewat JS langsung.
            // 2. `.fcom-modal-portal` dikecualikan total dari aturan
            //    "sembunyikan semua anak <body>" supaya modal tetap
            //    tampil — tapi portal itu ternyata cuma berisi SATU anak:
            //    `.modal-backdrop`, dan modal aslinya BERSARANG DI DALAM
            //    backdrop itu (bukan di sebelahnya). Backdrop sendiri
            //    punya warna gelap/abu2 bawaan (fungsinya di web memang
            //    menggelapkan halaman di belakang modal) — barrier gelap
            //    Dialog Flutter kita sudah menggantikan peran itu, jadi
            //    dipaksa transparan langsung lewat style API (inline
            //    style + 'important' selalu menang lawan rule stylesheet
            //    manapun, tidak ada lagi perang spesifisitas).
            await _controller.runJavaScript(r'''
              (function() {
                function cleanup() {
                  // TOP_PROBE membuktikan `<body class="fcom-is-mobile">`
                  // punya warna latar sungguhan (rgb(240,242,245)) yang
                  // tetap muncul di celah kecil sebelum kartu modal
                  // menutupinya — CSS `<style>` kita (`body{background:
                  // transparent}`) TERBUKTI kalah lagi, pola yang sama
                  // persis dengan `.show_on_light`/`.modal-backdrop`
                  // sebelumnya. Dipaksa langsung lewat style API di sini.
                  document.body.style.setProperty('background', 'transparent', 'important');
                  document.body.style.setProperty('background-color', 'transparent', 'important');
                  document.documentElement.style.setProperty('background', 'transparent', 'important');
                  document.documentElement.style.setProperty('background-color', 'transparent', 'important');
                  // Strip putih TERNYATA masih ada sesudah body/html
                  // dipaksa transparan — sumber aslinya baru ketahuan lewat
                  // TOP_PROBE lanjutan: `.fcom-modal-portal` (wadah Teleport
                  // Vue yang menaungi backdrop+modal) PUNYA warna latar
                  // sendiri (rgb(246,249,250), hampir putih) yang belum
                  // pernah disentuh perbaikan manapun sebelumnya.
                  document.querySelectorAll('.fcom-modal-portal').forEach(function(portal) {
                    portal.style.setProperty('background', 'transparent', 'important');
                    portal.style.setProperty('background-color', 'transparent', 'important');
                  });
                  // TOP_PROBE roundNearTop akhirnya membongkar sumber
                  // aslinya: bentuk bundar itu adalah IKON TOP MENU ASLI
                  // website (toggle dark mode, search, notifikasi, avatar
                  // user — class `.top_menu_item`/`.fcom_top_menu`).
                  // Elemen ini SUDAH ada di daftar selector CSS
                  // `display:none` sejak awal, tapi TERBUKTI tetap
                  // dirender — pola kekalahan CSS yang sama berulang kali
                  // di sesi ini. Dihapus langsung dari DOM di sini.
                  document.querySelectorAll('.fcom_top_menu, .top_menu_item').forEach(function(el) {
                    el.remove();
                  });
                  // AKHIRNYA ketemu sumber sungguhan strip putih itu —
                  // dibuktikan user sendiri lewat screenshot cepat pas
                  // modal ditutup: yang mengintip adalah HALAMAN MESSAGES
                  // ASLI (header, search, daftar chat), bukan warna dasar
                  // WebView. `.fcom_wrap` (pembungkus SELURUH halaman,
                  // anak langsung <body>) TERBUKTI tetap `display: block`
                  // walau sudah masuk daftar CSS `body > *:not(.fcom-modal-
                  // portal) { display:none }` — CSS kalah lagi, pola yang
                  // sama berulang kali di sesi ini. Dipaksa lewat JS.
                  // PENTING: JANGAN `el.remove()` di sini — sempat dicoba,
                  // hasilnya seluruh aplikasi Vue ikut mati (tombol "New
                  // message" sendiri jadi tidak ketemu lagi) karena
                  // `.fcom_wrap` ternyata bukan cuma pembungkus tampilan,
                  // tapi rumah bagi SELURUH app termasuk logikanya.
                  // `display:none` saja sudah cukup untuk menyembunyikan
                  // visualnya tanpa mematikan Vue-nya.
                  //
                  // CATATAN: sempat dicoba generalisasi ke SEMUA anak
                  // <body> (bukan cuma `.fcom_wrap`) untuk menutup sisa
                  // bocoran di bawah kartu — TERBUKTI merusak app-nya lagi
                  // (tombol "New message" jadi tidak ketemu, sama seperti
                  // kasus `el.remove()` sebelumnya). Dikembalikan ke target
                  // spesifik `.fcom_wrap` saja, yang sudah terbukti aman.
                  document.querySelectorAll('.fcom_wrap').forEach(function(el) {
                    el.style.setProperty('display', 'none', 'important');
                  });
                  document.querySelectorAll('.show_on_light').forEach(function(el) {
                    el.remove();
                  });
                  document.querySelectorAll('.fcom-modal-portal').forEach(function(portal) {
                    Array.from(portal.children).forEach(function(child) {
                      var isBackdrop = child.classList.contains('modal-backdrop');
                      var isTargetModal = child.classList.contains('modal') &&
                        child.classList.contains('new-message-modal');
                      if (!isBackdrop && !isTargetModal) child.remove();
                    });
                  });
                  document.querySelectorAll('.modal-backdrop').forEach(function(backdrop) {
                    backdrop.style.setProperty('background', 'transparent', 'important');
                    backdrop.style.setProperty('background-color', 'transparent', 'important');
                    Array.from(backdrop.children).forEach(function(child) {
                      var isTargetModal = child.classList.contains('modal') &&
                        child.classList.contains('new-message-modal');
                      if (!isTargetModal) child.remove();
                    });
                  });
                  // Dark mode: dipaksa ulang di sini (bukan cuma lewat
                  // `<style>` di awal) sebagai jaring pengaman, mengikuti
                  // pola yang sama dengan seluruh perbaikan lain di
                  // `cleanup()` ini — style tag di `<head>` berulang kali
                  // terbukti kalah/tersapu di modal ini. `window.__titcDarkMode`
                  // diisi dari Dart (lihat pemanggil `runJavaScript`
                  // sebelumnya) karena raw string ini tidak bisa interpolasi.
                  if (window.__titcDarkMode) {
                    document.querySelectorAll('.new-message-modal').forEach(function(modal) {
                      modal.style.setProperty('filter', 'invert(1) hue-rotate(180deg)', 'important');
                    });
                  }
                  // Sempat dipaksa tema gelap manual (background #1c1e2b,
                  // teks putih) meniru referensi web user — sekarang
                  // diminta balik ke tema TERANG alami (rendering asli
                  // WebView kita, dikonfirmasi lewat probe sebelumnya:
                  // modal ini bg=rgb(255,255,255) tanpa override apa pun).
                  // Jadi blok pemaksa warna gelap di atas DIHAPUS, bukan
                  // diganti — biarkan modal tampil apa adanya.
                  //
                  // Scrollbar bawaan browser di dalam kartu modal juga
                  // diminta disembunyikan — beda dari CSS lain di file ini
                  // yang berulang kali kalah lawan Svelte, scrollbar bisa
                  // disembunyikan lewat pseudo-class `::-webkit-scrollbar`
                  // (khusus WebKit/Blink, yang dipakai Android WebView)
                  // tanpa risiko specificity war karena bukan meng-override
                  // properti visual milik komponen.
                  var scrollbarHideStyle = document.getElementById('titc-hide-scrollbar');
                  if (!scrollbarHideStyle) {
                    scrollbarHideStyle = document.createElement('style');
                    scrollbarHideStyle.id = 'titc-hide-scrollbar';
                    scrollbarHideStyle.textContent =
                      '.modal.new-message-modal ::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }' +
                      '.modal.new-message-modal * { scrollbar-width: none !important; }';
                    document.head.appendChild(scrollbarHideStyle);
                  }
                  // Hasil pencarian kontak ("To: as...") bisa memuat banyak
                  // nama sekaligus — daftarnya dulu terpotong diam-diam
                  // (kepotong sama `overflow:hidden` punya <body>, bukan
                  // discroll). Kartu modal dipaksa punya batas tinggi
                  // maksimum + scroll VERTIKAL SENDIRI supaya kelebihannya
                  // bisa digulir, bukan hilang. Dipaksa lewat JS (bukan CSS
                  // biasa) mengikuti pola yang sudah terbukti menang lawan
                  // scoped style Svelte-nya.
                  var modalForScroll = document.querySelector('.modal.new-message-modal');
                  if (modalForScroll) {
                    // Pakai piksel TETAP (bukan `vh`) dengan sengaja —
                    // `vh` itu relatif ke tinggi viewport WebView kita
                    // SENDIRI (`_webViewHeight`), yang justru DITURUNKAN
                    // dari tinggi modal ini tiap `cleanup()` jalan ulang.
                    // Kalau dipakai `vh`, keduanya saling mempengaruhi dan
                    // bisa muter balik menciut terus — persis bug spiral
                    // yang sudah pernah terjadi sebelumnya di sesi ini.
                    modalForScroll.style.setProperty('max-height', '420px', 'important');
                    modalForScroll.style.setProperty('overflow-y', 'auto', 'important');
                  }
                  // Diukur DI SINI (bukan cuma sekali di luar) supaya ikut
                  // jalan tiap `cleanup()` dipanggil ulang oleh
                  // MutationObserver — termasuk saat user pindah tab
                  // "Direct Messages" ↔ "New Group" (mengubah DOM, memicu
                  // observer, memicu pengukuran ulang).
                  var modalForHeight = document.querySelector('.modal.new-message-modal');
                  if (modalForHeight && window.TitcDebug) {
                    var mrHeight = modalForHeight.getBoundingClientRect();
                    // +80 (bukan +24) — scrollbar di dalam kartu ternyata
                    // indikator BAWAAN Android WebView (bukan elemen CSS,
                    // tidak bisa disembunyikan lewat `::-webkit-scrollbar`),
                    // jadi didekati dari arah lain: kotaknya dibuat cukup
                    // lapang supaya seluruh isi kartu muat tanpa perlu
                    // discroll sama sekali.
                    window.TitcDebug.postMessage('MODAL_HEIGHT: ' + Math.ceil(mrHeight.height + 80));
                  }
                }
                cleanup();
                var cleanupObserver = new MutationObserver(cleanup);
                cleanupObserver.observe(document.body, { childList: true, subtree: true });
              })();
            ''');
            WebViewClickHelper.clickElementByText(_controller, 'New message');
            Future.delayed(const Duration(milliseconds: 900), () {
              // Debug sementara: strip putih dengan bentuk bundar samar
              // masih terlihat di ATAS kartu modal meski body/html + WebView
              // native sudah transparan — berarti ada elemen SUNGGUHAN yang
              // masih dirender di situ, bukan sekadar warna latar kosong.
              // Dicek langsung apa yang ada di titik y=5px (dekat puncak
              // viewport) dan daftar SEMUA anak langsung <body>.
              _controller.runJavaScript(r'''
                (function() {
                  if (!window.TitcDebug) return;
                  function describe(el) {
                    if (!el) return 'null';
                    var r = el.getBoundingClientRect();
                    var cs = window.getComputedStyle(el);
                    return el.tagName + '.' + String(el.className || '').replace(/\s+/g, '.') +
                      ' [' + Math.round(r.width) + 'x' + Math.round(r.height) + ' top=' + Math.round(r.top) +
                      '] display=' + cs.display + ' bg=' + cs.backgroundColor;
                  }
                  var topEl = document.elementFromPoint(180, 5);
                  var chain = [];
                  var walk = topEl;
                  for (var i = 0; i < 4 && walk; i++) { chain.push(describe(walk)); walk = walk.parentElement; }
                  var bodyChildren = [];
                  Array.from(document.body.children).forEach(function(c) { bodyChildren.push(describe(c)); });
                  window.TitcDebug.postMessage('TOP_PROBE elementAtY5: ' + JSON.stringify(chain));
                  window.TitcDebug.postMessage('TOP_PROBE bodyChildren: ' + JSON.stringify(bodyChildren));

                  // elementFromPoint di SATU titik ternyata tidak cukup —
                  // seluruh rantainya sudah transparan tapi strip putih
                  // dengan bentuk bundar masih terlihat. Dicari langsung
                  // SEMUA elemen di manapun di halaman yang punya bentuk
                  // bundar (border-radius besar) DAN posisinya dekat
                  // puncak viewport (top < 40px) — kandidat kuat untuk
                  // avatar/ikon yang terlihat di strip itu, apa pun jalur
                  // hit-test-nya.
                  var round = [];
                  document.querySelectorAll('*').forEach(function(el) {
                    var r = el.getBoundingClientRect();
                    if (r.top > 40 || r.top < -40 || r.width === 0) return;
                    var cs = window.getComputedStyle(el);
                    var radius = parseFloat(cs.borderRadius) || 0;
                    if (radius >= r.width / 2 - 2 && r.width > 4) {
                      round.push(describe(el) + ' radius=' + cs.borderRadius);
                    }
                  });
                  window.TitcDebug.postMessage('TOP_PROBE roundNearTop: ' + JSON.stringify(round));
                })();
              ''');
            });
            Future.delayed(const Duration(milliseconds: 900), () {
              _controller.runJavaScript(r'''
                (function() {
                  var seenOpen = !!document.querySelector('.modal.new-message-modal');
                  var observer = new MutationObserver(function() {
                    var stillOpen = !!document.querySelector('.modal.new-message-modal');
                    if (seenOpen && !stillOpen) {
                      if (window.TitcDebug) window.TitcDebug.postMessage('MODAL_CLOSED');
                      observer.disconnect();
                    }
                    seenOpen = stillOpen;
                  });
                  observer.observe(document.body, { childList: true, subtree: true });
                })();
              ''');
            });
            // Ditahan lebih lama dari sekadar "halaman selesai dimuat" —
            // klik "New message" (dengan retry) + transisi Svelte-nya
            // sendiri butuh waktu sebelum kartunya benar2 bersih. Sebelum
            // ini dicoba nilai lebih pendek, hasilnya halaman `/portal/chat`
            // MENTAH (header, search bar, daftar thread sendiri lengkap
            // dengan chrome-nya) sempat sekilas kelihatan sebelum CSS
            // penyembunyi & cleanup() sempat jalan — terlihat seperti "2
            // Messages" bertumpuk. `_isLoading` di bawah menutup TOTAL
            // (bukan cuma spinner mengambang) selama jeda ini.
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) setState(() => _isLoading = false);
            });
          },
        ),
      );
    _initCookiesAndLoad();
  }

  Future<void> _initCookiesAndLoad() async {
    await WebViewCookieHelper.setupCookies();
    _controller.loadRequest(Uri.parse('https://titc.or.id/portal/chat'));
  }

  /// Halaman `/portal/chat` dimuat UTUH (bukan cuma modalnya), tapi
  /// ditampilkan di kartu kecil mengambang — jadi seluruh chrome halaman
  /// (header, daftar thread, sidebar) disembunyikan paksa, hanya modal
  /// "New message" yang dibiarkan tampil apa adanya di posisi normalnya.
  ///
  /// SENGAJA transparan (bukan putih) — kotak putih persegi sempat dipasang
  /// di sini, tapi itu justru jadi "kotak kedua" yang terlihat sebagai
  /// bingkai terpisah di sekeliling kartu modal asli. Modal "New message"
  /// sendiri sudah punya latar putih + sudut membulat dari CSS webnya —
  /// cukup itu saja yang perlu terlihat; sisa area di sekitarnya biar
  /// tembus pandang, menyatu langsung dengan `barrierColor` gelap milik
  /// Dialog Flutter.
  static const String _dialogCss = r'''
    html { background: transparent !important; height: 100% !important; }
    body {
      background: transparent !important;
      overflow: hidden !important;
      min-height: 100vh !important;
    }
    header, nav, .fcom_top_menu, .spaces, .space_contents,
    #fluent_community_sidebar_menu, .fcom_sidebar_wrap, .fcom_side_footer,
    .space_opener, .site-header, .site-footer, footer,
    .fcom_mobile_menu, .fcom_space_opener_btn {
      display: none !important;
    }
    /* Lapisan terakhir: daftar selector di atas gampang ketinggalan satu
       (sudah terbukti berkali-kali nama class berbeda per halaman) — jadi
       daripada menambah daftar terus, semua anak langsung <body> yang
       BUKAN wadah modal langsung disembunyikan total, apa pun namanya.
       Dikecualikan pakai .fcom-modal-portal — wadah Vue Teleport untuk
       modal ini. (JANGAN pakai backtick di komentar CSS blok ini — ia
       disuntik ke dalam template literal JS lewat interpolasi Dart di
       pemanggilnya, satu backtick menutup literal itu lebih awal dan
       seluruh skrip jadi syntax error diam-diam.) */
    body > *:not(.fcom-modal-portal) {
      display: none !important;
    }
  ''';

  /// Modal "New message" adalah HTML web asli — latar putih & teks gelapnya
  /// datang dari CSS web itu sendiri, bukan dari Flutter, jadi tidak bisa
  /// diikutkan tema app lewat `Theme.of(context)` seperti widget Flutter
  /// biasa. Diterapkan HANYA saat dark mode aktif: `filter: invert(1)
  /// hue-rotate(180deg)` membalik terang↔gelap sekaligus mengoreksi
  /// pergeseran hue akibat invert — trik standar untuk konten web yang
  /// tidak punya varian dark mode sendiri. Aman di sini karena modal ini
  /// cuma berisi teks, input, dan tombol (tidak ada foto/logo yang akan
  /// ikut ter-invert jadi aneh).
  ///
  /// Target selector `.new-message-modal` — dikonfirmasi LANGSUNG dari kode
  /// `cleanup()` di bawah (`child.classList.contains('new-message-modal')`),
  /// bukan tebakan. Percobaan sebelumnya ke `.fcom-modal-portal` lalu `html`
  /// sama-sama tidak berefek — kemungkinan besar bukan soal selector salah
  /// semata, tapi style tag ini disuntik SEKALI di `onPageFinished`
  /// sebelum modal-nya sendiri sempat dibuat Vue (baru muncul setelah
  /// auto-click "New message"). CSS seharusnya tetap berlaku begitu elemen
  /// itu muncul belakangan (stylesheet itu reaktif ke DOM), tapi sebagai
  /// jaring pengaman filter yang sama JUGA dipaksa lewat `cleanup()` di
  /// bawah (yang terbukti jalan berulang kali melawan DOM yang berubah-ubah).
  static const String _darkModeCss = r'''
    .new-message-modal {
      filter: invert(1) hue-rotate(180deg) !important;
    }
  ''';

  @override
  Widget build(BuildContext context) {
    // Jarak atas dihitung eksplisit (bukan angka tetap) supaya dialog
    // selalu mulai di bawah status bar + AppBar native, apa pun ukuran
    // perangkatnya.
    final topClearance =
        MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return Dialog(
      // Transparan total, tanpa shape/elevation — bingkai putih & sudut
      // membulat yang tadinya digambar Flutter di sini justru muncul
      // sebagai "kotak kedua" terpisah dari kartu modal aslinya (yang
      // sudah punya latar putih + sudut membulat sendiri dari CSS web).
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.fromLTRB(20, topClearance, 20, 100),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: _webViewHeight,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              // Menutup TOTAL (bukan cuma spinner mengambang) selama
              // proses klik+cleanup berlangsung — lihat catatan di
              // `Future.delayed(1000ms)` pada `onPageFinished`.
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      // Ikut warna tema aplikasi (bukan putih tetap) supaya
                      // tidak ada kilasan warna yang beda dari kartu modal
                      // asli — yang saat dark mode aktif dibalik gelap lewat
                      // `_darkModeCss` (invert filter).
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

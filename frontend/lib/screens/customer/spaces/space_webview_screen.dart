import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/customer/admin_portal_drawer.dart';
import 'package:magang_titc/widgets/customer/side_drawer.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';
import 'package:magang_titc/services/webview_cookie_helper.dart';

/// Encode string Dart menjadi literal string JS yang aman (escape kutip,
/// backslash, baris baru, dll) supaya CSS tambahan bisa disisipkan ke
/// dalam snippet JS yang di-runJavaScript tanpa risiko injeksi.
String _jsStringLiteral(String value) => jsonEncode(value);

/// WebView khusus untuk halaman Space di Fluent Community Portal.
/// Class names verified via DOM debug:
/// - Right sidebar: ASIDE.el-aside.fcom_resp_side
/// - Sidebar widgets: DIV.fcom_main_side_wrap > DIV.app_side_widget
/// - Feed parent: DIV.fhr_home
/// - Layout uses Element Plus: el-container, el-aside, el-main
class SpaceWebViewScreen extends StatefulWidget {
  final String? spaceSlug;
  final String title;

  /// Segmen path portal FCOM: `space` (default) atau `course`. Modul Course
  /// di Fluent Community adalah varian dari Space (`type: "course"`) dan
  /// memakai shell Vue/CSS yang sama persis, jadi screen ini di-reuse
  /// dengan parameter URL berbeda alih-alih duplikat file (lihat PRD §12).
  final String portalSegment;

  /// Segmen tab yang dimuat di dalam space/course, mis. `home` (default)
  /// atau `lessons` untuk langsung membuka daftar pelajaran course.
  final String initialPath;

  /// URL absolut yang dipakai apa adanya (mis. permalink sebuah post),
  /// alih-alih membangun URL dari [portalSegment]/[spaceSlug]/[initialPath].
  /// Dipakai untuk kasus seperti membuka satu post + modal komentarnya,
  /// yang tetap memakai shell Vue/Element-Plus yang sama sehingga CSS
  /// reflow di bawah ini tetap relevan.
  final String? overrideUrl;

  /// CSS tambahan yang di-inject setelah style dasar, mis. untuk
  /// memfullscreen-kan modal komentar Element Plus.
  final String? extraCss;

  /// Pakai [AdminPortalDrawer] (struktur Portal Settings/Course Management/
  /// Reports) alih-alih [SideDrawer] member biasa. Dipakai untuk halaman
  /// `/portal/admin/`.
  final bool useAdminDrawer;

  const SpaceWebViewScreen({
    super.key,
    this.spaceSlug,
    required this.title,
    this.portalSegment = 'space',
    this.initialPath = 'home',
    this.overrideUrl,
    this.extraCss,
    this.useAdminDrawer = false,
  }) : assert(
         spaceSlug != null || overrideUrl != null,
         'Harus isi spaceSlug atau overrideUrl',
       );

  @override
  State<SpaceWebViewScreen> createState() => _SpaceWebViewScreenState();
}

class _SpaceWebViewScreenState extends State<SpaceWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// True selama fase pre-warm (`_initCookiesAndLoad` memuat portal root
  /// dulu untuk mengambil cookie tambahan) sebelum berpindah ke URL tujuan
  /// sesungguhnya. Portal root ini TIDAK PERNAH ditampilkan ke user — kalau
  /// `onPageFinished`-nya ikut mematikan `_isLoading`, spinner mati lalu
  /// hidup lagi begitu navigasi ke URL tujuan dimulai ("loading 2 kali").
  /// Selama flag ini true, `onPageFinished` mengabaikan reveal.
  bool _isPrewarming = false;

  /// Label item sidebar admin yang di-highlight [AdminPortalDrawer].
  ///
  /// Sempat dicoba dideteksi dari DOM (class `is-active`/`router-link-
  /// active` dsb.), tapi ternyata setiap item sidebar admin punya class
  /// statis unik per item (`settings_inner_menu_customization`, dst) yang
  /// TIDAK PERNAH berubah — bukan penanda status aktif. Web tidak
  /// menyediakan cara yang bisa diandalkan untuk membaca item aktif dari
  /// luar. Jadi dilacak dari tap terakhir di drawer sendiri — kita yang
  /// memicu navigasinya, jadi sudah pasti tahu item mana yang aktif tanpa
  /// perlu menebak dari DOM. "General" jadi default awal karena itu
  /// halaman yang dimuat pertama kali saat masuk `/portal/admin/`.
  String? _activeAdminLabel;

  /// Supaya auto-navigasi ke "General" (lihat `onPageFinished` di bawah)
  /// cuma jalan sekali per layar ini — sekali dipicu, tap manual user
  /// setelahnya tidak boleh ditimpa lagi.
  bool _autoOpenedAdminGeneral = false;

  String get _targetUrl =>
      widget.overrideUrl ??
      'https://titc.or.id/portal/${widget.portalSegment}/${widget.spaceSlug}/${widget.initialPath}';

  String get _injectScript => r'''
(function() {
  'use strict';

  function injectCSS() {
    if (document.getElementById('titc-final-styles')) return;
    var s = document.createElement('style');
    s.id = 'titc-final-styles';
    s.textContent = `
      /* ===== HIDE: Top navigation FCOM ===== */
      .fcom_top_menu { display: none !important; }

      /* ===== HIDE: Left sidebar (spaces list) ===== */
      .spaces, .space_contents, #fluent_community_sidebar_menu,
      .fcom_sidebar_wrap, .fcom_side_footer, .space_opener {
        display: none !important; width: 0 !important;
      }

      /* ===== HIDE: Mobile bottom nav ===== */
      .fcom_mobile_menu { display: none !important; }

      /* ===== HIDE: Hamburger button ===== */
      .fcom_space_opener_btn { display: none !important; }

      /* ===== HIDE: WordPress theme header/footer ===== */
      header, .site-header, #masthead, .ast-site-header,
      .elementor-location-header, footer, .site-footer, #colophon,
      .ast-site-footer, .elementor-location-footer, .footer-widgets,
      .bb-mobile-panel, .bb-mobile-header, .spectra-header-template {
        display: none !important;
      }

      /* ===== HIDE: Judul space (verified: H1.fcom_page_title) ===== */
      .fcom_page_title {
        display: none !important;
      }

      /* ===== HIDE: Tab nav desktop (Posts/Chat/About links) ===== */
      nav.fcom_desktop_only {
        display: none !important;
      }

      /* ===== HEADER: tetap tampil (breadcrumb + "Continue Course") ===== */
      /* Dulu di-collapse ke height:0 supaya judulnya tidak dobel dengan
         AppBar Flutter. Tapi judul itu sudah dimatikan terpisah lewat
         .fcom_page_title, jadi container-nya tidak perlu ikut dimatikan —
         yang tersisa justru breadcrumb dan tombol aksi yang memang berguna.
         Kuncinya: JANGAN pakai height:0 + overflow:visible. Kombinasi itu
         membuat isinya tetap tergambar tanpa menempati ruang, sehingga
         menimpa konten di bawahnya. Di sini header diberi tinggi natural
         supaya ikut mengalir normal. */
      .fhr_content_layout_header {
        height: auto !important;
        min-height: 0 !important;
        padding: 10px 12px !important;
        margin: 0 !important;
        overflow: visible !important;
        position: relative !important;
        display: flex !important;
        align-items: center !important;
        justify-content: space-between !important;
        gap: 10px !important;
        /* Layar HP jauh lebih sempit dari desktop: tanpa ini breadcrumb dan
           tombol saling desak sampai teksnya terpotong. */
        flex-wrap: wrap !important;
        border: none !important;
        box-shadow: none !important;
        outline: none !important;
        /* Putih, mengikuti tampilan web: baris breadcrumb + tombol berdiri
           di atas latar abu halaman, terpisah dari kartu konten di bawah. */
        background: #fff !important;
      }

      /* Isi header dipaksa kembali ke aliran normal. CSS bawaan FCOM
         meng-absolute-kan sebagian dari mereka (dirancang untuk header
         desktop yang tinggi), akibatnya container menyisakan pita kosong
         sementara isinya tergambar lebih ke bawah dan menimpa judul course.
         .fcom_dot_menu dikecualikan: itu memang harus tetap absolute dan
         transparan, dipakai hanya sebagai target .click() dari AppBar. */
      /* Body konten naik menimpa header — terbukti dari probe DOM: header
         menempati y=56..108, tapi body sudah mulai di y=52. Penyebabnya
         margin/padding negatif bawaan FCOM, yang di desktop dipakai untuk
         menyelipkan konten di bawah header sticky. Dinolkan supaya body
         benar-benar mengalir SETELAH header. */
      .fhr_content_layout_body {
        margin-top: 0 !important;
        top: auto !important;
        position: static !important;
      }

      .fhr_content_layout_header > *:not(.fcom_dot_menu) {
        position: static !important;
        top: auto !important;
        right: auto !important;
        bottom: auto !important;
        left: auto !important;
        transform: none !important;
        margin-top: 0 !important;
        margin-bottom: 0 !important;
      }

      /* ===== Tombol ⋮ web: tampilkan seperti di browser ===== */
      /* Dulu disembunyikan (opacity 0) dan hanya dipakai sebagai target
         .click() dari tombol ⋮ di AppBar Flutter, karena header web
         di-collapse sehingga tombolnya tidak punya tempat. Header sekarang
         tampil normal, jadi tombol aslinya dikembalikan ke tempatnya —
         posisi dropdown-nya pun jadi benar sendiri tanpa perlu dipaksa. */
      .fcom_dot_menu {
        opacity: 1 !important;
        pointer-events: auto !important;
      }
      /* ===== FIX: Body ===== */
      body {
        padding-top: 0 !important;
        margin-top: 0 !important;
        overflow-x: hidden !important;
      }

      /* ===== FIX: All wrappers full width ===== */
      .fcom_wrap, .fluent_com, .fhr_content, #fluent_comminity_body, .fhr_wrap {
        max-width: 100% !important;
        width: 100% !important;
        padding: 0 !important;
        margin: 0 !important;
        box-sizing: border-box !important;
      }

      /* ===== CRITICAL: Element Plus layout containers ===== */
      .el-container {
        display: flex !important;
        flex-direction: column !important;
        width: 100% !important;
        max-width: 100% !important;
        padding: 0 !important;
        margin: 0 !important;
      }

      .el-main {
        width: 100% !important;
        max-width: 100% !important;
        padding: 0 !important;
        margin: 0 !important;
        flex: none !important;
        overflow: visible !important;
      }

      /* ===== LEFT el-aside (spaces list) = sembunyikan ===== */
      aside.el-aside:not(.fcom_resp_side) {
        display: none !important;
        width: 0 !important;
      }

      /* ===== RIGHT el-aside (About + Recent) = tampilkan full width ===== */
      aside.fcom_resp_side,
      .fcom_resp_side {
        display: block !important;
        width: 100% !important;
        max-width: 100% !important;
        flex: none !important;
        position: static !important;
        top: auto !important;
        right: auto !important;
        float: none !important;
        height: auto !important;
        max-height: none !important;
        overflow: visible !important;
        margin: 0 !important;
        padding: 8px 0 0 0 !important;
        box-sizing: border-box !important;
        order: 10 !important;
      }

      .fcom_main_side_wrap {
        display: block !important;
        width: 100% !important;
        padding: 0 12px 16px !important;
        box-sizing: border-box !important;
      }

      .app_side_widget {
        display: block !important;
        width: 100% !important;
        margin-bottom: 12px !important;
        border-radius: 8px !important;
        background: var(--fcom-primary-bg, #fff) !important;
        box-shadow: 0 1px 2px rgba(0,0,0,0.1) !important;
        padding: 16px !important;
        box-sizing: border-box !important;
      }

      .widget_header {
        margin-bottom: 8px !important;
        font-weight: 600 !important;
      }

      .fhr_home {
        width: 100% !important;
        max-width: 100% !important;
        margin: 0 !important;
        padding: 0 !important;
      }

      .feed_layout {
        padding-left: 0 !important;
        margin-left: 0 !important;
        width: 100% !important;
        max-width: 100% !important;
      }
    `;
    document.head.appendChild(s);
  }

  function fixLayout() {
    document.querySelectorAll('.el-container').forEach(function(c) {
      c.style.setProperty('display', 'flex', 'important');
      c.style.setProperty('flex-direction', 'column', 'important');
      c.style.setProperty('width', '100%', 'important');
      c.style.setProperty('max-width', '100%', 'important');
    });

    document.querySelectorAll('.el-main').forEach(function(m) {
      m.style.setProperty('width', '100%', 'important');
      m.style.setProperty('max-width', '100%', 'important');
      m.style.setProperty('padding', '0', 'important');
      m.style.setProperty('flex', 'none', 'important');
    });

    var feedLayout = document.querySelector('.feed_layout');
    if (feedLayout) {
      feedLayout.style.setProperty('padding-left', '0', 'important');
      feedLayout.style.setProperty('margin-left', '0', 'important');
      feedLayout.style.setProperty('width', '100%', 'important');
      feedLayout.style.setProperty('max-width', '100%', 'important');
    }

    // Header dibiarkan tampil (breadcrumb + tombol "Continue Course"), tapi
    // dipaksa punya tinggi natural. Inline style di sini menang atas
    // stylesheet, jadi nilainya harus sama dengan aturan CSS di atas —
    // kalau berbeda, header balik tumpang tindih setiap MutationObserver
    // memanggil fixLayout() lagi.
    var layoutHeader = document.querySelector('.fhr_content_layout_header');
    if (layoutHeader) {
      // Halaman Space tidak punya breadcrumb maupun tombol "Continue Course"
      // seperti halaman Course. Judul & nav-nya sudah kita sembunyikan
      // (digantikan AppBar Flutter), jadi yang tersisa cuma tombol ⋮ — dan
      // header-nya tampil sebagai pita putih kosong yang terlihat seperti bug.
      // Kalau tidak ada isi yang benar-benar terlihat, header disembunyikan.
      var hasContent = false;
      Array.prototype.forEach.call(layoutHeader.children, function(child) {
        // Tombol ⋮ tidak dihitung: dia sendirian tidak cukup jadi alasan
        // menampilkan sebaris header kosong.
        if (child.classList && child.classList.contains('fcom_dot_menu')) return;
        var cs = getComputedStyle(child);
        if (cs.display === 'none' || cs.visibility === 'hidden') return;
        if (child.getBoundingClientRect().height > 0) hasContent = true;
      });

      // Sengaja BUKAN early-return: perbaikan pita kosong di atas dan posisi
      // body di bawah tetap harus dijalankan walau header-nya disembunyikan.
      if (hasContent) {
        layoutHeader.style.setProperty('height', 'auto', 'important');
        layoutHeader.style.setProperty('min-height', '0', 'important');
        layoutHeader.style.setProperty('padding', '10px 12px', 'important');
        layoutHeader.style.setProperty('margin', '0', 'important');
        layoutHeader.style.setProperty('overflow', 'visible', 'important');
        layoutHeader.style.setProperty('display', 'flex', 'important');
        layoutHeader.style.setProperty('align-items', 'center', 'important');
        layoutHeader.style.setProperty('justify-content', 'space-between', 'important');
        layoutHeader.style.setProperty('flex-wrap', 'wrap', 'important');
        layoutHeader.style.setProperty('gap', '10px', 'important');
        layoutHeader.style.setProperty('background', '#fff', 'important');
        layoutHeader.style.setProperty('z-index', '1', 'important');
      } else {
        layoutHeader.style.setProperty('display', 'none', 'important');
      }

      // Induk dipaksa block. Kalau induknya grid (atau flex row), header dan
      // body bisa ditempatkan di sel/kolom yang sama sehingga bertumpuk —
      // dan dalam kasus itu menolkan margin body tidak menolong sama sekali.
      // Ditangani lewat parentElement karena nama class-nya tidak diketahui.
      var headerParent = layoutHeader.parentElement;
      if (headerParent) {
        headerParent.style.setProperty('display', 'block', 'important');
        headerParent.style.setProperty('position', 'relative', 'important');
      }

      // Hapus pita kosong di atas header.
      //
      // FCOM memberi padding-top pada salah satu wrapper untuk menyediakan
      // tempat bagi .fcom_top_menu yang position:fixed (tingginya ~56px —
      // cocok dengan posisi header yang terbaca di probe). Menunya sudah kita
      // sembunyikan, tapi paddingnya tertinggal dan menyisakan pita abu.
      //
      // Disapu ke SELURUH rantai induk, bukan cuma induk langsung, karena
      // wrapper penyebabnya bisa berada beberapa tingkat di atas dan nama
      // class-nya tidak diketahui dari luar.
      var node = layoutHeader.parentElement;
      while (node && node !== document.body) {
        node.style.setProperty('padding-top', '0', 'important');
        node.style.setProperty('margin-top', '0', 'important');
        node = node.parentElement;
      }

      // Body dipaksa mengalir setelah header, bukan menyelip di bawahnya
      // seperti rancangan desktop yang header-nya sticky.
      var layoutBody = document.querySelector('.fhr_content_layout_body');
      if (layoutBody) {
        layoutBody.style.setProperty('margin-top', '0', 'important');
        layoutBody.style.setProperty('padding-top', '0', 'important');
        layoutBody.style.setProperty('position', 'static', 'important');
        layoutBody.style.setProperty('top', 'auto', 'important');
      }
    }


  }

  // Laporkan posisi nyata header & isinya ke Dart. Dipakai untuk menemukan
  // elemen mana yang bikin pita kosong / tumpang tindih, karena selector CSS
  // tidak bisa diverifikasi dari luar (portal butuh login).
  function reportHeader() {
    try {
      if (!window.TitcDebug) return;
      var h = document.querySelector('.fhr_content_layout_header');
      if (!h) { window.TitcDebug.postMessage('header tidak ketemu'); return; }

      function describe(el) {
        var r = el.getBoundingClientRect();
        var cs = getComputedStyle(el);
        return el.tagName + '.' + String(el.className || '').trim() +
               ' [pos=' + cs.position +
               ' top=' + Math.round(r.top) +
               ' h=' + Math.round(r.height) +
               ' mt=' + cs.marginTop +
               ' mb=' + cs.marginBottom +
               ' pt=' + cs.paddingTop + ']';
      }

      var out = ['HEADER ' + describe(h)];
      // Seluruh rantai induk dilaporkan: header idealnya menempel di y=0.
      // Kalau tidak, salah satu induk inilah yang menyumbang jarak — dan
      // baris ini menunjukkan yang mana beserta angkanya. display juga ikut,
      // untuk memisahkan penyebab "grid menumpuk" dari "padding tersisa".
      var node = h.parentElement;
      var level = 0;
      while (node && node !== document.body && level < 6) {
        out.push('INDUK[' + level + '] ' + describe(node) +
                 ' display=' + getComputedStyle(node).display);
        node = node.parentElement;
        level++;
      }
      var prev = h.previousElementSibling;
      out.push('SEBELUM: ' + (prev ? describe(prev) : 'tidak ada'));
      var next = h.nextElementSibling;
      out.push('SESUDAH: ' + (next ? describe(next) : 'tidak ada'));
      for (var i = 0; i < h.children.length; i++) {
        out.push('ANAK[' + i + '] ' + describe(h.children[i]));
      }
      window.TitcDebug.postMessage(out.join(' || '));
    } catch (e) {
      if (window.TitcDebug) window.TitcDebug.postMessage('error: ' + e);
    }
  }

  // Jalankan
  injectCSS();
  fixLayout();
  setTimeout(reportHeader, 2000);

  [300, 800, 1500, 3000].forEach(function(ms) {
    setTimeout(function() { injectCSS(); fixLayout(); }, ms);
  });


  // MutationObserver dengan debounce
  var debounceTimer = null;
  var observer = new MutationObserver(function() {
    injectCSS();
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(fixLayout, 200);
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
''';

  @override
  void initState() {
    super.initState();
    if (widget.useAdminDrawer) _activeAdminLabel = 'General';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      // Jalur pelaporan dari halaman web ke console Dart. DOM portal FCOM
      // hanya bisa diperiksa setelah login, jadi app-nya sendiri yang
      // melaporkan struktur header ketika layout masih meleset.
      ..addJavaScriptChannel(
        'TitcDebug',
        onMessageReceived: (message) => print('WEBVIEW_DOM: ${message.message}'),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // Selalu navigate: kalau ditolak, WebView melempar link ke browser
          // eksternal dan user merasa keluar dari aplikasi.
          //
          // URL-nya dicatat supaya tujuan tombol di dalam halaman web (mis.
          // "Continue Course") bisa dilihat dari console — DOM portal FCOM
          // hanya ada setelah login, jadi tidak bisa diperiksa dari luar.
          onNavigationRequest: (request) {
            print('WEBVIEW_NAV: ${request.url}');
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            await _controller.runJavaScript(_injectScript);
            if (widget.extraCss != null && widget.extraCss!.isNotEmpty) {
              await _controller.runJavaScript('''
                (function() {
                  var s = document.createElement('style');
                  s.id = 'titc-extra-styles';
                  s.textContent = ${_jsStringLiteral(widget.extraCss!)};
                  document.head.appendChild(s);
                })();
              ''');
            }
            // Portal admin ('/portal/admin/') mendarat di halaman yang
            // Vue Router-nya belum dinavigasikan ke sub-menu mana pun kalau
            // dibuka lewat full page load (bukan klik dari dalam SPA) — beda
            // dengan drawer Flutter yang sudah menyalakan highlight
            // "General" seolah-olah sudah di sana. Tanpa baris ini, halaman
            // tampak kosong/loading acak sampai user pindah menu lalu balik
            // lagi (barulah itu klik sungguhan yang menavigasikan Vue
            // Router). Dicek `url` (bukan `widget.useAdminDrawer` saja)
            // supaya tidak ikut terpicu saat pre-warm memuat portal root di
            // `_initCookiesAndLoad`, dan `_autoOpenedAdminGeneral` memastikan
            // ini cuma sekali — tap manual user sesudahnya tidak boleh
            // ditimpa balik ke General.
            if (widget.useAdminDrawer &&
                !_autoOpenedAdminGeneral &&
                url.contains('/portal/admin')) {
              _autoOpenedAdminGeneral = true;
              AdminPortalDrawer.clickSidebarLink(_controller, 'General');
            }

            // Halaman pre-warm tidak boleh mematikan spinner — lihat
            // penjelasan di deklarasi field `_isPrewarming`.
            if (_isPrewarming) return;

            Future.delayed(const Duration(milliseconds: 700), () {
              if (mounted) setState(() => _isLoading = false);
            });
          },
        ),
      );

    _initCookiesAndLoad();
  }

  Future<void> _initCookiesAndLoad() async {
    final hasCookies = await WebViewCookieHelper.setupCookies();
    final cookiesString = AuthService.cookies;

    print('WEBVIEW_LOAD: target=$_targetUrl (cookie ${!hasCookies ? "KOSONG" : "${cookiesString?.length ?? 0} char"})');

    // Cookie dibawa WebView lewat cookie jar yang di-set oleh helper.
    // TIDAK boleh menambahkan header `Cookie` manual (bentrok, minta login)
    // atau header `Cache-Control`/`Pragma` (juga minta login).
    //
    // Pre-warm: muat halaman portal root dulu secara silent untuk memberi
    // kesempatan server menyetel cookie LiteSpeed Cache dan session cookie
    // tambahan yang mungkin belum ada di cookie jar kita. Setelah itu baru
    // navigate ke halaman tujuan.
    if (hasCookies) {
      _isPrewarming = true;
      // Muat portal root dulu untuk pre-warm cookie
      await _controller.loadRequest(
        Uri.parse('https://titc.or.id/portal/'),
      );
      // Tunggu sebentar untuk halaman portal dimuat dan cookie ter-set
      await Future.delayed(const Duration(milliseconds: 2000));
      _isPrewarming = false;
    }
    // Navigate ke halaman tujuan
    await _controller.loadRequest(Uri.parse(_targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      // Navbar yang sama persis dengan Home (dan dengan tampilan web):
      // hamburger, "TITC Indonesia", search, lonceng, foto profil.
      //
      // Tombol ⋮ bawaan layar ini dilepas: dulu itu jembatan ke tombol ⋮
      // milik web yang terpaksa disembunyikan waktu header web di-collapse.
      // Sekarang header web tampil apa adanya, jadi tombol ⋮ aslinya muncul
      // sendiri di dalam halaman — persis seperti di browser.
      appBar: const TitcAppBar(),
      // Wajib ada: hamburger di TitcAppBar memanggil Scaffold.of().openDrawer(),
      // yang tidak berbuat apa-apa kalau Scaffold-nya tidak punya drawer.
      drawer: widget.useAdminDrawer
          ? AdminPortalDrawer(
              controller: _controller,
              activeLabel: _activeAdminLabel,
              onItemSelected: (label) =>
                  setState(() => _activeAdminLabel = label),
            )
          : const SideDrawer(),
      body: Stack(
        children: [
          Opacity(
            opacity: _isLoading ? 0.0 : 1.0,
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1877F2)),
                  SizedBox(height: 12),
                  Text('Memuat...',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

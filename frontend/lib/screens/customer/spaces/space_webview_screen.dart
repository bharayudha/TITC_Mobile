import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/auth_service.dart';

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

  const SpaceWebViewScreen({
    super.key,
    this.spaceSlug,
    required this.title,
    this.portalSegment = 'space',
    this.initialPath = 'home',
    this.overrideUrl,
    this.extraCss,
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

      /* ===== COLLAPSE: Container header tapi jangan display:none ===== */
      /* Harus tetap di DOM agar BUTTON.fcom_dot_menu bisa diklik via JS */
      .fhr_content_layout_header {
        height: 0 !important;
        min-height: 0 !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
        position: relative !important;
        border: none !important;
        box-shadow: none !important;
        outline: none !important;
        background: transparent !important;
      }

      /* ===== HIDE VISUALLY: Tombol ⋮ web (tetap di DOM untuk diklik) ===== */
      .fcom_dot_menu {
        opacity: 0 !important;
        pointer-events: none !important;
        position: absolute !important;
        top: 0 !important;
        right: 0 !important;
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

    // Collapse container header (jangan display:none agar tombol ⋮ tetap di DOM)
    var layoutHeader = document.querySelector('.fhr_content_layout_header');
    if (layoutHeader) {
      layoutHeader.style.setProperty('height', '0', 'important');
      layoutHeader.style.setProperty('min-height', '0', 'important');
      layoutHeader.style.setProperty('padding', '0', 'important');
      layoutHeader.style.setProperty('margin', '0', 'important');
      layoutHeader.style.setProperty('overflow', 'visible', 'important');
    }


  }

  // Jalankan
  injectCSS();
  fixLayout();

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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.navigate,
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
            Future.delayed(const Duration(milliseconds: 700), () {
              if (mounted) setState(() => _isLoading = false);
            });
          },
        ),
      );

    _initCookiesAndLoad();
  }

  Future<void> _initCookiesAndLoad() async {
    final cookieManager = WebViewCookieManager();
    final cookiesString = AuthService.cookies;

    if (cookiesString != null && cookiesString.isNotEmpty) {
      for (final part in cookiesString.split(';')) {
        final kv = part.trim().split('=');
        if (kv.length >= 2) {
          final name = kv[0].trim();
          final value = kv.sublist(1).join('=');
          await cookieManager.setCookie(
            WebViewCookie(name: name, value: value, domain: 'titc.or.id', path: '/'),
          );
          await cookieManager.setCookie(
            WebViewCookie(name: name, value: value, domain: '.titc.or.id', path: '/'),
          );
        }
      }
    }

    await _controller.loadRequest(
      Uri.parse(
        widget.overrideUrl ??
            'https://titc.or.id/portal/${widget.portalSegment}/${widget.spaceSlug}/${widget.initialPath}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Klik BUTTON.fcom_dot_menu (verified via DOM debug)
              _controller.runJavaScript('''
                (function() {
                  var dotBtn = document.querySelector('.fcom_dot_menu');
                  if (!dotBtn) { console.log('[DEBUG] .fcom_dot_menu tidak ketemu'); return; }
                  
                  // Restore pointer-events agar bisa diklik
                  dotBtn.style.setProperty('opacity', '1', 'important');
                  dotBtn.style.setProperty('pointer-events', 'auto', 'important');
                  
                  // Klik tombolnya
                  dotBtn.click();
                  
                  // Sembunyikan lagi setelah klik
                  setTimeout(function() {
                    dotBtn.style.setProperty('opacity', '0', 'important');
                    dotBtn.style.setProperty('pointer-events', 'none', 'important');
                  }, 100);
                })();
              ''');
            },
          ),
        ],
      ),
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

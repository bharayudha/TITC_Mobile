import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/auth_service.dart';

/// WebView khusus untuk halaman Space di Fluent Community Portal.
/// Menghilangkan semua elemen navigasi web (header, sidebar, bottom nav)
/// sehingga tampilan menyatu seolah-olah halaman Native.
class SpaceWebViewScreen extends StatefulWidget {
  final String spaceSlug;
  final String title;

  const SpaceWebViewScreen({
    super.key,
    required this.spaceSlug,
    required this.title,
  });

  @override
  State<SpaceWebViewScreen> createState() => _SpaceWebViewScreenState();
}

class _SpaceWebViewScreenState extends State<SpaceWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // CSS untuk menyembunyikan semua elemen navigasi web Fluent Community
  static const String _hideChromeCSS = '''
    /* ===== HIDE TOP NAVIGATION BAR ===== */
    .fcom_top_menu,
    .top_menu_left,
    .top_menu_center,
    .top_menu_right {
      display: none !important;
      height: 0 !important;
      overflow: hidden !important;
    }

    /* ===== HIDE LEFT SIDEBAR ===== */
    .spaces,
    .space_contents,
    #fluent_community_sidebar_menu,
    .fcom_sidebar_wrap,
    .fcom_side_footer,
    .space_opener {
      display: none !important;
      width: 0 !important;
      overflow: hidden !important;
    }

    /* ===== HIDE MOBILE BOTTOM NAVIGATION ===== */
    .fcom_mobile_menu,
    .focm_menu_items,
    .focm_menu_item {
      display: none !important;
      height: 0 !important;
      overflow: hidden !important;
    }

    /* ===== HIDE MOBILE HAMBURGER BUTTON ===== */
    .fcom_space_opener_btn {
      display: none !important;
    }

    /* ===== HIDE WORDPRESS THEME HEADER/FOOTER ===== */
    header, .site-header, #masthead, .ast-site-header, .elementor-location-header,
    footer, .site-footer, #colophon, .ast-site-footer, .elementor-location-footer,
    .footer-widgets, .bb-mobile-panel, .bb-mobile-header, .header-inner, .buddypanel,
    .spectra-header-template {
      display: none !important;
    }

    /* ===== FIX LAYOUT: Hapus offset sidebar ===== */
    .feed_layout {
      padding-left: 0 !important;
      margin-left: 0 !important;
    }

    /* ===== FIX BODY ===== */
    body {
      padding-top: 0 !important;
      margin-top: 0 !important;
      overflow-x: hidden !important;
    }

    /* ===== Pastikan konten utama full width ===== */
    .fcom_wrap, .fluent_com, .fhr_content, #fluent_comminity_body {
      max-width: 100% !important;
      width: 100% !important;
      padding-left: 0 !important;
      margin-left: 0 !important;
    }
  ''';

  // JavaScript untuk menyuntikkan CSS dan menjaga agar tetap tersembunyi
  // meskipun SPA (Single Page Application) Vue.js melakukan re-render
  static const String _injectScript = '''
    (function() {
      // Inject CSS
      var style = document.createElement('style');
      style.id = 'titc-mobile-hide-chrome';
      style.innerHTML = `$_hideChromeCSS`;
      document.head.appendChild(style);

      // MutationObserver untuk memantau perubahan DOM dari Vue.js SPA
      // dan memastikan CSS tetap tersuntik meskipun ada re-render
      var observer = new MutationObserver(function(mutations) {
        if (!document.getElementById('titc-mobile-hide-chrome')) {
          var s = document.createElement('style');
          s.id = 'titc-mobile-hide-chrome';
          s.innerHTML = `$_hideChromeCSS`;
          document.head.appendChild(s);
        }
      });
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true
      });
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Paksa semua navigasi tetap di dalam WebView, jangan buka Chrome
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            // Inject CSS + MutationObserver setiap kali halaman selesai dimuat
            await _controller.runJavaScript(_injectScript);

            // Delay sedikit untuk memastikan CSS sudah dirender
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => _isLoading = false);
              }
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
      final parts = cookiesString.split(';');
      for (final part in parts) {
        final kv = part.trim().split('=');
        if (kv.length >= 2) {
          final name = kv[0];
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

    final url = 'https://titc.or.id/portal/space/${widget.spaceSlug}/home';
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          // WebView yang sudah dibersihkan dari elemen web
          Opacity(
            opacity: _isLoading ? 0 : 1,
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

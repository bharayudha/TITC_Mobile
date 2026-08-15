import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/webview_click_helper.dart';
import 'package:magang_titc/services/webview_cookie_helper.dart';
import 'package:magang_titc/constants/app_colors.dart';

class AuthenticatedWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? extraCss;

  /// Teks tombol/link yang otomatis diklik SEKALI begitu halaman selesai
  /// dimuat — lihat penjelasan lengkap di
  /// `SpaceWebViewScreen.autoClickText`, mekanismenya sama persis
  /// (`WebViewClickHelper.clickElementByText`).
  final String? autoClickText;

  /// Alternatif dari [autoClickText] untuk trigger dua langkah: klik
  /// tombol "⋮" (`.fcom_dot_menu`) dulu untuk membuka dropdown-nya, baru
  /// klik teks ini di dalam dropdown yang muncul. Dipakai untuk menu yang
  /// pemicunya ikon polos tanpa teks (mis. "Welcome Banner"/"Manage
  /// Links" di header Feed) — lihat
  /// `WebViewClickHelper.clickDotMenuThenText`. Hanya salah satu dari
  /// [autoClickText]/[autoClickDotMenuThenText] yang perlu diisi.
  final String? autoClickDotMenuThenText;

  const AuthenticatedWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.extraCss,
    this.autoClickText,
    this.autoClickDotMenuThenText,
  });

  @override
  State<AuthenticatedWebViewScreen> createState() =>
      _AuthenticatedWebViewScreenState();
}

class _AuthenticatedWebViewScreenState extends State<AuthenticatedWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  /// Supaya [AuthenticatedWebViewScreen.autoClickText] cuma dipicu sekali.
  bool _autoClickedText = false;

  /// URL pertama yang dimuat — dipakai untuk mendeteksi navigasi setelah
  /// form disubmit (mis. "Create Course" → redirect ke halaman course baru).
  String? _initialUrl;

  /// Tandai bahwa halaman pertama sudah selesai dimuat. Navigasi baru
  /// SETELAH flag ini aktif, ke URL yang BERBEDA dari [_initialUrl], berarti
  /// form telah disubmit → pop screen kembali ke Flutter.
  bool _firstPageFinished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      // Debug sementara — dipakai WebViewClickHelper untuk melaporkan hasil
      // AUTO_CLICK/MODAL_PROBE lewat `adb logcat`. Sebelumnya layar ini
      // tidak punya channel ini sama sekali (laporannya dibuang diam2 lewat
      // guard `if (window.TitcDebug)`), aman ditambahkan karena murni
      // tambahan (tidak mengubah perilaku call site manapun yang sudah ada).
      ..addJavaScriptChannel(
        'TitcDebug',
        onMessageReceived: (message) {
          // ignore: avoid_print
          print('WEBVIEW_DOM: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Setelah autoClick dipicu dan halaman pertama sudah selesai
            // dimuat, kalau ada navigasi ke URL yang berbeda dari URL awal
            // itu berarti form sudah disubmit (mis. Create Course redirect ke
            // halaman course baru). Pop screen supaya user tidak terlontar
            // ke tampilan website penuh.
            if (_firstPageFinished && _autoClickedText && _initialUrl != null) {
              final reqUrl = request.url;
              final base = _initialUrl!.split('?').first.split('#').first;
              final req = reqUrl.split('?').first.split('#').first;
              if (req != base) {
                // Jangan navigate — pop Flutter screen saja.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context, true);
                  }
                });
                return NavigationDecision.prevent;
              }
            }
            // Cegah webview melempar user ke browser eksternal (Chrome)
            // Biarkan semua navigasi tetap di dalam aplikasi
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            // Simpan URL pertama saat mulai loading
            _initialUrl ??= url;
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            _firstPageFinished = true;
            // Inject CSS inside an IIFE to avoid "Identifier 'style' has already been declared" error
            await _controller.runJavaScript('''
              (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                /* Sembunyikan Header dan Footer default WordPress & FCOM */
                /* Sembunyikan semua elemen Header dan Footer dari WordPress Theme (Astra, OceanWP, Elementor, BuddyBoss) */
                header, .site-header, #masthead, .ast-site-header, .elementor-location-header,
                footer, .site-footer, #colophon, .ast-site-footer, .elementor-location-footer, .footer-widgets,
                .bb-mobile-panel, .bb-mobile-header, .header-inner, .buddypanel,
                
                /* Sembunyikan elemen bawaan Fluent Community UI */
                nav, .fcom-sidebar, .fcom_page_header, .fcom-bottom-nav, .fcom-mobile-nav, .fcom-app-header,
                .fcom_sidebar, .fcom_bottom_nav, .fcom_mobile_nav, .fcom_app_header,
                .fc-header, .fc-mobile-header, .fc-top-bar, .fc-app-header, .fc-mobile-nav, .fc-bottom-bar,
                #fc-app-header, #fc-mobile-nav, .fluent-community-header, .fluent-community-footer,
                .fc-mobile-bottom-nav, .fc-mobile-nav-wrap, .fc-top-nav {
                  display: none !important;
                }
                
                /* Paksa body untuk terlihat seperti aplikasi native */
                body {
                  background-color: #F7F9FC !important;
                  padding-top: 0 !important;
                  padding-bottom: 0 !important;
                  margin: 0 !important;
                }
                
                /* Container utama form dibuat menyatu dengan background */
                .fcom-main-content, .fcom-settings-wrapper, .fluent_community_wrapper {
                  padding: 16px !important;
                  max-width: 100% !important;
                  border: none !important;
                  box-shadow: none !important;
                  background: transparent !important;
                  margin-top: 0 !important;
                }
                
                /* Desain Card untuk setiap bagian (Bio, Socials, Password) */
                .fcom-settings-card, .fcom_settings_section {
                  background: white !important;
                  border-radius: 12px !important;
                  padding: 20px !important;
                  margin-bottom: 20px !important;
                  box-shadow: 0px 4px 12px rgba(0,0,0,0.03) !important;
                  border: 1px solid #eee !important;
                }
                
                /* Desain Input fields ala Flutter */
                input[type="text"], input[type="email"], input[type="password"], textarea, select {
                  width: 100% !important;
                  border-radius: 8px !important;
                  border: 1px solid #DDDDDD !important;
                  padding: 14px 16px !important;
                  font-size: 14px !important;
                  background-color: white !important;
                  color: #333 !important;
                  outline: none !important;
                  box-sizing: border-box !important;
                }
                
                input:focus, textarea:focus {
                  border-color: #1E5AF5 !important;
                  box-shadow: 0 0 0 1px #1E5AF5 !important;
                }
                
                /* Desain Tombol ala Flutter ElevatedButton */
                button, .fcom-btn, input[type="submit"] {
                  background-color: #1E5AF5 !important;
                  color: white !important;
                  border-radius: 8px !important;
                  padding: 12px 24px !important;
                  border: none !important;
                  font-weight: 600 !important;
                  font-size: 14px !important;
                  cursor: pointer !important;
                  width: 100% !important;
                  display: block !important;
                  margin-top: 10px !important;
                }
                
                /* Hilangkan label yang tidak penting atau sesuaikan font */
                label {
                  font-weight: 600 !important;
                  font-size: 14px !important;
                  color: #444 !important;
                  margin-bottom: 8px !important;
                  display: block !important;
                }
                
                /* Extra CSS dari parameter */
                ${widget.extraCss ?? ''}
              `;
              document.head.appendChild(style);
              })();
            ''');

            if (widget.autoClickText != null && !_autoClickedText) {
              _autoClickedText = true;
              WebViewClickHelper.clickElementByText(_controller, widget.autoClickText!);
            }
            if (widget.autoClickDotMenuThenText != null && !_autoClickedText) {
              _autoClickedText = true;
              WebViewClickHelper.clickDotMenuThenText(
                _controller,
                widget.autoClickDotMenuThenText!,
              );
            }

            // Beri waktu sejenak agar CSS selesai dirender sebelum menampilkan WebView
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          },
        ),
      );

    _initCookiesAndLoad();
  }

  Future<void> _initCookiesAndLoad() async {
    await WebViewCookieHelper.setupCookies();

    _controller.loadRequest(
      Uri.parse(widget.url),
      headers: {
        'X-App-Client': 'titc-mobile',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        scrolledUnderElevation: 3,
        shadowColor: kShadowColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black87),
          // Sebagian pemanggil memakai judul panjang (mis. link cepat di Home
          // "Daftar Tes TOEFL ITP Resmi ETS"), yang tanpa ini meluber.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

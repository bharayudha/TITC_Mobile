import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/constants/app_colors.dart';

class AuthenticatedWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const AuthenticatedWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<AuthenticatedWebViewScreen> createState() =>
      _AuthenticatedWebViewScreenState();
}

class _AuthenticatedWebViewScreenState extends State<AuthenticatedWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);
            // Sembunyikan Header dan Footer bawaan website agar terasa seperti Native App
            await _controller.runJavaScript('''
              const style = document.createElement('style');
              style.innerHTML = `
                /* Sembunyikan semua elemen web yang tidak perlu */
                header, .site-header, #masthead, footer, .site-footer, #colophon, .fcom-sidebar, .fcom_page_header {
                  display: none !important;
                }
                
                /* Reset Body agar penuh layar tanpa margin web */
                body, html, .site-content, .fcom-app-wrapper {
                  padding: 0 !important;
                  margin: 0 !important;
                  background-color: #F7F9FC !important; /* Warna background Flutter App */
                }
                
                /* Container utama form dibuat menyatu dengan background */
                .fcom-main-content, .fcom-settings-wrapper {
                  padding: 16px !important;
                  max-width: 100% !important;
                  border: none !important;
                  box-shadow: none !important;
                  background: transparent !important;
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
                  border-radius: 10px !important;
                  padding: 16px !important;
                  font-size: 15px !important;
                  font-weight: 600 !important;
                  width: 100% !important;
                  border: none !important;
                  text-align: center !important;
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
              `;
              document.head.appendChild(style);
            ''');
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
            WebViewCookie(
              name: name,
              value: value,
              domain: 'titc.or.id',
              path: '/',
            ),
          );
          // Tambahkan juga untuk domain dengan titik (wildcard)
          await cookieManager.setCookie(
            WebViewCookie(
              name: name,
              value: value,
              domain: '.titc.or.id',
              path: '/',
            ),
          );
        }
      }
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

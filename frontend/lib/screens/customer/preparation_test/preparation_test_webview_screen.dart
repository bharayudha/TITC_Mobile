import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';

const String preparationTestUrl =
    'https://titc.or.id/institutional-preparation-test/';

class PreparationTestWebviewScreen extends StatefulWidget {
  const PreparationTestWebviewScreen({super.key});

  @override
  State<PreparationTestWebviewScreen> createState() =>
      _PreparationTestWebviewScreenState();
}

class _PreparationTestWebviewScreenState
    extends State<PreparationTestWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) async {
            // Sembunyikan header/footer bawaan tema WordPress (kotak biru
            // "TITC Indonesia" + hamburger) supaya tidak dobel dengan AppBar
            // Flutter di atasnya. Injeksi CSS lewat JS hanya berlaku di sisi
            // WebView klien saat itu saja — TIDAK mengubah apa pun di server
            // atau tampilan yang dilihat pengunjung web asli.
            await _controller.runJavaScript('''
              (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                  header, .site-header, #masthead, .ast-site-header, .elementor-location-header,
                  footer, .site-footer, #colophon, .ast-site-footer, .elementor-location-footer, .footer-widgets {
                    display: none !important;
                  }
                  body {
                    padding-top: 0 !important;
                    margin: 0 !important;
                  }
                `;
                document.head.appendChild(style);
              })();
            ''');
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(preparationTestUrl));
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
        title: const Text(
          'Preparation Test',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // Penutup solid (bukan cuma spinner mengambang) supaya header web
          // asli tidak sempat kelihatan sekilas sebelum CSS injeksi selesai
          // menyembunyikannya di onPageFinished.
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

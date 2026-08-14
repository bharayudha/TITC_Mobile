import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/top_app_bar.dart';
import 'package:magang_titc/services/webview_cookie_helper.dart';

String _jsStringLiteral(String value) => jsonEncode(value);

class AdminActionWebViewScreen extends StatefulWidget {
  final String targetUrl;
  final String title;
  
  /// Type of action: 'button' or 'dot_menu'
  final String actionType;
  
  /// For 'button', text to look for inside button.el-button
  final String? buttonText;
  
  /// For 'dot_menu', the text inside the dropdown menu item
  final String? menuItemText;

  const AdminActionWebViewScreen({
    super.key,
    required this.targetUrl,
    required this.title,
    this.actionType = 'button',
    this.buttonText,
    this.menuItemText,
  });

  @override
  State<AdminActionWebViewScreen> createState() => _AdminActionWebViewScreenState();
}

class _AdminActionWebViewScreenState extends State<AdminActionWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isPrewarming = false;

  String get _injectScript => '''
(function() {
  'use strict';

  function injectCSS() {
    if (document.getElementById('titc-admin-action-styles')) return;
    var s = document.createElement('style');
    s.id = 'titc-admin-action-styles';
    s.textContent = `
      /* Hide all standard portal UI elements to leave ONLY the drawer visible */
      .fcom_top_menu, .spaces, .space_contents, #fluent_community_sidebar_menu,
      .fcom_sidebar_wrap, .fcom_side_footer, .space_opener, .fcom_mobile_menu,
      .fcom_space_opener_btn, header, .site-header, #masthead, .ast-site-header,
      .elementor-location-header, footer, .site-footer, #colophon,
      .ast-site-footer, .elementor-location-footer, .footer-widgets,
      .bb-mobile-panel, .bb-mobile-header, .spectra-header-template,
      .fcom_page_title, nav.fcom_desktop_only, .fhr_content_layout_header,
      .fhr_content_layout_body, aside, .el-main, .fcom_main_side_wrap, .fhr_home {
        display: none !important;
        opacity: 0 !important;
        height: 0 !important;
        pointer-events: none !important;
      }
      
      body, html {
        background: transparent !important;
      }
      
      /* Ensure drawer is fully visible and covers the whole screen */
      .el-drawer__wrapper, .el-overlay {
        background: rgba(0, 0, 0, 0.5) !important;
      }
      
      /* Force drawer to 100% width on mobile */
      .el-drawer {
        width: 100% !important;
      }
    `;
    document.head.appendChild(s);
  }

  injectCSS();
  
  // Monitor when the drawer closes to navigate back
  let drawerWasOpen = false;
  let checkInterval = setInterval(function() {
    var drawer = document.querySelector('.el-drawer');
    if (drawer && !drawerWasOpen) {
      drawerWasOpen = true;
    } else if (!drawer && drawerWasOpen) {
      // Drawer closed, notify Flutter to pop the screen
      clearInterval(checkInterval);
      if (window.TitcAdminAction) {
        window.TitcAdminAction.postMessage('DRAWER_CLOSED');
      }
    }
  }, 500);

})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'TitcAdminAction',
        onMessageReceived: (message) {
          if (message.message == 'DRAWER_CLOSED') {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            if (_isPrewarming) return;
            
            await _controller.runJavaScript(_injectScript);
            
            if (widget.actionType == 'button' && widget.buttonText != null) {
              await _controller.runJavaScript('''
                setTimeout(() => {
                  const buttons = Array.from(document.querySelectorAll('button.el-button.fcom_primary_button'));
                  const targetBtn = buttons.find(b => b.textContent.includes(${_jsStringLiteral(widget.buttonText!)}));
                  if (targetBtn) targetBtn.click();
                }, 500);
              ''');
            } else if (widget.actionType == 'dot_menu' && widget.menuItemText != null) {
              await _controller.runJavaScript('''
                setTimeout(() => {
                  const dotBtn = document.querySelector('.fcom_dot_menu');
                  if (dotBtn) {
                    dotBtn.click();
                    setTimeout(() => {
                      const items = Array.from(document.querySelectorAll('li.el-dropdown-menu__item'));
                      const targetItem = items.find(i => i.textContent.includes(${_jsStringLiteral(widget.menuItemText!)}));
                      if (targetItem) targetItem.click();
                    }, 800);
                  }
                }, 500);
              ''');
            }
            
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) setState(() => _isLoading = false);
            });
          },
        ),
      );

    _initCookiesAndLoad();
  }

  Future<void> _initCookiesAndLoad() async {
    final hasCookies = await WebViewCookieHelper.setupCookies();
    if (hasCookies) {
      _isPrewarming = true;
      await _controller.loadRequest(Uri.parse('https://titc.or.id/portal/'));
      await Future.delayed(const Duration(milliseconds: 2000));
      _isPrewarming = false;
    }
    await _controller.loadRequest(Uri.parse(widget.targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
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
                  Text('Menyiapkan formulir...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

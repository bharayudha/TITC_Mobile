import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants/app_colors.dart';

const String preparationTestUrl =
    'https://titc.or.id/preparation-test-athority-dydfdh353536sfjsfsfywff90adajqadahsafaf835jc7fsisnfhgsjsgd/';

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
          onPageFinished: (_) => setState(() => _isLoading = false),
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

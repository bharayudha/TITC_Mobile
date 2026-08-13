import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';

/// Drawer khusus untuk halaman `/portal/admin/`, meniru struktur sidebar
/// "Portal Settings" milik web (Portal Settings / Course Management /
/// Reports) alih-alih menu member biasa (Membership Areas / Courses).
///
/// Tap item TIDAK membangun URL sendiri — URL sub-halaman admin tidak
/// mengikuti pola label-nya (contoh: "Managers" slug aslinya `moderators`,
/// bukan `managers`, terbukti dari cURL DevTools user). Alih-alih menebak,
/// tap item mencari link di sidebar web (yang sudah dibuat tampil lewat
/// CSS di [SpaceWebViewScreen]) yang teksnya mengandung label ini, lalu
/// men-simulasikan klik lewat JS. Ini otomatis selalu akurat mengikuti apa
/// pun yang web render, tanpa perlu di-update manual kalau slug web berubah.
class AdminPortalDrawer extends StatelessWidget {
  final WebViewController controller;

  /// Label item yang sedang di-highlight aktif.
  final String? activeLabel;

  /// Dipanggil saat item di-tap, dengan labelnya — dipakai
  /// [SpaceWebViewScreen] untuk update [activeLabel] (dilacak dari tap,
  /// bukan dibaca dari DOM web — lihat catatan di [SpaceWebViewScreen]).
  final ValueChanged<String>? onItemSelected;

  const AdminPortalDrawer({
    super.key,
    required this.controller,
    this.activeLabel,
    this.onItemSelected,
  });

  static const _portalSettingsItems = <(String, IconData)>[
    ('General', PhosphorIconsRegular.identificationBadge),
    ('Customizations', PhosphorIconsRegular.paintBrush),
    ('Managers', PhosphorIconsRegular.usersThree),
    ('Email Settings', PhosphorIconsRegular.envelopeSimple),
    ('Features & Addons', PhosphorIconsRegular.puzzlePiece),
    ('Manage Topics', PhosphorIconsRegular.tag),
    ('Space Groups', PhosphorIconsRegular.squaresFour),
    ('Menu Settings', PhosphorIconsRegular.listBullets),
    ('Content Moderation', PhosphorIconsRegular.shieldCheck),
    ('Privacy Settings', PhosphorIconsRegular.lockKey),
    ('Access Management', PhosphorIconsRegular.pencilSimpleLine),
    ('Incoming Webhook', PhosphorIconsRegular.plugsConnected),
    ('Tools', PhosphorIconsRegular.wrench),
  ];

  static const _courseManagementItems = <(String, IconData)>[
    ('Manage Courses', PhosphorIconsRegular.graduationCap),
  ];

  static const _reportsItems = <(String, IconData)>[
    ('Analytics', PhosphorIconsRegular.chartBar),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const AppDivider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildBackToHome(context),
                  const AppDivider(),
                  _buildSectionLabel('Portal Settings'),
                  for (final (label, icon) in _portalSettingsItems)
                    _buildItem(context, label, icon),
                  const AppDivider(),
                  _buildSectionLabel('Course Management'),
                  for (final (label, icon) in _courseManagementItems)
                    _buildItem(context, label, icon),
                  const AppDivider(),
                  _buildSectionLabel('Reports'),
                  for (final (label, icon) in _reportsItems)
                    _buildItem(context, label, icon),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: 'TITC ',
                  style: TextStyle(color: AppColors.primary),
                ),
                TextSpan(
                  text: 'Indonesia',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.x,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Meniru "← Back to home" di sidebar web. MainShell selalu jadi route
  /// pertama (lihat `top_app_bar.dart`), jadi menutup semua halaman sampai
  /// yang pertama = pulang ke Home — pola yang sama dipakai judul navbar.
  Widget _buildBackToHome(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: const SizedBox(
        width: 24,
        child: Center(
          child: PhosphorIcon(
            PhosphorIconsRegular.arrowLeft,
            color: Colors.black87,
            size: 20,
          ),
        ),
      ),
      title: const Text(
        'Back to home',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () =>
          Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, String label, IconData icon) {
    final isActive = activeLabel == label;
    final fgColor = isActive ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isActive,
        selectedTileColor: AppColors.primary,
        leading: SizedBox(
          width: 24,
          child: Center(child: PhosphorIcon(icon, color: fgColor, size: 20)),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onItemSelected?.call(label);
          _clickWebSidebarLink(label);
        },
      ),
    );
  }

  /// Cari elemen di sidebar admin web (`aside.el-aside`) yang teksnya
  /// MENGANDUNG [label] (bukan sama persis — beberapa item web punya
  /// ikon/badge di dalam elemen yang sama, jadi textContent bisa
  /// kebawa spasi/karakter ekstra), lalu klik `<a>` terdekat.
  ///
  /// Dilaporkan lewat channel `TitcDebug` yang sudah ada di
  /// [SpaceWebViewScreen] (muncul sebagai log `WEBVIEW_DOM:`) supaya kalau
  /// masih gagal, penyebabnya kelihatan dari log alih-alih menebak lagi.
  void _clickWebSidebarLink(String label) {
    final escaped = label
        .replaceAll('\\', r'\\')
        .replaceAll("'", r"\'");
    controller.runJavaScript('''
      (function() {
        function report(msg) {
          if (window.TitcDebug) window.TitcDebug.postMessage('ADMIN_DRAWER: ' + msg);
        }
        // Sidebar "Portal Settings" dirender di dalam .space_contents,
        // dikonfirmasi lewat probe DOM (bukan aside.el-aside seperti
        // dugaan awal di Space/Course).
        var sidebar = document.querySelector('.space_contents');
        if (!sidebar) {
          // Fallback kalau strukturnya berubah lagi: cari langsung dari
          // teks "Portal Settings" dan laporkan ancestor-nya supaya
          // selector yang benar ketahuan dari log, bukan tebakan lagi.
          var all = document.querySelectorAll('body *');
          var anchor = null;
          for (var k = 0; k < all.length; k++) {
            var t = (all[k].textContent || '').trim();
            if (t.indexOf('Portal Settings') === 0 && t.length < 200) {
              anchor = all[k];
            }
          }
          if (!anchor) { report('.space_contents & teks "Portal Settings" tidak ketemu sama sekali'); return; }
          var chain = [];
          var node = anchor;
          for (var d = 0; d < 6 && node; d++) {
            chain.push(node.tagName + (node.className ? '.' + String(node.className).replace(/\\s+/g, '.') : ''));
            node = node.parentElement;
          }
          report('.space_contents tidak ketemu. Ancestor dari teks "Portal Settings": ' + chain.join(' < '));
          return;
        }
        var all = sidebar.querySelectorAll('a, li, [role="menuitem"], button');
        var match = null;
        for (var i = 0; i < all.length; i++) {
          var text = (all[i].textContent || '').replace(/\\s+/g, ' ').trim();
          if (text.indexOf('$escaped') !== -1) { match = all[i]; break; }
        }
        if (!match) {
          var seen = [];
          for (var j = 0; j < Math.min(all.length, 20); j++) {
            seen.push((all[j].textContent || '').replace(/\\s+/g, ' ').trim());
          }
          report('tidak ketemu match untuk "$escaped". Teks yang ada: ' + JSON.stringify(seen));
          return;
        }
        // Kalau yang match bukan <a>, cari <a> di dalam/di sekitarnya.
        var link = match.tagName === 'A' ? match : match.querySelector('a');
        var target = link || match;
        report('klik: ' + target.tagName + ' href=' + (target.href || '-'));
        target.click();
      })();
    ''');
  }
}

import 'package:webview_flutter/webview_flutter.dart';

/// Simulasi klik pada elemen web berdasarkan teksnya, dipakai bersama oleh
/// [SpaceWebViewScreen] dan [AuthenticatedWebViewScreen] supaya logikanya
/// tidak diduplikasi di dua tempat (pola yang sama dengan
/// [WebViewCookieHelper]).
class WebViewClickHelper {
  /// Cari elemen di SELURUH halaman yang teksnya cocok dengan [text], lalu
  /// `.click()`. Beda dengan `AdminPortalDrawer.clickSidebarLink` yang
  /// dibatasi ke dalam `.space_contents` (sidebar admin) — ini dipakai untuk
  /// tombol aksi yang letaknya di toolbar halaman biasa, mis. "New Space".
  ///
  /// Berisi retry beberapa kali dengan jeda karena elemen targetnya belum
  /// tentu sudah ter-mount tepat saat dipanggil (mis. dipanggil otomatis
  /// begitu halaman selesai dimuat). Dilaporkan lewat channel `TitcDebug`
  /// (muncul sebagai log `WEBVIEW_DOM: AUTO_CLICK: ...`) supaya kalau gagal,
  /// penyebabnya kelihatan dari log alih-alih menebak lagi.
  static void clickElementByText(WebViewController controller, String text) {
    final escaped = text.replaceAll('\\', r'\\').replaceAll("'", r"\'");
    controller.runJavaScript('''
      (function() {
        function report(msg) {
          if (window.TitcDebug) window.TitcDebug.postMessage('AUTO_CLICK: ' + msg);
        }
        function attempt(tries) {
          var candidates = document.querySelectorAll('button, a, [role="button"]');
          var exact = null;
          var partial = null;
          for (var i = 0; i < candidates.length; i++) {
            var t = (candidates[i].textContent || '').replace(/\\s+/g, ' ').trim();
            if (t === '$escaped') { exact = candidates[i]; break; }
            if (!partial && t.indexOf('$escaped') !== -1) { partial = candidates[i]; }
          }
          var target = exact || partial;
          if (!target) {
            if (tries < 8) { setTimeout(function() { attempt(tries + 1); }, 300); return; }
            report('tombol "$escaped" tidak ketemu setelah beberapa percobaan');
            return;
          }
          report('klik (percobaan ' + tries + '): ' + target.tagName + ' text="' +
            (target.textContent || '').trim().substring(0, 40) + '"');
          target.click();

          // Debug sementara: laporkan struktur modal/dialog yang muncul
          // SESUDAH klik, supaya CSS penyesuaiannya (extraCss) tidak perlu
          // menebak nama class — sering beda dari .el-dialog/.el-drawer yang
          // dipakai halaman lain.
          setTimeout(function() {
            var modalSelectors = '.el-dialog, .el-drawer, .el-overlay, .modal, [class*="dialog" i], [class*="modal" i], [role="dialog"]';
            var modals = document.querySelectorAll(modalSelectors);
            var seen = [];
            for (var m = 0; m < modals.length; m++) {
              var el = modals[m];
              var rect = el.getBoundingClientRect();
              seen.push(el.tagName + '.' + String(el.className || '').replace(/\\s+/g, '.') +
                ' [' + Math.round(rect.width) + 'x' + Math.round(rect.height) + ' top=' + Math.round(rect.top) + ']');
            }
            report('MODAL_PROBE: ' + JSON.stringify(seen));
          }, 500);
        }
        attempt(0);
      })();
    ''');
  }

  /// Sama seperti [clickElementByText], tapi untuk trigger dua langkah:
  /// klik dulu tombol "⋮" (`.fcom_dot_menu`) untuk membuka dropdown-nya,
  /// baru klik salah satu isi dropdown lewat teksnya. Dipakai untuk menu
  /// seperti "Welcome Banner"/"Manage Links" di header Feed, yang
  /// pemicunya ikon polos tanpa teks (jadi tidak bisa dicari lewat
  /// [clickElementByText] biasa).
  ///
  /// `.fcom_dot_menu` dipakai ULANG di banyak tempat pada satu halaman
  /// (satu per item feed, ditambah satu untuk header) — dipilih yang
  /// PALING ATAS (`top` terkecil) karena trigger header selalu di posisi
  /// paling atas halaman, sebelum item feed manapun sempat dirender.
  static void clickDotMenuThenText(WebViewController controller, String menuItemText) {
    final escaped = menuItemText.replaceAll('\\', r'\\').replaceAll("'", r"\'");
    controller.runJavaScript('''
      (function() {
        function report(msg) {
          if (window.TitcDebug) window.TitcDebug.postMessage('AUTO_CLICK: ' + msg);
        }
        function findTopmostDotMenu() {
          var candidates = document.querySelectorAll('.fcom_dot_menu');
          var best = null;
          var bestTop = Infinity;
          for (var i = 0; i < candidates.length; i++) {
            var rect = candidates[i].getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) continue;
            if (rect.top < bestTop) { bestTop = rect.top; best = candidates[i]; }
          }
          return best;
        }
        function attemptDotMenu(tries) {
          var dotMenu = findTopmostDotMenu();
          if (!dotMenu) {
            if (tries < 8) { setTimeout(function() { attemptDotMenu(tries + 1); }, 300); return; }
            report('.fcom_dot_menu tidak ketemu setelah beberapa percobaan');
            return;
          }
          report('klik dot-menu (percobaan ' + tries + '), top=' + Math.round(dotMenu.getBoundingClientRect().top));
          dotMenu.click();
          setTimeout(function() { attemptText(0); }, 300);
        }
        function attemptText(tries) {
          var candidates = document.querySelectorAll('button, a, [role="button"], li, span, div');
          var exact = null;
          var partial = null;
          for (var i = 0; i < candidates.length; i++) {
            var t = (candidates[i].textContent || '').replace(/\\s+/g, ' ').trim();
            if (t === '$escaped') { exact = candidates[i]; break; }
            if (!partial && t.indexOf('$escaped') !== -1 && t.length < '$escaped'.length + 20) { partial = candidates[i]; }
          }
          var target = exact || partial;
          if (!target) {
            if (tries < 8) { setTimeout(function() { attemptText(tries + 1); }, 300); return; }
            report('menu item "$escaped" tidak ketemu setelah dot-menu diklik');
            return;
          }
          report('klik menu item (percobaan ' + tries + '): ' + target.tagName + ' text="' +
            (target.textContent || '').trim().substring(0, 40) + '"');
          target.click();

          setTimeout(function() {
            var modalSelectors = '.el-dialog, .el-drawer, .el-overlay, .modal, [class*="dialog" i], [class*="modal" i], [role="dialog"]';
            var modals = document.querySelectorAll(modalSelectors);
            var seen = [];
            for (var m = 0; m < modals.length; m++) {
              var el = modals[m];
              var rect = el.getBoundingClientRect();
              seen.push(el.tagName + '.' + String(el.className || '').replace(/\\s+/g, '.') +
                ' [' + Math.round(rect.width) + 'x' + Math.round(rect.height) + ' top=' + Math.round(rect.top) + ']');
            }
            report('MODAL_PROBE: ' + JSON.stringify(seen));
          }, 500);
        }
        attemptDotMenu(0);
      })();
    ''');
  }
}

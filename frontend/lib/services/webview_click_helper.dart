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
        }
        attempt(0);
      })();
    ''');
  }
}

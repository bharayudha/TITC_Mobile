/// CSS untuk modal post + komentar Fluent Community.
///
/// Post yang dibuka dari mana pun (ikon komentar di Home, notifikasi, dsb.)
/// dirender FCOM sebagai modal Element Plus (`.el-dialog` di dalam
/// `.el-overlay`) di atas halaman Space. Tanpa CSS ini modalnya tampil
/// sebagai kotak kecil melayang di atas latar gelap (persis versi
/// desktop-nya) alih-alih memenuhi layar seperti halaman native.
///
/// Ditaruh di satu tempat karena sebelumnya CSS ini disalin ke dua tempat
/// (`home_screen.dart` dan `notifications_popup.dart`), lalu salinannya
/// berbeda: versi notifikasi kehilangan aturan `__footer`, `button`, dan
/// `.fcom_dot_menu`, sehingga post yang dibuka dari notifikasi tampil beda
/// dari yang dibuka lewat ikon komentar di Home. Satu sumber = tidak bisa
/// menyimpang lagi.
///
/// Aman dipakai untuk halaman FCOM apa pun: semua aturannya hanya cocok
/// kalau `.el-dialog` memang ada di halaman itu, jadi tidak berefek apa-apa
/// pada halaman yang tidak memunculkan modal.
const String kFcomPostDialogCss = '''
  .el-overlay {
    background: transparent !important;
    position: fixed !important;
    inset: 0 !important;
  }
  .el-overlay-dialog {
    padding: 0 !important;
    display: block !important;
  }
  .el-dialog {
    width: 100% !important;
    max-width: 100% !important;
    height: 100vh !important;
    max-height: 100vh !important;
    margin: 0 !important;
    border-radius: 0 !important;
    box-shadow: none !important;
    display: flex !important;
    flex-direction: column !important;
    box-sizing: border-box !important;
  }
  .el-dialog__header {
    flex: none !important;
    padding: 12px 16px !important;
  }
  .el-dialog__body {
    flex: 1 1 auto !important;
    overflow-y: auto !important;
    -webkit-overflow-scrolling: touch !important;
    padding: 12px 16px !important;
  }
  .el-dialog__footer {
    flex: none !important;
    padding: 12px 16px !important;
  }
  /* Aturan tombol full-width dari style dasar tidak cocok untuk modal ini:
     like/reply/emoji/kirim-gambar/post-comment harus tetap tombol kecil
     sejajar, bukan block penuh lebar layar. */
  .el-dialog button {
    width: auto !important;
    display: inline-flex !important;
    margin-top: 0 !important;
  }
  /* Style dasar SpaceWebViewScreen menyembunyikan .fcom_dot_menu secara
     total (opacity 0 + pointer-events none) supaya HANYA bisa dipicu
     lewat tombol "⋮" kustom di app bar Flutter -- itu didesain untuk
     SATU dot-menu per halaman Space. Tapi di modal komentar, kelas yang
     sama dipakai ulang untuk tombol "⋮" milik SETIAP komentar (punya
     sendiri maupun punya orang lain), jadi aturan sembunyi-total itu ikut
     mematikan semuanya. Kembalikan tampil & bisa diklik normal di sini.
  */
  .el-dialog .fcom_dot_menu {
    opacity: 1 !important;
    pointer-events: auto !important;
    position: static !important;
    top: auto !important;
    right: auto !important;
  }
''';

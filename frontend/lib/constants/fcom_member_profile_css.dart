/// CSS khusus halaman profil member di Fluent Community
/// (`https://titc.or.id/portal/u/{username}`).
///
/// Menyembunyikan top-nav FCOM, sidebar kiri, footer WP, tapi MEMPERTAHANKAN
/// tab profil (About/Posts/Spaces/Courses) dan kolom konten utama agar
/// tetap bisa di-scroll dan diklik.
///
/// Ditaruh di satu tempat karena awalnya cuma ada di
/// `members_list_screen.dart` — saat profil dibuka dari notifikasi (klik
/// notifikasi "X started following you"), layar itu memakai
/// `AuthenticatedWebViewScreen` TANPA CSS ini sama sekali, sehingga jatuh ke
/// tampilan mentah situs. Sekarang kedua tempat menunjuk ke sini supaya
/// profil member selalu tampil sama, dari mana pun dibuka.
const String kFcomMemberProfileCss = '''
  /* Sembunyikan top-nav FCOM */
  .fcom_top_menu, .fcom_mobile_menu, .fcom_space_opener_btn {
    display: none !important;
  }
  /* Sembunyikan sidebar kiri (daftar spaces) */
  .spaces, .space_contents, #fluent_community_sidebar_menu,
  .fcom_sidebar_wrap, .fcom_side_footer, .space_opener,
  aside.el-aside:not(.fcom_resp_side) {
    display: none !important;
    width: 0 !important;
  }
  /* Sembunyikan header & footer WordPress */
  header, .site-header, #masthead, footer, .site-footer,
  #colophon, .bb-mobile-panel, .bb-mobile-header {
    display: none !important;
  }
  /* Hapus padding-top sisa dari top-menu yang sudah disembunyikan */
  body {
    padding-top: 0 !important;
    margin-top: 0 !important;
    overflow-x: hidden !important;
    background: #f5f6f8 !important;
  }
  /* Buat semua wrapper jadi full-width */
  .fcom_wrap, .fluent_com, .fhr_content, #fluent_comminity_body, .fhr_wrap {
    max-width: 100% !important;
    width: 100% !important;
    padding: 0 !important;
    margin: 0 !important;
    box-sizing: border-box !important;
  }
  .el-container {
    display: flex !important;
    flex-direction: column !important;
    width: 100% !important;
  }
  .el-main {
    width: 100% !important;
    padding: 0 !important;
    overflow: visible !important;
  }
  /* Profil: banner foto cover */
  .fcom_cover_photo_wrap {
    width: 100% !important;
    max-height: 160px !important;
    overflow: hidden !important;
  }
  /* Konten profil utama */
  .fcom_profile_wrap, .fcom_profile_content {
    width: 100% !important;
    max-width: 100% !important;
    padding: 0 12px 80px !important;
    box-sizing: border-box !important;
  }
  /* Tab navigasi profil (About/Posts/Spaces/Courses) — JANGAN disembunyikan */
  .fcom_profile_nav, .fcom_profile_tabs, .fcom-tabs {
    display: flex !important;
    overflow-x: auto !important;
    -webkit-overflow-scrolling: touch !important;
  }
  /* Kembalikan button ke inline agar tombol Follow/Message tidak full-width */
  button {
    width: auto !important;
    display: inline-flex !important;
    margin-top: 0 !important;
  }
  /* Right sidebar (Recent Activities) tampil di bawah konten utama */
  .fcom_resp_side, aside.fcom_resp_side {
    display: block !important;
    width: 100% !important;
  }
''';

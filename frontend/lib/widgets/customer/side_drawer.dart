import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:magang_titc/constants/app_colors.dart';
import 'package:magang_titc/constants/app_text_styles.dart';
import 'package:magang_titc/models/course_model.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/services/portal_navigator.dart';

/// Versi drawer dengan ikon emoji: tampilannya mengikuti font emoji bawaan
/// perangkat (Noto di Android, Apple Color Emoji di iOS).
class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  /// Daftar course, dipakai untuk menentukan item mana yang diberi gembok.
  ///
  /// Dibuat sekali di [initState], **bukan** di `build()`: `build` bisa
  /// berjalan berkali-kali (mis. saat drawer beranimasi), dan membuat Future
  /// baru tiap kali akan membuat `FutureBuilder` balik ke keadaan loading
  /// terus-menerus sehingga gembok berkedip.
  late final Future<List<CourseModel>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    // Kalau tab Courses sudah pernah dibuka, datanya dipakai langsung supaya
    // gembok tampil seketika tanpa menunggu jaringan. Cache ini dibuang
    // otomatis oleh PortalNavigator setiap kali enroll berhasil, jadi tidak
    // ada risiko gembok tertinggal di kelas yang baru saja dibuka aksesnya.
    final cached = ApiService.cachedCourses;
    _coursesFuture = cached != null
        ? Future<List<CourseModel>>.value(cached)
        // Kegagalan sengaja ditelan: drawer tetap harus bisa dipakai walau
        // status enroll tidak diketahui. Hasilnya daftar kosong → tidak ada
        // gembok, bukan gembok di semua item.
        : ApiService.fetchCourses().catchError(
            (_) => const <CourseModel>[],
          );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const AppDivider(),
            // Daftar menu mengisi ruang tersisa dan bisa di-scroll sendiri,
            // sehingga Settings & Logout tetap menempel di bawah.
            Expanded(
              child: FutureBuilder<List<CourseModel>>(
                future: _coursesFuture,
                builder: (context, snapshot) {
                  // `snapshot.data` masih null selama daftar course dimuat.
                  // Diteruskan apa adanya — `_buildCourseItem` memperlakukan
                  // null sebagai "belum tahu" dan tidak menggambar gembok.
                  final courses = snapshot.data;
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSectionLabel('MEMBERSHIP AREAS'),
                      _buildSpaceItem(context, '🔥', 'FREE Placement Test'),
                      _buildSpaceItem(context, '🖥️', 'Institutional Prep Test'),
                      _buildSpaceItem(context, '💻', 'TOEFL - Mockup Test'),
                      _buildSpaceItem(context, '🔖', 'Promo Khusus Member'),
                      _buildSpaceItem(context, '📰', 'Update - Announcement'),
                      _buildSpaceItem(context, '🚀', 'Update - Certification'),
                      const AppDivider(),
                      _buildSectionLabel('TOEFL Preparation'),
                      _buildCourseItem(context, '🎓', '4 Hours Intensive', courses),
                      _buildCourseItem(context, '🎓', '3 Meeting Courses', courses),
                      _buildCourseItem(context, '🎓', '7 Meeting Courses', courses),
                      _buildCourseItem(context, '🎓', '10 Meeting Courses', courses),
                      _buildCourseItem(context, '🎓', '15 Meeting Courses', courses),
                      _buildCourseItem(context, '🎓', '20 Meeting Courses', courses),
                      const AppDivider(),
                      _buildSectionLabel('English for Specific Purposes'),
                      _buildCourseItem(context, '📚', 'Structure and Grammar', courses),
                      _buildCourseItem(context, '🎧', 'Listening and Reading', courses),
                      _buildCourseItem(
                        context,
                        '🎙️',
                        'Speaking and Conversation',
                        courses,
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
            // Settings hanya untuk admin, jadi FutureBuilder-nya bisa saja
            // tidak merender apa pun — divider & spacing ikut di dalam
            // builder supaya user biasa tidak melihat ruang kosong ganjil.
            FutureBuilder<bool>(
              future: AuthService.isCurrentUserAdmin(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return Column(
                  children: [
                    const AppDivider(),
                    const SizedBox(height: 4),
                    _buildIconItem(
                      icon: PhosphorIconsRegular.gear,
                      label: 'Settings',
                      onTap: () => _openAdminPortal(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
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
          // Tombol tutup tetap ikon vektor: ini kontrol UI, bukan item menu.
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

  /// Item MEMBERSHIP AREAS. Tiap label di sini adalah judul Space di Fluent
  /// Community, jadi tap-nya membuka halaman space yang sama seperti di web.
  Widget _buildSpaceItem(BuildContext context, String emoji, String label) {
    return _buildItem(
      emoji: emoji,
      label: label,
      onTap: () => _openSpaceByTitle(context, label),
    );
  }

  /// Buka Space berdasarkan judulnya.
  ///
  /// Drawer ditutup lebih dulu, jadi `navigator` & `messenger` diambil
  /// sebelum pop — setelah itu `context` sudah tidak mounted.
  Future<void> _openSpaceByTitle(BuildContext context, String label) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    await PortalNavigator.openSpaceByTitle(
      navigator: navigator,
      messenger: messenger,
      title: label,
    );
  }

  /// Item TOEFL Preparation & English for Specific Purposes. Label di sini
  /// adalah judul Course di Fluent Community — secara teknis Space dengan
  /// `type: "course"`, tapi punya gerbang enrollment sendiri. Gerbang itulah
  /// yang ditandai gembok, meniru web.
  ///
  /// [courses] boleh null (daftar belum termuat). Gembok HANYA digambar kalau
  /// course-nya ketemu DAN `isEnrolled` bernilai false — jadi keadaan "belum
  /// tahu" tampil polos, bukan terkunci. Gembok palsu di kelas yang sudah
  /// dibayar jauh lebih merugikan daripada gembok yang telat muncul.
  Widget _buildCourseItem(
    BuildContext context,
    String emoji,
    String label,
    List<CourseModel>? courses,
  ) {
    final course = PortalNavigator.findCourseByTitle(courses, label);
    final isLocked = course != null && !course.isEnrolled;

    return _buildItem(
      emoji: emoji,
      label: label,
      // Tetap bisa ditekan walau terkunci — sama seperti web. Menutup aksesnya
      // di sini justru membuat user tidak punya jalan untuk tahu cara membuka
      // kelas; PortalNavigator sudah meneruskan pesan penolakan dari server
      // yang isinya lebih spesifik daripada kalimat generik buatan app.
      onTap: () => _openCourseByTitle(context, label),
      trailing: isLocked
          ? PhosphorIcon(
              PhosphorIconsRegular.lockSimple,
              size: 16,
              color: Colors.black26,
              // Pembaca layar tidak melihat ikon, jadi statusnya diucapkan.
              semanticLabel: 'Terkunci, belum punya akses',
            )
          : null,
    );
  }

  Future<void> _openCourseByTitle(BuildContext context, String label) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    await PortalNavigator.openCourseByTitle(
      navigator: navigator,
      messenger: messenger,
      title: label,
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

  Widget _buildItem({
    required String emoji,
    required String label,
    Color labelColor = Colors.black87,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return _buildTile(
      // Lebar emoji berbeda-beda antar perangkat, jadi dikunci dalam kotak
      // selebar 24 supaya teks menunya tetap sejajar.
      leading: Center(
        child: Text(emoji, style: emojiStyle()),
      ),
      label: label,
      labelColor: labelColor,
      onTap: onTap,
      trailing: trailing,
    );
  }

  Widget _buildIconItem({
    required IconData icon,
    required String label,
    Color color = Colors.black87,
    VoidCallback? onTap,
  }) {
    return _buildTile(
      leading: Center(child: PhosphorIcon(icon, color: color, size: 20)),
      label: label,
      labelColor: color,
      onTap: onTap,
    );
  }

  /// CSS dasar SpaceWebViewScreen menyembunyikan `.spaces` & `.space_contents`
  /// karena di halaman Space/Course itu adalah daftar Space kiri yang
  /// memang harus disembunyikan demi tampilan native. Tapi di
  /// `/portal/admin/`, sidebar "Portal Settings" (General, Managers, dst)
  /// ternyata dirender DI DALAM `.space_contents`/`.spaces` yang sama
  /// (dikonfirmasi lewat probe DOM: `H4 < DIV.fcom_admin_menu < DIV <
  /// DIV.space_contents < DIV.spaces` — bukan `aside.el-aside` seperti
  /// dugaan awal). Selector di sini disamakan persis dengan aturan dasarnya
  /// supaya spesifisitasnya sama — override yang datang belakangan baru
  /// menang kalau spesifisitasnya minimal setara, bukan cuma soal urutan.
  static const String _adminSidebarCss = '''
    .spaces, .space_contents {
      display: block !important;
      width: 100% !important;
      max-width: 100% !important;
      position: static !important;
      height: auto !important;
      max-height: none !important;
      overflow: visible !important;
      float: none !important;
      margin: 0 !important;
      padding: 8px 0 !important;
      box-sizing: border-box !important;
    }
  ''';

  /// Buka portal admin Fluent Community (`/portal/admin/`). Dipakai key
  /// SpaceWebViewScreen yang sama dengan Space/Course lain supaya shell
  /// CSS/JS-nya (yang sudah diverifikasi DOM) ikut berlaku di sini.
  void _openAdminPortal(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const SpaceWebViewScreen(
          title: 'Admin',
          overrideUrl: 'https://titc.or.id/portal/admin/',
          extraCss: _adminSidebarCss,
          useAdminDrawer: true,
        ),
      ),
    );
  }

  Widget _buildTile({
    required Widget leading,
    required String label,
    required Color labelColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: SizedBox(width: 24, child: leading),
      title: Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
      // Ikon status (mis. gembok) rata kanan seperti di web. `ListTile`
      // memberi trailing ukuran bebas, jadi tidak perlu dibatasi manual.
      trailing: trailing,
      // Menu yang belum tersambung sengaja dibiarkan tanpa handler supaya
      // tidak memberi efek ripple seolah-olah ada yang terjadi saat ditekan.
      onTap: onTap,
    );
  }
}

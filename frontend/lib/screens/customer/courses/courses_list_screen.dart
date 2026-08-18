import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/course_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';
import 'package:magang_titc/screens/shared/authenticated_webview_screen.dart';

/// Konten tab Courses. App bar, drawer, chat FAB, dan bottom nav dipasang
/// oleh [MainShell].
class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  bool _showAllCourses = true;
  late Future<List<CourseModel>> _coursesFuture;
  List<CourseModel> _allFetchedCourses = [];
  String _searchQuery = '';
  String _sortBy = 'Alphabetical';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCourses(useCache: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Pencarian dikirim ke server, bukan disaring di HP — lihat catatan yang
  /// sama di `spaces_list_screen.dart`. Jeda 450ms mengikuti layar Members.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == _searchQuery) return;
      _searchQuery = query;
      _loadCourses();
    });
  }

  /// Muat daftar courses. Kalau [useCache] true dan ada data lama, data itu
  /// langsung ditampilkan (tidak loading dari nol tiap kali tab ini dibuka
  /// lagi) sambil diam-diam refresh di belakang layar. Pull-to-refresh dan
  /// aksi enroll selalu memaksa fetch baru (useCache: false).
  void _loadCourses({bool useCache = false}) {
    // Cache hanya berisi daftar penuh, jadi tidak dipakai saat sedang mencari.
    final cached = _searchQuery.isEmpty ? ApiService.cachedCourses : null;
    if (useCache && cached != null) {
      setState(() {
        _allFetchedCourses = cached;
        _coursesFuture = Future.value(cached);
      });
      ApiService.fetchCourses()
          .then((courses) {
            if (mounted) {
              setState(() {
                _allFetchedCourses = courses;
                _coursesFuture = Future.value(courses);
              });
            }
          })
          .catchError((_) {});
      return;
    }

    setState(() {
      _coursesFuture = ApiService.fetchCourses(search: _searchQuery).then((
        courses,
      ) {
        _allFetchedCourses = courses;
        return courses;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // MainShell memakai `extendBodyBehindAppBar: true` supaya
    // TitcAppBar(glass: true) bisa nge-blur latar ini — tanpa offset ini,
    // header & konten akan mulai dari belakang app bar (tertutup).
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Latar glassmorphism — palet & orb sama persis dengan
          // SpacesListScreen/HomeScreen supaya konsisten antar tab.
          const Positioned.fill(child: ColoredBox(color: Colors.white)),

          // Header judul/tab/search/sort ikut scroll bersama daftar (BUKAN
          // pinned) — cuma latarnya dibuat menyatu dengan halaman (putih
          // polos, tanpa kartu kaca/blur/shadow terpisah).
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadCourses();
                await _coursesFuture;
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: topInset)),
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCoursesHeader(),
                        _buildSearchAndSortBar(),
                      ],
                    ),
                  ),
                  ..._buildCourseSlivers(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCourseSlivers() {
    return [
      FutureBuilder<List<CourseModel>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Belum ada course.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          final query = _searchQuery.toLowerCase();
          var filteredCourses = _allFetchedCourses.where((course) {
            // Filter tab Enrolled/All: murni pilihan lokal.
            if (!_showAllCourses && !course.isEnrolled) {
              return false;
            }

            // Penyaring cadangan — alasannya sama dengan yang dijelaskan di
            // `spaces_list_screen.dart`: kata kunci sudah dikirim ke
            // server, tapi belum terbukti endpoint-nya menghormati ?search=.
            if (query.isEmpty) return true;
            return course.title.toLowerCase().contains(query) ||
                course.description.toLowerCase().contains(query);
          }).toList();

          // Local Sorting
          if (_sortBy == 'Alphabetical') {
            filteredCourses.sort((a, b) => a.title.compareTo(b.title));
          } else if (_sortBy == 'Students') {
            filteredCourses.sort(
              (a, b) => b.studentsCount.compareTo(a.studentsCount),
            );
          }

          if (filteredCourses.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _searchQuery.isEmpty
                      ? 'Tidak ada course di kategori ini.'
                      : 'Tidak ada course yang cocok dengan "$_searchQuery".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 80,
              top: 8,
            ),
            sliver: SliverList.separated(
              itemCount: filteredCourses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildCourseCard(filteredCourses[index]);
              },
            ),
          );
        },
      ),
    ];
  }

  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: TextField(
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Course...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E5AF5),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Sort by: ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Theme(
                  data: Theme.of(context).copyWith(canvasColor: Colors.white),
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Color(0xFF1E5AF5),
                    ),
                    elevation: 8,
                    style: const TextStyle(
                      color: Color(0xFF1E5AF5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    dropdownColor: Colors.white,
                    underline: const SizedBox(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                        });
                      }
                    },
                    items: <String>['Alphabetical', 'Students']
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image & Tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Container(
                      height: 130,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      child: course.coverPhotoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: course.coverPhotoUrl,
                              httpHeaders: AuthService.imageAuthHeaders,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              // Batasi decode di memori sesuai ukuran tampil
                              // (bukan resolusi asli file) — kartu ini kecil
                              // tapi foto sumbernya bisa berukuran beberapa
                              // MB, jadi tanpa ini tiap kartu memboroskan RAM
                              // jauh melebihi yang terlihat di layar.
                              memCacheHeight: 260,
                              memCacheWidth: 800,
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: PhosphorIcon(
                                      PhosphorIconsRegular.image,
                                      color: Color(0xFFA5B4FC),
                                    ),
                                  ),
                            )
                          : const Center(
                              child: PhosphorIcon(
                                PhosphorIconsRegular.image,
                                color: Color(0xFFA5B4FC),
                              ),
                            ),
                    ),
                  ),
                  if (course.isEnrolled)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'Enrolled',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1E5AF5,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  width: 1.0,
                                ),
                              ),
                              child: course.logoUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: course.logoUrl,
                                      httpHeaders: AuthService.imageAuthHeaders,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 144,
                                      memCacheHeight: 144,
                                      errorWidget: (context, url, error) =>
                                          const Center(
                                            child: PhosphorIcon(
                                              PhosphorIconsRegular
                                                  .graduationCap,
                                              color: Color(0xFF818CF8),
                                            ),
                                          ),
                                    )
                                  : const Center(
                                      child: PhosphorIcon(
                                        PhosphorIconsRegular.graduationCap,
                                        color: Color(0xFF818CF8),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    PhosphorIconsRegular.bookOpen,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.lessonsCount} Lessons',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    PhosphorIconsRegular.users,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.studentsCount} Students',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      course.description.replaceAll(RegExp(r'<[^>]*>'), ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (course.isEnrolled) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (course.progress.clamp(0, 100)) / 100,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF1E5AF5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.progress}% selesai',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: course.isEnrolled
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: OutlinedButton(
                                  onPressed: () => _onCourseAction(course),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E5AF5),
                                    side: const BorderSide(
                                      color: Color(0xFF1E5AF5),
                                      width: 1.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(
                                      0xFF1E5AF5,
                                    ).withValues(alpha: 0.08),
                                  ),
                                  child: const Text(
                                    'Continue Learning',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: ElevatedButton(
                                  onPressed: () => _onCourseAction(course),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E5AF5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Enroll',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCourseAction(CourseModel course) async {
    if (course.isEnrolled) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpaceWebViewScreen(
            spaceSlug: course.slug,
            title: course.title,
            portalSegment: 'course',
            initialPath: 'lessons',
          ),
        ),
      );
      return;
    }

    final errorMessage = await ApiService.enrollCourse(course.id);
    if (!mounted) return;
    if (errorMessage == null) {
      _loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil mendaftar ke Course!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  static const double _coursesHeaderHeight = 66;

  /// Header Courses — menyatu dengan latar putih halaman (bukan lagi kartu
  /// kaca melayang), ikut scroll bersama daftar seperti bagian lain dari
  /// halaman. Mengikuti pola `_buildSpacesHeader` di SpacesListScreen.
  /// Semua handler (filter, New Course) tidak diubah.
  Widget _buildCoursesHeader() {
    return Container(
      width: double.infinity,
      height: _coursesHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Courses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChip('All Courses', selected: _showAllCourses),
              const SizedBox(width: 8),
              _buildFilterChip('My Courses', selected: !_showAllCourses),
              // Hanya admin/manager komunitas FCOM yang bisa membuat course baru
              // — tombolnya ditempelkan lewat AdminOnly, tidak mengubah apa pun
              // untuk user biasa (SizedBox.shrink kalau bukan admin).
              AdminOnly(
                builder: (context) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    onPressed: _openManageCourses,
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.plusCircle,
                      color: Color(0xFF1E5AF5),
                    ),
                    tooltip: 'New Course',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Buka halaman "New Course" di portal web secara langsung, lalu
  /// otomatis klik tombol "New Course" milik web (melalui autoClickText)
  /// sehingga drawer pembuatan course terbuka native.
  Future<void> _openManageCourses() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthenticatedWebViewScreen(
          title: 'New Course',
          url: 'https://titc.or.id/portal/courses',
          autoClickText: 'New Course',
          extraCss: _courseSpaceDrawerCss,
        ),
      ),
    );
    // Kalau course berhasil dibuat (webview detect redirect setelah submit),
    // refresh daftar courses supaya course baru langsung muncul.
    if (created == true && mounted) {
      _loadCourses();
    }
  }

  /// CSS agar drawer Element Plus (el-drawer) dari web tampil fullscreen
  /// di layar HP, bukan kotak kecil melayang.
  static const String _courseSpaceDrawerCss = '''
    .el-overlay {
      background: rgba(0,0,0,0.5) !important;
      position: fixed !important;
      inset: 0 !important;
      z-index: 2000 !important;
    }
    .el-drawer {
      width: 100% !important;
      max-width: 100% !important;
    }
    .el-drawer__header {
      padding: 16px !important;
    }
    .el-drawer__body {
      padding: 16px !important;
      overflow-y: auto !important;
      -webkit-overflow-scrolling: touch !important;
    }
    button {
      width: auto !important;
      display: inline-flex !important;
      margin-top: 0 !important;
    }
  ''';

  Widget _buildFilterChip(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _showAllCourses = label == 'All Courses'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1E5AF5).withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E5AF5).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E5AF5) : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

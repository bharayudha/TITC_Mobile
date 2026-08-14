import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:magang_titc/models/course_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/widgets/shared/admin_only.dart';
import 'package:magang_titc/widgets/shared/section_header.dart';
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
      ApiService.fetchCourses().then((courses) {
        if (mounted) {
          setState(() {
            _allFetchedCourses = courses;
            _coursesFuture = Future.value(courses);
          });
        }
      }).catchError((_) {});
      return;
    }

    setState(() {
      _coursesFuture =
          ApiService.fetchCourses(search: _searchQuery).then((courses) {
        _allFetchedCourses = courses;
        return courses;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF5F6F8))),

          // Data List
          Positioned.fill(
            top: 70, // Beri jarak untuk SectionHeader
            child: Column(
              children: [
                _buildSearchAndSortBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _loadCourses();
                      await _coursesFuture;
                    },
                    child: FutureBuilder<List<CourseModel>>(
                      future: _coursesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('Belum ada course.'));
                        }

                        final query = _searchQuery.toLowerCase();
                        var filteredCourses =
                            _allFetchedCourses.where((course) {
                          // Filter tab Enrolled/All: murni pilihan lokal.
                          if (!_showAllCourses && !course.isEnrolled) {
                            return false;
                          }

                          // Penyaring cadangan — alasannya sama dengan yang
                          // dijelaskan di `spaces_list_screen.dart`: kata
                          // kunci sudah dikirim ke server, tapi belum terbukti
                          // endpoint-nya menghormati ?search=.
                          if (query.isEmpty) return true;
                          return course.title.toLowerCase().contains(query) ||
                              course.description.toLowerCase().contains(query);
                        }).toList();

                        // Local Sorting
                        if (_sortBy == 'Alphabetical') {
                          filteredCourses.sort((a, b) => a.title.compareTo(b.title));
                        } else if (_sortBy == 'Students') {
                          filteredCourses.sort((a, b) => b.studentsCount.compareTo(a.studentsCount));
                        }

                        if (filteredCourses.isEmpty) {
                          return Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'Tidak ada course di kategori ini.'
                                  : 'Tidak ada course yang cocok dengan "$_searchQuery".',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 8),
                          itemCount: filteredCourses.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildCourseCard(filteredCourses[index]);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header diletakkan di atas agar shadow tidak tertutup list
          Align(
            alignment: Alignment.topCenter,
            child: _buildCoursesHeader(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search Course...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E5AF5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Sort by: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                elevation: 16,
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
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
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image & Tag
          Stack(
            children: [
              Container(
                height: 130,
                color: Colors.grey.shade200,
                child: course.coverPhotoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: course.coverPhotoUrl,
                        httpHeaders: AuthService.imageAuthHeaders,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Center(
                          child: PhosphorIcon(PhosphorIconsRegular.image, color: Colors.grey.shade400),
                        ),
                      )
                    : Center(
                        child: PhosphorIcon(PhosphorIconsRegular.image, color: Colors.grey.shade400),
                      ),
              ),
              if (course.isEnrolled)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Enrolled',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: course.logoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: course.logoUrl,
                              httpHeaders: AuthService.imageAuthHeaders,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Center(
                                child: PhosphorIcon(PhosphorIconsRegular.graduationCap, color: Colors.grey),
                              ),
                            )
                          : const Center(child: PhosphorIcon(PhosphorIconsRegular.graduationCap, color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              PhosphorIcon(PhosphorIconsRegular.bookOpen, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('${course.lessonsCount} Lessons', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                              const SizedBox(width: 12),
                              PhosphorIcon(PhosphorIconsRegular.users, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('${course.studentsCount} Students', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                if (course.isEnrolled) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (course.progress.clamp(0, 100)) / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF1E5AF5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${course.progress}% selesai', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _onCourseAction(course),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: course.isEnrolled ? Colors.white : const Color(0xFF1E5AF5),
                      foregroundColor: course.isEnrolled ? const Color(0xFF1E5AF5) : Colors.white,
                      elevation: 0,
                      side: course.isEnrolled ? const BorderSide(color: Color(0xFF1E5AF5)) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      course.isEnrolled ? 'Continue Learning' : 'Enroll',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Widget _buildCoursesHeader() {
    return SectionHeader(
      title: 'Courses',
      trailing: Row(
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
                icon: const PhosphorIcon(PhosphorIconsRegular.plusCircle, color: Color(0xFF1E5AF5)),
                tooltip: 'New Course',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Buka halaman "New Course" di portal web secara langsung, lalu
  /// otomatis klik tombol "New Course" milik web (melalui autoClickText)
  /// sehingga drawer pembuatan course terbuka native.
  void _openManageCourses() {
    Navigator.push(
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
          color: selected ? const Color(0xFFEAF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1E5AF5) : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

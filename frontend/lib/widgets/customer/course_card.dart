import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:magang_titc/models/course_model.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/screens/customer/spaces/space_webview_screen.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback? onEnrollPressed;

  const CourseCard({
    Key? key,
    required this.course,
    this.onEnrollPressed,
  }) : super(key: key);

  /// Sama persis dengan `_onCourseAction` di `courses_list_screen.dart`:
  /// course yang sudah di-enroll dibuka lewat `portalSegment: 'course'` +
  /// `initialPath: 'lessons'` (bukan default `space`/`home` — itu URL space,
  /// bukan course, dan membuat WebView terbuka ke halaman yang salah).
  Future<void> _onCourseAction(BuildContext context) async {
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
    if (!context.mounted) return;
    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil mendaftar ke Course!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              errorWidget: (context, url, error) => const Center(
                                child: PhosphorIcon(PhosphorIconsRegular.image, color: Color(0xFFA5B4FC)),
                              ),
                            )
                          : const Center(
                              child: PhosphorIcon(PhosphorIconsRegular.image, color: Color(0xFFA5B4FC)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
                                color: const Color(0xFF1E5AF5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1.0),
                              ),
                              child: course.logoUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: course.logoUrl,
                                      httpHeaders: AuthService.imageAuthHeaders,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => const Center(
                                        child: PhosphorIcon(PhosphorIconsRegular.graduationCap, color: Color(0xFF818CF8)),
                                      ),
                                    )
                                  : const Center(
                                      child: PhosphorIcon(PhosphorIconsRegular.graduationCap, color: Color(0xFF818CF8)),
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
                                  Icon(PhosphorIconsRegular.bookOpen, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.lessonsCount} Lessons',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(PhosphorIconsRegular.users, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${course.studentsCount} Students',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF1E5AF5)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.progress}% selesai',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: OutlinedButton(
                                  onPressed: () => _onCourseAction(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E5AF5),
                                    side: const BorderSide(color: Color(0xFF1E5AF5), width: 1.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFF1E5AF5).withValues(alpha: 0.08),
                                  ),
                                  child: const Text(
                                    'Continue Learning',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (onEnrollPressed != null) {
                                      onEnrollPressed!();
                                    } else {
                                      _onCourseAction(context);
                                    }
                                  },
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
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
}

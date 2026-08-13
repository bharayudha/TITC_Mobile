import 'package:magang_titc/models/json_utils.dart';

/// Model untuk satu entitas Course dari Fluent Community.
///
/// Endpoint Course berbagi struktur dasar yang sama dengan Space
/// (`type: "course"`), ditambah field spesifik course seperti
/// `isEnrolled`, `progress`, `sectionsCount`, dan `lessonsCount`.
class CourseModel {
  final int id;
  final String slug;
  final String title;
  final String description;
  final String logoUrl;
  final String coverPhotoUrl;
  final int studentsCount;
  final bool isEnrolled;
  final int progress;
  final int sectionsCount;
  final int lessonsCount;
  final String privacy;

  CourseModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.logoUrl,
    required this.coverPhotoUrl,
    this.studentsCount = 0,
    this.isEnrolled = false,
    this.progress = 0,
    this.sectionsCount = 0,
    this.lessonsCount = 0,
    this.privacy = 'private',
  });

  /// Ambil nilai String pertama yang benar-benar berisi.
  ///
  /// Operator `??` saja tidak cukup karena API mengirim `""` (string kosong)
  /// maupun `null` untuk gambar yang belum diisi; dengan `??` nilai `""`
  /// dianggap sah sehingga fallback tidak pernah dipakai.
  static String _firstNonEmpty(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    final settings = asJsonMap(json['settings']);

    return CourseModel(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      logoUrl: _firstNonEmpty([json['logo'], json['avatar']]),
      coverPhotoUrl: _firstNonEmpty([
        json['cover_photo'],
        json['cover'],
        settings['og_image'],
      ]),
      studentsCount: json['studentsCount'] ?? 0,
      isEnrolled: json['isEnrolled'] ?? false,
      progress: json['progress'] ?? 0,
      sectionsCount: json['sectionsCount'] ?? 0,
      lessonsCount: json['lessonsCount'] ?? 0,
      privacy: json['privacy'] ?? 'private',
    );
  }
}

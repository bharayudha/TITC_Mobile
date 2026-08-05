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

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      logoUrl: json['logo'] ?? json['avatar'] ?? '',
      coverPhotoUrl: json['cover_photo'] ?? json['cover'] ?? '',
      studentsCount: json['studentsCount'] ?? 0,
      isEnrolled: json['isEnrolled'] ?? false,
      progress: json['progress'] ?? 0,
      sectionsCount: json['sectionsCount'] ?? 0,
      lessonsCount: json['lessonsCount'] ?? 0,
      privacy: json['privacy'] ?? 'private',
    );
  }
}

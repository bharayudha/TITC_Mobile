/// Model untuk satu entitas Space (Grup) dari Fluent Community.
class SpaceModel {
  final int id;
  final String slug;
  final String title;
  final String description;
  final String logoUrl;
  final String coverPhotoUrl;
  final int membersCount;
  final bool isJoined;
  final String privacy;

  SpaceModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.logoUrl,
    required this.coverPhotoUrl,
    this.membersCount = 0,
    this.isJoined = false,
    this.privacy = 'public',
  });

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      logoUrl: json['logo'] ?? json['avatar'] ?? '',
      coverPhotoUrl: json['cover_photo'] ?? json['cover'] ?? '',
      membersCount: json['members_count'] ?? json['member_count'] ?? 0,
      isJoined: json['is_joined'] ?? json['is_member'] ?? false,
      privacy: json['privacy'] ?? 'public',
    );
  }
}

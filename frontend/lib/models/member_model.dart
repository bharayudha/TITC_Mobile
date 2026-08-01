/// Model untuk satu entitas Member dari Fluent Community.
class MemberModel {
  final int id;
  final String displayName;
  final String avatarUrl;
  final String lastActivity;
  final String status; // misal: 'online', 'offline'

  MemberModel({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.lastActivity,
    this.status = 'offline',
  });

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] ?? 0,
      displayName: json['display_name'] ?? json['name'] ?? 'Unknown Member',
      avatarUrl: json['avatar'] ?? json['photo'] ?? '',
      lastActivity: json['last_activity'] ?? json['human_diff'] ?? '',
      status: json['status'] ?? 'offline',
    );
  }
}

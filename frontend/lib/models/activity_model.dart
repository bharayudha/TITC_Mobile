/// Model untuk satu item feed/activity dari Fluent Community.
class ActivityModel {
  final int id;
  final String authorName;
  final String avatarUrl;
  final String content;
  final String date;
  final int likeCount;
  final int commentCount;
  final String? mediaUrl;
  final String? spaceName;

  ActivityModel({
    required this.id,
    required this.authorName,
    required this.avatarUrl,
    required this.content,
    required this.date,
    this.likeCount = 0,
    this.commentCount = 0,
    this.mediaUrl,
    this.spaceName,
  });

  /// Factory dari JSON response Fluent Community `/feeds`.
  ///
  /// Struktur JSON Fluent Community biasanya:
  /// ```json
  /// {
  ///   "id": 123,
  ///   "message": "...",
  ///   "message_rendered": "<p>...</p>",
  ///   "user": { "display_name": "...", "avatar": "..." },
  ///   "created_at": "2026-07-...",
  ///   "reactions_count": 2,
  ///   "comments_count": 1,
  ///   "space": { "title": "..." },
  ///   "meta": { "featured_image": "..." }
  /// }
  /// ```
  factory ActivityModel.fromFluentCommunity(Map<String, dynamic> json) {
    // User info di v2 seringkali ada di 'xprofile' bukan 'user'
    final user = json['xprofile'] as Map<String, dynamic>? ?? json['user'] as Map<String, dynamic>? ?? {};
    final space = json['space'] as Map<String, dynamic>? ?? {};
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return ActivityModel(
      id: json['id'] ?? 0,
      authorName: user['display_name'] ?? user['name'] ?? 'Unknown',
      avatarUrl: user['avatar'] ?? user['photo'] ?? '',
      content: json['message_rendered'] ??
          json['message'] ??
          json['title'] ??
          '',
      date: json['created_at'] ??
          json['updated_at'] ??
          json['human_diff'] ??
          json['date'] ??
          '',
      likeCount: json['reactions_count'] ?? json['react_count'] ?? 0,
      commentCount: json['comments_count'] ?? json['comment_count'] ?? 0,
      mediaUrl: meta['featured_image'] as String?,
      spaceName: space['title'] as String?,
    );
  }
}

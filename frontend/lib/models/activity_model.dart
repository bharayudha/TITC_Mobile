import 'package:magang_titc/models/json_utils.dart';

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
  final String? permalink;
  final String? linkPreviewUrl;
  final String? linkPreviewTitle;
  final String? linkPreviewDescription;

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
    this.permalink,
    this.linkPreviewUrl,
    this.linkPreviewTitle,
    this.linkPreviewDescription,
  });

  /// Factory dari JSON response Fluent Community `/feeds`.
  factory ActivityModel.fromFluentCommunity(Map<String, dynamic> json) {
    // User info di v2 seringkali ada di 'xprofile' bukan 'user'
    var user = asJsonMap(json['xprofile']);
    if (user.isEmpty) user = asJsonMap(json['user']);
    final space = asJsonMap(json['space']);
    final meta = asJsonMap(json['meta']);

    // Parse preview data if available
    final previewData = asJsonMap(meta['preview_data']);
    String? linkUrl;
    String? linkTitle;
    String? linkDesc;
    if (previewData.isNotEmpty) {
      linkUrl = previewData['url'] ?? previewData['link'];
      linkTitle = previewData['title'];
      linkDesc = previewData['description'];
    } else {
      // Fallback regex extract link from content if needed, but FCOM usually uses preview_data
      // We can check if 'url' exists in meta directly
      linkUrl = meta['url'] as String?;
    }

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
      permalink: json['permalink'] as String?,
      linkPreviewUrl: linkUrl,
      linkPreviewTitle: linkTitle,
      linkPreviewDescription: linkDesc,
    );
  }
}

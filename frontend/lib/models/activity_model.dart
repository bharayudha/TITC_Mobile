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

  /// Status "sudah di-like oleh user saat ini" menurut SERVER — dipakai untuk
  /// mengisi status Like yang benar saat feed pertama kali dimuat/di-refresh
  /// (mis. setelah hot restart), bukan cuma mengandalkan tap lokal yang
  /// hilang begitu app ditutup. Field aslinya belum terverifikasi lewat
  /// DevTools, jadi dicoba beberapa nama yang lazim dipakai FCOM (lihat
  /// `_parseIsLikedByMe`) — kalau tidak ada yang cocok, defaultnya `false`,
  /// sama seperti sebelum field ini ada (bukan regresi).
  final bool isLikedByMe;

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
    this.isLikedByMe = false,
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
      isLikedByMe: _parseIsLikedByMe(json),
    );
  }

  /// Coba beberapa nama field yang lazim dipakai FCOM untuk menandai reaksi
  /// user saat ini pada satu item feed. Lihat catatan di [isLikedByMe].
  static bool _parseIsLikedByMe(Map<String, dynamic> json) {
    for (final key in [
      'is_liked',
      'has_liked',
      'is_reacted',
      'has_reacted',
      'user_has_reacted',
      'reacted_by_me',
      'is_liked_by_me',
      'has_user_reacted',
    ]) {
      final value = json[key];
      if (value == true || value == 1 || value == '1') return true;
    }

    final userReactions = json['user_reactions'];
    if (userReactions is List &&
        userReactions.any((r) => '$r'.toLowerCase() == 'like')) {
      return true;
    }

    final myReaction = json['my_reaction'] ?? json['user_reaction'];
    if (myReaction is String && myReaction.toLowerCase() == 'like') {
      return true;
    }

    return false;
  }
}

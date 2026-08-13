import 'package:magang_titc/models/json_utils.dart';

/// Model untuk satu thread chat (community/direct/group) dari Fluent Community.
class ChatThreadModel {
  final int id;
  final String title;
  final String avatarUrl;
  final String iconHtml;
  final String lastMessagePreview;
  final String updatedAt;
  final int messageCount;
  final int unreadCount;
  final bool canSendMessage;
  final String type;

  ChatThreadModel({
    required this.id,
    required this.title,
    required this.avatarUrl,
    this.iconHtml = '',
    this.lastMessagePreview = '',
    this.updatedAt = '',
    this.messageCount = 0,
    this.unreadCount = 0,
    this.canSendMessage = true,
    this.type = 'community',
  });

  /// Factory dari salah satu item `community_threads`/`threads`/`group_threads`
  /// pada response `GET /chat/threads`.
  ///
  /// Thread komunitas (per Space) punya field `info` berisi data space.
  /// Thread DM/grup punya struktur yang belum terverifikasi langsung dari API
  /// (akun test tidak punya DM aktif), jadi di-fallback ke beberapa
  /// kemungkinan key yang lazim dipakai Fluent Community.
  factory ChatThreadModel.fromJson(Map<String, dynamic> json, {String type = 'community'}) {
    final info = asJsonMap(json['info']);
    var otherUser = asJsonMap(json['recipient']);
    if (otherUser.isEmpty) otherUser = asJsonMap(json['other_user']);
    if (otherUser.isEmpty) otherUser = asJsonMap(json['xprofile']);

    final messages = asJsonList(json['messages']);
    final latestMessage =
        messages.isNotEmpty ? asJsonMap(messages.first) : const {};
    final latestText = asJsonString(latestMessage['text']) ?? '';

    return ChatThreadModel(
      id: json['id'] ?? 0,
      title: (json['title'] as String?)?.isNotEmpty == true
          ? json['title']
          : (info['title'] as String?) ?? (otherUser['display_name'] as String?) ?? 'Tanpa Judul',
      avatarUrl: (info['photo'] as String?)?.isNotEmpty == true
          ? info['photo']
          : (otherUser['avatar'] as String?) ?? '',
      iconHtml: info['icon_html'] ?? '',
      lastMessagePreview: latestText.replaceAll(RegExp(r'<[^>]*>'), ''),
      updatedAt: json['updated_at'] ?? '',
      messageCount: int.tryParse('${json['message_count'] ?? 0}') ?? 0,
      canSendMessage: info['can_send_message'] ?? true,
      type: type,
    );
  }

  ChatThreadModel copyWithUnread(int unread) {
    return ChatThreadModel(
      id: id,
      title: title,
      avatarUrl: avatarUrl,
      iconHtml: iconHtml,
      lastMessagePreview: lastMessagePreview,
      updatedAt: updatedAt,
      messageCount: messageCount,
      unreadCount: unread,
      canSendMessage: canSendMessage,
      type: type,
    );
  }
}

/// Model untuk satu pesan pada `GET /chat/messages/{thread_id}`.
class ChatMessageModel {
  final int id;
  final int threadId;
  final String userId;
  final String text;
  final String createdAt;
  final String authorName;
  final String authorAvatar;
  final String authorUsername;

  ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.authorName,
    required this.authorAvatar,
    required this.authorUsername,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final xprofile = asJsonMap(json['xprofile']);
    final rawText = asJsonString(json['text']) ?? '';

    return ChatMessageModel(
      id: json['id'] ?? 0,
      threadId: int.tryParse('${json['thread_id'] ?? 0}') ?? 0,
      userId: '${json['user_id'] ?? ''}',
      text: rawText.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
      createdAt: json['created_at'] ?? '',
      authorName: xprofile['display_name'] ?? 'Unknown',
      authorAvatar: xprofile['avatar'] ?? '',
      authorUsername: xprofile['username'] ?? '',
    );
  }
}

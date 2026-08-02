import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import 'auth_service.dart';

/// Hasil `GET /chat/threads`, dikelompokkan sesuai section UI
/// (Communities vs Direct Messages).
class ChatThreadsResult {
  final List<ChatThreadModel> communityThreads;
  final List<ChatThreadModel> directThreads;
  final List<ChatThreadModel> groupThreads;

  ChatThreadsResult({
    required this.communityThreads,
    required this.directThreads,
    required this.groupThreads,
  });
}

/// Hasil `GET /chat/messages/{thread_id}`.
class ChatMessagesResult {
  final String threadTitle;
  final bool canSendMessage;
  final List<ChatMessageModel> messages;
  final bool hasMore;

  ChatMessagesResult({
    required this.threadTitle,
    required this.canSendMessage,
    required this.messages,
    required this.hasMore,
  });
}

/// Service untuk fitur Forum — Messages (Chat) via Fluent Community REST API.
///
/// Endpoint dikonfirmasi lewat WP REST API discovery index
/// (`GET /wp-json/fluent-community/v2`), bukan dari dokumentasi resmi karena
/// Fluent Community tidak mempublikasikan referensi endpoint chat.
class MessagesService {
  static const String _baseUrl =
      'https://titc.or.id/wp-json/fluent-community/v2';

  static Map<String, String> get _authHeaders {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://titc.or.id/portal/',
      if (AuthService.cookies != null) 'Cookie': AuthService.cookies!,
      if (AuthService.wpNonce != null) 'X-WP-Nonce': AuthService.wpNonce!,
    };
  }

  /// Ambil semua thread chat (komunitas per space, DM, dan grup) sekaligus
  /// unread count-nya.
  static Future<ChatThreadsResult> fetchThreads() async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/chat/threads'),
      headers: _authHeaders,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Sesi login telah habis. Silakan login ulang.');
    }
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat pesan: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final unread = await _fetchUnreadCountsSafe();

    List<ChatThreadModel> parseList(String key, String type) {
      final list = data[key] as List<dynamic>? ?? [];
      return list
          .map((e) => ChatThreadModel.fromJson(e as Map<String, dynamic>, type: type))
          .map((thread) => thread.copyWithUnread(unread[thread.id] ?? 0))
          .toList();
    }

    return ChatThreadsResult(
      communityThreads: parseList('community_threads', 'community'),
      directThreads: parseList('threads', 'direct'),
      groupThreads: parseList('group_threads', 'group'),
    );
  }

  /// `GET /chat/unread_threads` -> `{ "threadId": count }`.
  /// Dibungkus try-catch karena bersifat pelengkap (badge), bukan data inti.
  static Future<Map<int, int>> _fetchUnreadCountsSafe() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/unread_threads'),
        headers: _authHeaders,
      );
      if (response.statusCode != 200) return {};

      final data = json.decode(response.body) as Map<String, dynamic>;
      final raw = data['unread_threads'] as Map<String, dynamic>? ?? {};
      return raw.map((key, value) => MapEntry(int.tryParse(key) ?? 0, int.tryParse('$value') ?? 0));
    } catch (_) {
      return {};
    }
  }

  /// Ambil riwayat pesan pada satu thread.
  static Future<ChatMessagesResult> fetchMessages(int threadId) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/chat/messages/$threadId'),
      headers: _authHeaders,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Sesi login telah habis. Silakan login ulang.');
    }
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat percakapan: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final threadDetails = data['threadDetails'] as Map<String, dynamic>? ?? {};
    final info = threadDetails['info'] as Map<String, dynamic>? ?? {};
    final messagesJson = data['messages'] as List<dynamic>? ?? [];

    return ChatMessagesResult(
      threadTitle: threadDetails['title'] ?? '',
      canSendMessage: info['can_send_message'] ?? true,
      messages: messagesJson
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: data['has_more'] ?? false,
    );
  }

  /// Kirim pesan baru ke thread. Nama field body (`message`) disimpulkan dari
  /// bundle JS Fluent Community (`app.js`, pola `message: e.message`) —
  /// endpoint ini belum pernah dicoba dengan payload nyata (dihindari supaya
  /// tidak mengirim pesan tes ke thread produksi), jadi validasi ulang saat
  /// uji coba pertama di device.
  static Future<ChatMessageModel?> sendMessage(int threadId, String text) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }
    if (text.trim().isEmpty) return null;

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/messages/$threadId'),
      headers: _authHeaders,
      body: json.encode({'message': text.trim()}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal mengirim pesan: ${response.statusCode} ${response.body}');
    }

    final data = json.decode(response.body);
    if (data is Map<String, dynamic>) {
      final messageJson = data['message'] as Map<String, dynamic>? ?? data['data'] as Map<String, dynamic>?;
      if (messageJson != null) {
        return ChatMessageModel.fromJson(messageJson);
      }
    }
    return null;
  }
}

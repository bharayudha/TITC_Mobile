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
  factory ChatThreadModel.fromJson(
    Map<String, dynamic> json, {
    String type = 'community',
  }) {
    final info = asJsonMap(json['info']);
    var otherUser = asJsonMap(json['recipient']);
    if (otherUser.isEmpty) otherUser = asJsonMap(json['other_user']);
    if (otherUser.isEmpty) otherUser = asJsonMap(json['xprofile']);

    final messages = asJsonList(json['messages']);
    final latestMessage = messages.isNotEmpty
        ? asJsonMap(messages.first)
        : const {};
    final latestText = asJsonString(latestMessage['text']) ?? '';

    return ChatThreadModel(
      id: json['id'] ?? 0,
      title: (json['title'] as String?)?.isNotEmpty == true
          ? json['title']
          : (info['title'] as String?) ??
                (otherUser['display_name'] as String?) ??
                'Tanpa Judul',
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

  /// URL gambar yang menempel pada pesan ini. Kosong untuk pesan teks biasa.
  final List<String> mediaUrls;

  /// Cuplikan pesan yang dibalas. Null kalau ini bukan balasan.
  final String? replyText;

  /// Reaksi emoji beserta jumlahnya, mis. `{'👍': 2}`.
  final Map<String, int> reactions;

  ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.authorName,
    required this.authorAvatar,
    required this.authorUsername,
    this.mediaUrls = const [],
    this.replyText,
    this.reactions = const {},
  });

  /// Hitung reaksi per emoji.
  ///
  /// **Bentuk terverifikasi** (dari respons `GET /chat/messages/21`, 15 Agt):
  /// reaksi disimpan di `meta.reactions` sebagai peta emoji → daftar user id
  /// yang bereaksi, BUKAN sebagai jumlah:
  ///
  /// ```json
  /// "meta": { "reactions": { "👍": [727] } }
  /// ```
  ///
  /// Jadi jumlahnya = panjang daftar. Pesan tanpa reaksi punya `meta: null`.
  ///
  /// Sekali lagi bentuk KIRIM dan BACA tidak simetris — mengirim reaksi
  /// memakai `{"emoji": "👍"}` ke endpoint terpisah. Jangan menyimpulkan
  /// yang satu dari yang lain.
  ///
  /// Bentuk lain tetap diterima sebagai cadangan; daftar user id di dalamnya
  /// sengaja tidak disimpan karena app belum punya user id numerik milik
  /// user sendiri (`AuthService` hanya menyimpan slug), jadi belum bisa
  /// dipakai untuk menandai "kamu sudah bereaksi".
  static Map<String, int> _collectReactions(Map<String, dynamic> json) {
    final meta = asJsonMap(json['meta']);
    for (final raw in [
      json['reactions'],
      json['reacts'],
      meta['reactions'],
      meta['reacts'],
    ]) {
      if (raw == null) continue;

      final asMap = asJsonMap(raw);
      if (asMap.isNotEmpty) {
        final counts = <String, int>{};
        asMap.forEach((key, value) {
          final count = int.tryParse('$value');
          // Peta {emoji: jumlah}. Nilai yang bukan angka berarti bentuknya
          // lain (mis. {emoji: [daftar user]}), jadi panjangnya yang dipakai.
          counts[key] = count ?? asJsonList(value).length;
        });
        counts.removeWhere((_, value) => value <= 0);
        if (counts.isNotEmpty) return counts;
      }

      final asList = asJsonList(raw);
      if (asList.isNotEmpty) {
        final counts = <String, int>{};
        for (final item in asList) {
          final emoji =
              asJsonString(item) ?? asJsonString(asJsonMap(item)['emoji']);
          if (emoji == null) continue;
          counts[emoji] = (counts[emoji] ?? 0) + 1;
        }
        if (counts.isNotEmpty) return counts;
      }
    }
    return const {};
  }

  /// Ambil `src` dari setiap `<img>` di dalam HTML.
  static final _imgSrcPattern = RegExp(
    '''<img[^>]+src\\s*=\\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Kumpulkan URL gambar dari pesan.
  ///
  /// **Gambar chat TIDAK punya field sendiri.** FCOM menanamnya sebagai HTML
  /// di dalam `text`, dan `meta` bernilai `null` (diverifikasi dari respons
  /// `GET /chat/messages/19`, 15 Agt):
  ///
  /// ```html
  /// <div class="chat_medias"><div class="chat_media">
  ///   <img src="https://…webp" alt="Image shared in chat">
  /// </div></div>
  /// ```
  ///
  /// Ini beda dari bentuk KIRIM, yang memakai `mediaItems: ["url"]` di luar
  /// teks — jadi jangan berasumsi keduanya simetris.
  ///
  /// Beberapa nama field media tetap ikut diperiksa sebagai cadangan karena
  /// endpoint FCOM lain memang memakainya; kalau suatu saat chat ikut
  /// berubah, gambarnya tidak hilang diam-diam.
  static List<String> _collectMediaUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    // Sumber utama: HTML di dalam `text`.
    final rawText = asJsonString(json['text']) ?? '';
    for (final match in _imgSrcPattern.allMatches(rawText)) {
      final src = match.group(1);
      if (src != null && src.startsWith('http')) urls.add(src);
    }
    if (urls.isNotEmpty) return urls;

    // Cadangan: wadah media terpisah, kalau-kalau bentuknya berubah.
    final meta = asJsonMap(json['meta']);
    final candidates = [
      json['media'],
      json['media_items'],
      json['mediaItems'],
      meta['media'],
      meta['media_items'],
      meta['mediaItems'],
    ];

    for (final candidate in candidates) {
      final found = <String>[];
      for (final item in asJsonList(candidate)) {
        final direct = asJsonString(item);
        if (direct != null && direct.startsWith('http')) {
          found.add(direct);
          continue;
        }
        final map = asJsonMap(item);
        final url =
            asJsonString(map['url']) ??
            asJsonString(map['public_url']) ??
            asJsonString(map['source_url']) ??
            asJsonString(map['thumbnail']);
        if (url != null && url.startsWith('http')) found.add(url);
      }
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final xprofile = asJsonMap(json['xprofile']);
    final rawText = asJsonString(json['text']) ?? '';

    return ChatMessageModel(
      id: json['id'] ?? 0,
      threadId: int.tryParse('${json['thread_id'] ?? 0}') ?? 0,
      userId: '${json['user_id'] ?? ''}',
      // Tag dibuang SETELAH URL gambar dipanen di `_collectMediaUrls` —
      // urutan ini yang penting. Pesan berisi gambar saja menyisakan string
      // kosong di sini, dan itu memang benar: isinya sudah pindah ke
      // `mediaUrls`.
      text: rawText.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
      createdAt: json['created_at'] ?? '',
      authorName: xprofile['display_name'] ?? 'Unknown',
      authorAvatar: xprofile['avatar'] ?? '',
      authorUsername: xprofile['username'] ?? '',
      mediaUrls: _collectMediaUrls(json),
      // Nama field diambil dari sisi KIRIM yang sudah terverifikasi
      // (`reply_text`); `meta` ikut diperiksa karena FCOM kerap menyimpan
      // data tambahan di sana.
      replyText:
          asJsonString(json['reply_text']) ??
          asJsonString(asJsonMap(json['meta'])['reply_text']),
      reactions: _collectReactions(json),
    );
  }
}

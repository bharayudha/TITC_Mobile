import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/json_utils.dart';
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
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

    final data = asJsonMap(json.decode(response.body));
    final unread = await _fetchUnreadCountsSafe();

    List<ChatThreadModel> parseList(String key, String type) {
      return asJsonList(data[key])
          .map((e) => ChatThreadModel.fromJson(asJsonMap(e), type: type))
          .map((thread) => thread.copyWithUnread(unread[thread.id] ?? 0))
          .toList();
    }

    return ChatThreadsResult(
      communityThreads: parseList('community_threads', 'community'),
      directThreads: parseList('threads', 'direct'),
      groupThreads: parseList('group_threads', 'group'),
    );
  }

  /// Jumlah pesan belum dibaca dari SELURUH percakapan — komunitas maupun
  /// direct message. Dipakai badge angka di ikon Messages.
  ///
  /// Memakai [ValueNotifier] karena ikonnya hidup di `MainShell`, jauh dari
  /// layar chat; `setState` di layar chat tidak akan menjangkaunya. Pola yang
  /// sama dipakai `NotificationsService` untuk badge lonceng.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static Timer? _pollingTimer;

  /// Mulai memantau jumlah pesan belum dibaca.
  ///
  /// Jeda 60 detik menyamai polling lonceng: ini cuma angka pada ikon, beda
  /// dari layar chat yang terbuka (6 detik) di mana user memang menunggu
  /// balasan. Aman dipanggil berkali-kali — pemanggilan kedua diabaikan
  /// selama timer sebelumnya masih hidup.
  static const _unreadCountCacheKey = 'chat_unread_count_cache';

  static void startUnreadPolling() {
    if (_pollingTimer?.isActive ?? false) return;

    // Badge dulu selalu mulai dari 0 dan baru terisi setelah fetch jaringan
    // pertama selesai — kelihatan "tidak langsung muncul" saat app dibuka,
    // terutama kalau koneksinya lambat. Angka terakhir yang diketahui
    // disimpan lokal (SharedPreferences) dan dimuat di sini SEBELUM fetch
    // jaringan, supaya badge langsung tampil dengan angka terakhir yang
    // benar sejak app dibuka — lalu dikoreksi begitu fetch selesai kalau
    // ternyata sudah berubah (mis. dibaca dari perangkat lain).
    _loadCachedUnreadCount();
    _refreshUnreadCount();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (AuthService.isLoggedIn) {
        _refreshUnreadCount();
      } else {
        stopUnreadPolling();
      }
    });
  }

  /// Sama seperti [_loadCachedUnreadCount], tapi PUBLIC dan dipanggil dari
  /// `main()` SEBELUM `runApp()` — bukan dari `initState` tombol chat.
  ///
  /// Memuatnya dari `initState` (seperti awalnya) ternyata TIDAK cukup
  /// cepat: `SharedPreferences.getInstance()` sendiri butuh inisialisasi
  /// platform channel, jadi kecepatannya sebanding dengan fetch jaringan
  /// begitu app baru saja dingin (cold start) — badge tetap sempat kosong
  /// sesaat sebelum terisi, sama seperti sebelum diperbaiki. Dipanggil di
  /// `main()` (yang sudah `await AuthService.init()` duluan) berarti
  /// nilainya SUDAH siap di `unreadCountNotifier` SEBELUM widget pertama
  /// digambar sama sekali — tidak ada lagi jendela waktu badge kosong.
  static Future<void> preloadCachedUnreadCount() => _loadCachedUnreadCount();

  static Future<void> _loadCachedUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_unreadCountCacheKey);
    if (cached != null && cached > 0) {
      unreadCountNotifier.value = cached;
    }
  }

  static void stopUnreadPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    unreadCountNotifier.value = 0;
    // Dibersihkan supaya kalau akun lain login di perangkat yang sama,
    // badge-nya tidak sempat menampilkan angka sisa milik akun sebelumnya.
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove(_unreadCountCacheKey),
    );
  }

  /// Segarkan angka badge sekarang juga.
  ///
  /// Dipanggil saat layar chat ditutup supaya badge tidak tertinggal
  /// menampilkan pesan yang baru saja dibaca — menunggu putaran 60 detik
  /// berikutnya membuat angkanya terasa macet.
  static Future<void> refreshUnreadCount() => _refreshUnreadCount();

  static Future<void> _refreshUnreadCount() async {
    if (!AuthService.isLoggedIn) return;
    final counts = await _fetchUnreadCountsSafe();
    // Kegagalan sudah ditelan oleh _fetchUnreadCountsSafe (mengembalikan peta
    // kosong). Nilai lama dipertahankan supaya gangguan jaringan sesaat tidak
    // membuat badge berkedip hilang lalu muncul lagi.
    if (counts.isEmpty) return;
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    unreadCountNotifier.value = total;
    // Disimpan supaya kali berikutnya app dibuka, badge langsung tampil
    // dari angka ini (lihat `_loadCachedUnreadCount`) alih-alih mulai dari
    // 0 sambil menunggu fetch jaringan pertama selesai.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadCountCacheKey, total);
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

      final data = asJsonMap(json.decode(response.body));
      final raw = asJsonMap(data['unread_threads']);
      return raw.map(
        (key, value) =>
            MapEntry(int.tryParse(key) ?? 0, int.tryParse('$value') ?? 0),
      );
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

    // Dibaca lewat helper json_utils, bukan cast langsung: PHP menserialisasi
    // objek KOSONG sebagai `[]`, sehingga `as Map<String, dynamic>? ?? {}`
    // melempar exception alih-alih jatuh ke `{}`. Thread yang `info`-nya
    // kosong dulu bisa membuat layar chat error, bukan sekadar tampil polos.
    final data = asJsonMap(json.decode(response.body));
    final threadDetails = asJsonMap(data['threadDetails']);
    final info = asJsonMap(threadDetails['info']);
    final messagesJson = asJsonList(data['messages']);

    return ChatMessagesResult(
      threadTitle: threadDetails['title'] ?? '',
      canSendMessage: info['can_send_message'] ?? true,
      messages: messagesJson
          .map((e) => ChatMessageModel.fromJson(asJsonMap(e)))
          .toList(),
      hasMore: data['has_more'] ?? false,
    );
  }

  /// Ambil HANYA pesan yang lebih baru dari [lastId].
  ///
  /// `GET /chat/messages/{threadId}/new?last_id={lastId}` — endpoint yang
  /// dipakai portal web untuk polling (terlihat di DevTools sebagai
  /// `new?last_id=`, diverifikasi lewat cURL 15 Agt). Jauh lebih ringan
  /// daripada menarik ulang seluruh percakapan tiap beberapa detik.
  ///
  /// Melempar exception kalau bentuk balasannya tidak dikenali, supaya
  /// pemanggil bisa jatuh ke [fetchMessages] yang sudah pasti benar.
  /// Balasan kosong BUKAN error — itu keadaan normal "tidak ada pesan baru".
  static Future<List<ChatMessageModel>> fetchNewMessages(
    int threadId,
    int lastId,
  ) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/chat/messages/$threadId/new?last_id=$lastId'),
      headers: _authHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal memuat pesan baru: ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final root = asJsonMap(decoded);

    // Keberadaan KUNCI yang dicek, bukan isinya — daftar kosong adalah
    // jawaban yang sah dan tidak boleh dianggap gagal parsing.
    List<dynamic>? raw;
    if (root.containsKey('messages')) {
      raw = asJsonList(root['messages']);
    } else if (root.containsKey('data')) {
      raw = asJsonList(root['data']);
    } else if (decoded is List) {
      raw = decoded;
    }

    if (raw == null) {
      throw Exception('Bentuk balasan pesan baru tidak dikenali');
    }

    return raw.map((e) => ChatMessageModel.fromJson(asJsonMap(e))).toList();
  }

  /// Kirim pesan baru ke thread.
  ///
  /// Bentuk body **diverifikasi dari cURL DevTools portal web** (15 Agt):
  /// `{"text": "...", "mediaItems": ["https://…?media_key=…"]}`.
  ///
  /// Dua hal yang sudah terbukti TIDAK bisa ditebak, jangan diubah tanpa
  /// capture baru:
  /// 1. Nama field teksnya `text`, bukan `message`. Tebakan lama diambil
  ///    dari bundle JS dan ditolak server dengan **422**.
  /// 2. `mediaItems` berisi **string URL polos**, bukan objek media. Dugaan
  ///    bahwa objek dari endpoint unggah diteruskan apa adanya juga salah.
  ///
  /// `mediaItems` tetap dikirim walau kosong: itu yang dilakukan web, dan
  /// endpoint yang memvalidasi ketat sampai menolak dengan 422 lebih baik
  /// tidak dipancing dengan payload yang bentuknya berbeda.
  static Future<ChatMessageModel?> sendMessage(
    int threadId,
    String text, {
    List<String> mediaItems = const [],
    int? replyToId,
    String? replyText,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }
    // Pesan berisi gambar saja (tanpa teks) tetap sah, jadi yang ditolak
    // hanya kalau dua-duanya kosong.
    if (text.trim().isEmpty && mediaItems.isEmpty) return null;

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/messages/$threadId'),
      headers: _authHeaders,
      body: json.encode({
        'text': text.trim(),
        'mediaItems': mediaItems,
        // Balasan BUKAN endpoint terpisah — cuma dua field tambahan pada
        // kiriman biasa. `reply_text` adalah cuplikan pesan yang dibalas,
        // dikirim ulang oleh web supaya kutipannya bisa ditampilkan tanpa
        // menelusuri pesan aslinya.
        if (replyToId != null) 'reply_to': replyToId,
        if (replyToId != null) 'reply_text': replyText ?? '',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Gagal mengirim pesan: ${response.statusCode} ${response.body}',
      );
    }

    final data = asJsonMap(json.decode(response.body));

    // Bentuk balasan belum diverifikasi, jadi tiga kemungkinan dicoba
    // berurutan: objek di `message`, di `data`, atau pesan itu sendiri di
    // akar respons. `asJsonMap` dipakai supaya kunci yang isinya bukan objek
    // (mis. `[]` dari PHP, atau string status) tidak melempar exception —
    // pesan SUDAH terkirim di titik ini, jadi gagal membaca balasan tidak
    // boleh terlihat seperti gagal mengirim.
    for (final candidate in [data['message'], data['data'], data]) {
      final messageJson = asJsonMap(candidate);
      if (messageJson.isNotEmpty) {
        return ChatMessageModel.fromJson(messageJson);
      }
    }
    return null;
  }

  /// Beri (atau cabut) reaksi emoji pada sebuah pesan.
  ///
  /// `POST /chat/messages/{messageId}/react` body `{"emoji": "👍"}` —
  /// diverifikasi dari cURL DevTools (15 Agt). Perhatikan id yang dipakai
  /// adalah **id PESAN**, bukan id thread.
  ///
  /// Server yang menentukan ini menambah atau membatalkan reaksi; web
  /// mengirim permintaan yang sama persis untuk dua-duanya.
  static Future<void> reactToMessage(int messageId, String emoji) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/messages/$messageId/react'),
      headers: _authHeaders,
      body: json.encode({'emoji': emoji}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Gagal memberi reaksi: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Hapus sebuah pesan.
  ///
  /// `POST /chat/messages/delete/{messageId}` dengan body `{}` — diverifikasi
  /// dari cURL DevTools (15 Agt).
  ///
  /// > Perhatikan bentuk URL-nya: kata `delete` berada **sebelum** id, bukan
  /// > sesudah, dan metodenya POST — bukan `DELETE /chat/messages/{id}`
  /// > seperti lazimnya REST. Jangan "dirapikan" tanpa capture baru.
  static Future<void> deleteMessage(int messageId) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/messages/delete/$messageId'),
      headers: _authHeaders,
      body: json.encode(<String, dynamic>{}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Gagal menghapus pesan: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Unggah satu gambar untuk dilampirkan ke pesan, mengembalikan URL-nya.
  ///
  /// Endpointnya **terikat thread**: `POST /chat/messages/{threadId}/media_upload`
  /// — bukan `/feeds/media-upload` yang dipakai upload avatar. Keduanya
  /// sama-sama endpoint media FCOM, tapi tidak bisa saling menggantikan.
  /// Diverifikasi dari cURL DevTools portal web (15 Agt).
  ///
  /// URL hasilnya dikembalikan **apa adanya**, termasuk query `?media_key=`.
  /// Query itu bagian dari identitas berkasnya, bukan hiasan — memotongnya
  /// membuat gambar tidak bisa diambil kembali.
  static Future<String> uploadMedia(int threadId, File imageFile) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/chat/messages/$threadId/media_upload'),
    );
    // MultipartRequest menyusun Content-Type sendiri (lengkap dengan
    // boundary), jadi header JSON dari _authHeaders tidak boleh dipakai
    // utuh — menimpanya membuat unggahan gagal.
    request.headers.addAll({
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://titc.or.id/portal/',
      if (AuthService.cookies != null) 'Cookie': AuthService.cookies!,
      if (AuthService.wpNonce != null) 'X-WP-Nonce': AuthService.wpNonce!,
    });
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Gagal mengunggah gambar: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = json.decode(response.body);

    // Bentuk balasan belum sempat ditangkap dari DevTools, jadi URL-nya
    // dicari di beberapa tempat yang lazim dipakai endpoint media FCOM
    // (bandingkan penanganan serupa di ApiService.uploadAvatar, yang juga
    // harus mencoba banyak kunci). Yang diterima hanya nilai berawalan
    // http, supaya field lain tidak ikut terbawa sebagai URL palsu.
    final root = asJsonMap(decoded);
    final containers = [
      root,
      asJsonMap(root['media']),
      asJsonMap(root['data']),
    ];
    for (final container in containers) {
      final url =
          asJsonString(container['url']) ??
          asJsonString(container['public_url']) ??
          asJsonString(container['source_url']) ??
          asJsonString(container['media_url']);
      if (url != null && url.startsWith('http')) return url;
    }

    // Balasan berupa daftar, atau string URL telanjang.
    for (final item in asJsonList(
      root['media'],
    ).followedBy(asJsonList(decoded))) {
      final direct = asJsonString(item);
      if (direct != null && direct.startsWith('http')) return direct;
      final url = asJsonString(asJsonMap(item)['url']);
      if (url != null && url.startsWith('http')) return url;
    }

    throw Exception('Balasan unggahan tidak dikenali: ${response.body}');
  }
}

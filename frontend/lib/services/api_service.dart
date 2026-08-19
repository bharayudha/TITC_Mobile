import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';
import '../models/course_model.dart';
import '../models/member_model.dart';
import '../models/space_model.dart';
import 'auth_service.dart';

/// Satu halaman hasil dari endpoint members, lengkap dengan info paginasi
/// supaya UI tahu total member dan apakah masih ada halaman berikutnya.
class MembersPage {
  final List<MemberModel> members;
  final int total;
  final int currentPage;
  final int lastPage;

  const MembersPage({
    required this.members,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Service untuk mengakses REST API Fluent Community.
///
/// Semua endpoint memerlukan autentikasi (cookie WordPress).
class ApiService {
  static const String _baseUrl =
      'https://titc.or.id/wp-json/fluent-community/v2';

  // Client HTTP dipakai bersama supaya koneksi ke titc.or.id bisa dipakai
  // ulang antar request (bukan handshake TCP/TLS baru tiap panggilan).
  static final http.Client client = http.Client();

  // Cache hasil fetch terakhir, dipakai layar (Home/Spaces) untuk tampil
  // instan saat tab dibuka lagi alih-alih fetch ulang dari nol setiap kali
  // pindah tab. Direset saat logout lewat [clearCache].
  static List<ActivityModel>? cachedActivities;
  static List<SpaceModel>? cachedSpaces;
  static List<CourseModel>? cachedCourses;

  static void clearCache() {
    cachedActivities = null;
    cachedSpaces = null;
    cachedCourses = null;
    _joinedSpacesCache = {};
    _likedFeedIdsCache = {};
    _followedUsernamesCache = {};
  }

  // Menyimpan slug space yang sudah di-join secara lokal sebagai fallback
  static Set<String> _joinedSpacesCache = {};

  static Future<void> _initJoinedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('joined_spaces');
    if (cached != null) {
      _joinedSpacesCache = cached.toSet();
    }
  }

  static Future<void> _addJoinedSpace(String slug) async {
    _joinedSpacesCache.add(slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('joined_spaces', _joinedSpacesCache.toList());
  }

  // Menyimpan id feed yang sudah di-like secara lokal — pola yang sama
  // persis dengan `_joinedSpacesCache` di atas, karena masalahnya sama:
  // server tidak (atau belum diketahui bagaimana) melaporkan balik status
  // "sudah di-like" dengan andal lewat `/feeds`, jadi status like hilang
  // tiap kali app di-restart kalau hanya mengandalkan field dari server.
  // Menyimpannya sendiri di perangkat membuat tombol Like tetap benar
  // setelah restart TANPA bergantung pada nama field server yang belum
  // pasti.
  static Set<int> _likedFeedIdsCache = {};
  static bool _likedFeedIdsCacheLoaded = false;

  static Future<void> _initLikedFeedIdsCache() async {
    if (_likedFeedIdsCacheLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('liked_feed_ids');
    if (cached != null) {
      _likedFeedIdsCache =
          cached.map((e) => int.tryParse(e)).whereType<int>().toSet();
    }
    _likedFeedIdsCacheLoaded = true;
  }

  /// Dipakai Home untuk mengisi status Like seketika saat feed dimuat,
  /// tanpa menunggu (atau bergantung pada) field dari server.
  static Future<Set<int>> getLikedFeedIdsCache() async {
    await _initLikedFeedIdsCache();
    return Set<int>.from(_likedFeedIdsCache);
  }

  static Future<void> _setFeedLikedLocally(int feedId, bool liked) async {
    await _initLikedFeedIdsCache();
    if (liked) {
      _likedFeedIdsCache.add(feedId);
    } else {
      _likedFeedIdsCache.remove(feedId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'liked_feed_ids',
      _likedFeedIdsCache.map((e) => e.toString()).toList(),
    );
  }

  // Menyimpan username member yang sudah di-follow secara lokal — pola yang
  // sama persis dengan `_likedFeedIdsCache` di atas, karena masalahnya juga
  // sama: respons `/members` TIDAK punya field status follow sama sekali
  // (dibuktikan log `MEMBER_JSON`: hanya ada user_id, display_name,
  // username, avatar, status, meta, dst). Akibatnya semua member selalu
  // dianggap belum di-follow, tombolnya menampilkan "Follow", lalu server
  // menolak dengan 422 "You are already following..." saat ditekan.
  static Set<String> _followedUsernamesCache = {};
  static bool _followedUsernamesCacheLoaded = false;

  static Future<void> _initFollowedUsernamesCache() async {
    if (_followedUsernamesCacheLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('followed_usernames');
    if (cached != null) {
      _followedUsernamesCache = cached.toSet();
    }
    _followedUsernamesCacheLoaded = true;
  }

  /// Dipakai layar Members untuk mengisi status Follow seketika saat daftar
  /// dimuat, tanpa bergantung pada field server yang memang tidak ada.
  static Future<Set<String>> getFollowedUsernamesCache() async {
    await _initFollowedUsernamesCache();
    return Set<String>.from(_followedUsernamesCache);
  }

  static Future<void> _setMemberFollowedLocally(
    String username,
    bool followed,
  ) async {
    await _initFollowedUsernamesCache();
    if (followed) {
      _followedUsernamesCache.add(username);
    } else {
      _followedUsernamesCache.remove(username);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'followed_usernames',
      _followedUsernamesCache.toList(),
    );
  }

  /// Headers standar yang menyertakan cookie autentikasi.
  static Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'TITC Mobile App/1.0 (Android; Dart)',
      'Referer': 'https://titc.or.id/portal/',
      if (AuthService.cookies != null) 'Cookie': AuthService.cookies!,
      if (AuthService.wpNonce != null) 'X-WP-Nonce': AuthService.wpNonce!,
    };
  }

  /// GET dengan auth headers. Jika server menolak dengan 401/403 (biasanya
  /// karena X-WP-Nonce belum sempat/gagal diambil, mis. setelah ganti akun),
  /// coba refresh nonce sekali lalu retry sebelum menyerah.
  ///
  /// Juga menangani timeout dan error jaringan: retry 1x setelah jeda 2
  /// detik sebelum throw. Server TITC bisa lambat (apalagi saat LiteSpeed
  /// Cache sedang memproses), jadi retry 1x cukup mengurangi false-timeout.
  static Future<http.Response> authorizedGet(Uri uri) async {
    http.Response response;
    try {
      response = await client
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      // Retry 1x untuk timeout / network error
      print('authorizedGet: first attempt failed ($e), retrying in 2s...');
      await Future.delayed(const Duration(seconds: 2));
      response = await client
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthService.refreshNonce();
      response = await client
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));
    }

    return response;
  }

  /// Ukuran halaman feed Home, disamakan dengan nilai yang tertangkap dari
  /// request asli portal web (lihat dokumentasi [searchFeeds]).
  static const int feedsPerPage = 10;

  /// Ambil halaman pertama feed/activity dari Fluent Community. Di-dedupe:
  /// kalau beberapa tab dibuka berdekatan sama-sama memicu fetch ini, mereka
  /// berbagi satu request yang sama alih-alih menembak beberapa request
  /// paralel ke host yang sama (penyebab lambat/timeout saat pindah tab).
  static Future<List<ActivityModel>>? _activitiesInFlight;

  static Future<List<ActivityModel>> fetchActivities() {
    return _activitiesInFlight ??=
        _doFetchActivitiesPage(page: 1, perPage: feedsPerPage).whenComplete(() {
      _activitiesInFlight = null;
    });
  }

  /// Ambil SATU halaman feed, dipakai untuk infinite scroll di Home.
  ///
  /// `/feeds` TIDAK mengembalikan seluruh feed sekaligus — sebelumnya Home
  /// memanggil endpoint ini tanpa parameter halaman sama sekali, jadi hanya
  /// batch pertama yang pernah termuat sepanjang app berjalan. Itu sebabnya
  /// feed di app terlihat lebih sedikit daripada di web walau sudah di-scroll
  /// sampai bawah — bukan masalah parsing, tapi tidak pernah ada yang minta
  /// halaman berikutnya. Parameter query sama persis dengan [searchFeeds]
  /// (dikonfirmasi dari request asli portal web via DevTools), minus
  /// parameter pencarian.
  ///
  /// Halaman pertama tidak di-dedupe di sini (itu tugas [fetchActivities]);
  /// halaman berikutnya juga sengaja tidak di-dedupe karena hampir tidak
  /// pernah ada dua request bersamaan untuk halaman lanjutan yang sama.
  static Future<List<ActivityModel>> fetchActivitiesPage({
    required int page,
    int perPage = feedsPerPage,
  }) {
    return _doFetchActivitiesPage(page: page, perPage: perPage);
  }

  /// Bongkar daftar item feed dari berbagai bentuk respons yang mungkin
  /// dikembalikan Fluent Community: array langsung, `{data: [...]}`,
  /// `{activities: {data: [...]}}`, atau `{feeds: {data: [...]}}`.
  ///
  /// Dipakai bersama oleh feed Home dan pencarian post, karena keduanya
  /// menembak endpoint `/feeds` yang sama.
  static List<dynamic> _extractFeedItems(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return const [];

    for (final key in ['feeds', 'activities']) {
      final section = data[key];
      if (section is Map && section['data'] is List) {
        return section['data'] as List;
      }
      if (section is List) return section;
    }
    if (data['data'] is List) return data['data'] as List;
    return const [];
  }

  /// Cari post lewat endpoint `/feeds` — endpoint yang sama dengan feed Home,
  /// hanya diberi parameter pencarian.
  ///
  /// Bentuk parameternya disalin dari request asli portal web (hasil inspeksi
  /// DevTools, mengikuti metode PRD §13):
  ///
  /// ```
  /// GET /feeds?page=1&per_page=10&space=&order_by_type=latest
  ///            &search=free&search_in[0]=post_content
  /// ```
  ///
  /// [spaceSlug] kosong berarti "All Posts"; diisi slug space untuk
  /// mempersempit ke satu Membership Area.
  static Future<List<ActivityModel>> searchFeeds({
    required String query,
    String spaceSlug = '',
    bool includeComments = false,
    int page = 1,
    int perPage = 20,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    // `post_content` terverifikasi dari request web. `comments` menyusul
    // pola yang sama untuk centang "Comments" — kalau server tidak
    // mengenalinya, dia diabaikan dan hasilnya kembali ke judul+isi saja,
    // bukan error.
    final searchIn = <String>['post_content', if (includeComments) 'comments'];

    final uri = Uri.parse('$_baseUrl/feeds').replace(
      queryParameters: <String, String>{
        'feed_base_url': 'feeds',
        'page': '$page',
        'per_page': '$perPage',
        'space': spaceSlug,
        'order_by_type': 'latest',
        'search': query,
        for (var i = 0; i < searchIn.length; i++)
          'search_in[$i]': searchIn[i],
      },
    );

    try {
      final response = await authorizedGet(uri);
      print('SEARCH_FEEDS: $uri → ${response.statusCode}');

      if (response.statusCode == 200) {
        return _extractFeedItems(json.decode(response.body))
            .map((e) => ActivityModel.fromFluentCommunity(e))
            .toList();
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      }
      throw Exception('Gagal mencari post: ${response.statusCode}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<List<ActivityModel>> _doFetchActivitiesPage({
    required int page,
    required int perPage,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/feeds').replace(
        queryParameters: <String, String>{
          'feed_base_url': 'feeds',
          'page': '$page',
          'per_page': '$perPage',
          'space': '',
          'order_by_type': 'latest',
        },
      );

      print('--- FETCH FEEDS DEBUG ---');
      print('URL: $uri');

      final response = await authorizedGet(uri);

      print('Status Code: ${response.statusCode}');
      // Truncate response body to avoid flooding stdout
      final bodyPreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}... (${response.body.length} chars total)'
          : response.body;
      print('Response Body (preview): $bodyPreview');
      print('-------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final feeds = _extractFeedItems(data);

        // Debug: cetak JSON mentah item pertama supaya nama field asli
        // untuk status "sudah di-like" (dipakai ActivityModel.isLikedByMe)
        // bisa dipastikan, bukan cuma tebakan beberapa nama umum.
        if (page == 1 && feeds.isNotEmpty) {
          const encoder = JsonEncoder.withIndent('  ');
          for (final line in encoder.convert(feeds.first).split('\n')) {
            print('FEED_JSON: $line');
          }
        }

        final activities = feeds
            .map((json) => ActivityModel.fromFluentCommunity(json))
            .toList();
        // Cache cuma halaman pertama — itu yang dipakai Home untuk tampil
        // instan saat tab dibuka lagi. Halaman lanjutan (infinite scroll)
        // tidak masuk cache supaya tidak salah dianggap "daftar penuh".
        if (page == 1) cachedActivities = activities;
        return activities;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }
  /// Ambil daftar spaces dari Fluent Community. Fetch daftar penuh (tanpa
  /// search) di-dedupe seperti [fetchActivities]; fetch dengan search tidak
  /// perlu di-dedupe karena tiap query beda hasil.
  static Future<List<SpaceModel>>? _spacesInFlight;

  static Future<List<SpaceModel>> fetchSpaces({String search = ''}) {
    if (search.isEmpty) {
      return _spacesInFlight ??= _doFetchSpaces(search: search).whenComplete(() {
        _spacesInFlight = null;
      });
    }
    return _doFetchSpaces(search: search);
  }

  static Future<List<SpaceModel>> _doFetchSpaces({String search = ''}) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      // Pakai `/spaces/discover?type=all`, BUKAN `/spaces`.
      //
      // `/spaces` hanya mengembalikan space yang sudah di-join user — terbukti
      // dari log: server mengirim 5 space, semuanya ber-badge "Member" di web,
      // sementara "TOEFL - Mockup Test" (belum di-join, tombolnya "Join")
      // tidak ikut. Akibatnya toggle All/Joined di tab Spaces jadi percuma
      // karena keduanya menampilkan daftar yang sama, dan user tidak pernah
      // bisa menemukan space baru untuk di-join lewat app.
      //
      // Endpoint & parameter di bawah disalin dari request asli portal web
      // (hasil inspeksi DevTools, metode PRD §13):
      //   GET /spaces/discover?type=all&search=&sort_by=alphabetical
      //                       &page=1&per_page=24
      final uri = Uri.parse('$_baseUrl/spaces/discover').replace(
        queryParameters: <String, String>{
          'type': 'all',
          'search': search,
          'sort_by': 'alphabetical',
          'page': '1',
          // Web memakai 24; dinaikkan karena app menampilkan seluruh daftar
          // sekaligus (tanpa pagination) dan jumlah space bisa bertambah.
          'per_page': '100',
        },
      );

      final response = await authorizedGet(uri);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else if (response.statusCode != 200) {
        throw Exception('Gagal memuat spaces: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      // Respons `/spaces` TIDAK dipaginate (log menunjukkan current_page &
      // last_page selalu null). Masalah "ada space yang tidak muncul" bukan
      // karena halaman berikutnya tidak diambil, tapi karena FCOM menaruh
      // space di beberapa tempat sekaligus dalam satu respons: ada yang di
      // key `spaces`, ada yang dikelompokkan di bawah parent/kategori, dan
      // ada yang di key lain lagi. Kalau kita cuma baca satu key, space
      // seperti "Update - Certification" ikut hilang.
      //
      // Jadi di sini kita telusuri seluruh struktur JSON dan pungut apa pun
      // yang berbentuk space (punya id + slug + title), lalu dedupe by id.
      // Cara ini tahan terhadap perubahan/variasi bentuk respons.
      final collected = <int, Map<String, dynamic>>{};
      _collectSpaceLikeObjects(data, collected);

      // Course adalah Space dengan `type: "course"` dan sudah punya tabnya
      // sendiri, jadi jangan ikut ditampilkan di tab Spaces.
      final spaces = collected.values
          .where((json) => (json['type'] as String?) != 'course')
          .toList();

      if (data is Map) {
        print('SPACES_ENVELOPE_KEYS: ${data.keys.toList()}');
        // Cetak SETIAP entri mentah apa adanya, sebelum disaring collector.
        // Ini yang menentukan apakah space hilang karena server memang tidak
        // mengirimnya, atau karena tersaring di sisi aplikasi.
        data.forEach((key, value) {
          if (value is List) {
            print('SPACES_RAW[$key]: ${value.length} entri');
            for (final item in value) {
              if (item is Map) {
                print('SPACES_RAW_ITEM[$key]: id=${item['id']} slug=${item['slug']} type=${item['type']} privacy=${item['privacy']} status=${item['status']} title=${item['title']}');
                // Gambar sengaja dicetak terpisah: kartu space "Update -
                // Announcement" & "Update - Certification" tidak menampilkan
                // gambar, perlu dipastikan apakah URL-nya memang kosong/null
                // dari server atau ada tapi gagal dimuat.
                print('SPACES_RAW_IMG[$key]: title=${item['title']} logo=${item['logo']} cover_photo=${item['cover_photo']}');
              } else {
                print('SPACES_RAW_ITEM[$key]: (bukan objek) $item');
              }
            }
          } else if (value is Map) {
            print('SPACES_RAW[$key]: objek dengan keys ${value.keys.toList()}');
          }
        });
      }
      print('SPACES_COLLECTED: total=${collected.length} nonCourse=${spaces.length}');
      for (final s in spaces) {
        print('SPACE_ITEM: id=${s['id']} type=${s['type']} privacy=${s['privacy']} status=${s['status']} title=${s['title']}');
      }
      // Nama field keanggotaan di respons `discover` belum diketahui —
      // SpaceModel baru mencoba `is_joined` dan `is_member`. Daftar key entri
      // pertama dicetak sekali supaya ketahuan field aslinya, karena tanpa itu
      // badge "Member"/tombol Join di app bisa salah tampil.
      if (spaces.isNotEmpty) {
        print('SPACE_KEYS: ${spaces.first.keys.toList()}');
      }

      await _initJoinedCache();

      final result = spaces.map((json) {
        final space = SpaceModel.fromJson(json);
        // Inject isJoined from cache if the API didn't provide it
        if (_joinedSpacesCache.contains(space.slug)) {
          return SpaceModel(
            id: space.id,
            slug: space.slug,
            title: space.title,
            description: space.description,
            logoUrl: space.logoUrl,
            coverPhotoUrl: space.coverPhotoUrl,
            membersCount: space.membersCount,
            isJoined: true,
            privacy: space.privacy,
          );
        }
        return space;
      }).toList();
      // Hanya cache hasil daftar penuh (tanpa search), supaya tab Spaces
      // tidak salah menampilkan hasil pencarian sebagai daftar default.
      if (search.isEmpty) {
        cachedSpaces = result;
      }
      return result;
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Telusuri seluruh struktur JSON respons dan pungut setiap objek yang
  /// berbentuk Space, ke mana pun FCOM menaruhnya (langsung di key `spaces`,
  /// dikelompokkan di bawah parent/kategori, atau di key lain). Hasilnya
  /// di-dedupe berdasarkan `id` supaya space yang muncul di dua tempat tidak
  /// dobel.
  ///
  /// Objek dianggap Space kalau punya `id`, `slug`, dan `title`. Key `settings`
  /// dilewati karena isinya konfigurasi, bukan daftar space.
  static void _collectSpaceLikeObjects(
    dynamic node,
    Map<int, Map<String, dynamic>> out,
  ) {
    if (node is List) {
      for (final item in node) {
        _collectSpaceLikeObjects(item, out);
      }
      return;
    }
    if (node is! Map) return;

    final rawId = node['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id != null && node['slug'] is String && node['title'] is String) {
      out.putIfAbsent(id, () => Map<String, dynamic>.from(node));
    }

    node.forEach((key, value) {
      if (key == 'settings') return;
      if (value is List || value is Map) {
        _collectSpaceLikeObjects(value, out);
      }
    });
  }

  /// Bergabung ke dalam suatu Space.
  static Future<bool> joinSpace(String spaceSlug) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/spaces/$spaceSlug/join'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _addJoinedSpace(spaceSlug);
        return true;
      } else if (response.statusCode == 422 && response.body.contains('already a member')) {
        // Jika server menolak karena user sudah menjadi member, kita anggap sukses
        await _addJoinedSpace(spaceSlug);
        return true;
      } else {
        print('Failed to join space: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception in joinSpace: $e');
      return false;
    }
  }

  /// Ambil daftar courses dari Fluent Community (module Course = Space
  /// dengan `type: "course"`, jadi bentuk responsnya serupa `fetchSpaces`).
  /// Fetch daftar penuh (tanpa search) di-dedupe seperti [fetchActivities].
  static Future<List<CourseModel>>? _coursesInFlight;

  static Future<List<CourseModel>> fetchCourses({String search = ''}) {
    if (search.isEmpty) {
      return _coursesInFlight ??= _doFetchCourses(search: search).whenComplete(() {
        _coursesInFlight = null;
      });
    }
    return _doFetchCourses(search: search);
  }

  static Future<List<CourseModel>> _doFetchCourses({String search = ''}) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/courses').replace(
        queryParameters: search.isNotEmpty ? {'search': search} : null,
      );

      final response = await authorizedGet(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<dynamic> courses;
        if (data is List) {
          courses = data;
        } else if (data is Map && data.containsKey('courses')) {
          if (data['courses'] is Map && data['courses'].containsKey('data')) {
            courses = data['courses']['data'] as List;
          } else if (data['courses'] is List) {
            courses = data['courses'] as List;
          } else {
            courses = [];
          }
        } else if (data is Map && data.containsKey('data')) {
          courses = data['data'] as List;
        } else {
          courses = [];
        }

        // Debug sementara: tampilkan JSON mentah course pertama supaya kita
        // bisa lihat nama field asli untuk status enrollment/akses (dipakai
        // untuk investigasi kasus "Continue Learning" mengarah ke course
        // yang ternyata private meski akun sudah py access di web).
        if (courses.isNotEmpty) {
          const encoder = JsonEncoder.withIndent('  ');
          final jsonStr = encoder.convert(courses.first);
          for (final line in jsonStr.split('\n')) {
            print('COURSE_JSON: $line');
          }
        }

        final result = courses.map((json) => CourseModel.fromJson(json)).toList();
        for (final c in result) {
          print('COURSE_PARSED: slug=${c.slug} isEnrolled=${c.isEnrolled} privacy=${c.privacy} title=${c.title}');
        }
        // Hanya cache hasil daftar penuh (tanpa search), supaya tab Courses
        // tidak salah menampilkan hasil pencarian sebagai daftar default.
        if (search.isEmpty) {
          cachedCourses = result;
        }
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat courses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Mendaftar (enroll) ke suatu Course. Course di TITC umumnya privat dan
  /// baru bisa diakses setelah didaftarkan manual oleh admin (pembelian di
  /// web), jadi endpoint ini bisa menolak dengan pesan spesifik dari server
  /// alih-alih generic error — pesan itu diteruskan supaya UI bisa
  /// menampilkannya apa adanya ke pengguna.
  static Future<String?> enrollCourse(int courseId) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/courses/$courseId/enroll'),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // null = sukses
      }

      String? message;
      try {
        final data = json.decode(response.body);
        if (data is Map && data['message'] is String) {
          message = data['message'];
        }
      } catch (_) {}
      return message ?? 'Gagal mendaftar course (${response.statusCode}).';
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Ambil feed spesifik untuk suatu space.
  static Future<List<ActivityModel>> fetchSpaceFeeds(int spaceId) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      // Biasanya parameter group_id atau space_id ditambahkan untuk mengambil feed khusus space
      final uri = Uri.parse('$_baseUrl/feeds').replace(
        queryParameters: {'space_id': spaceId.toString()},
      );

      final response = await authorizedGet(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<dynamic> feeds;
        if (data is List) {
          feeds = data;
        } else if (data is Map && data.containsKey('data')) {
          feeds = data['data'] as List;
        } else if (data is Map && data.containsKey('activities')) {
          if (data['activities'] is Map && data['activities'].containsKey('data')) {
            feeds = data['activities']['data'] as List;
          } else {
            feeds = [];
          }
        } else if (data is Map && data.containsKey('feeds')) {
          if (data['feeds'] is Map && data['feeds'].containsKey('data')) {
            feeds = data['feeds']['data'] as List;
          } else if (data['feeds'] is List) {
            feeds = data['feeds'] as List;
          } else {
            feeds = [];
          }
        } else {
          feeds = [];
        }

        // Karena parameter query API mungkin diabaikan (mengembalikan global feed),
        // kita filter secara lokal untuk memastikan feed sesuai dengan Space yang dipilih
        final spaceFeeds = feeds.where((json) {
          final sId = json['space_id']?.toString() ?? json['group_id']?.toString();
          return sId == spaceId.toString();
        }).toList();

        return spaceFeeds
            .map((json) => ActivityModel.fromFluentCommunity(json))
            .toList();
      } else {
        throw Exception('Gagal memuat space feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Ambil satu halaman members dari Fluent Community.
  ///
  /// Member di TITC jumlahnya ribuan (web menampilkan "All Members (2,256)"),
  /// jadi datanya diambil per halaman lalu di-scroll tak terbatas di UI —
  /// bukan sekali tarik semua.
  ///
  /// [status] dipakai filter Active/Pending/Blocked khusus admin (lihat
  /// `MembersListScreen`) — nilai `active`/`pending`/`blocked` sesuai field
  /// `status` yang sama persis dikembalikan API pada tiap member (bukan
  /// tebakan; sudah terlihat di log `MEMBER_JSON` sebelumnya, mis.
  /// `"status": "active"`). Kosong berarti tanpa filter, sama seperti
  /// sebelum parameter ini ada.
  static Future<MembersPage> fetchMembers({
    String search = '',
    int page = 1,
    String status = '',
  }) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/members').replace(
        queryParameters: {
          if (search.isNotEmpty) 'search': search,
          if (status.isNotEmpty) 'status': status,
          'page': page.toString(),
        },
      );

      final response = await authorizedGet(uri);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else if (response.statusCode != 200) {
        throw Exception('Gagal memuat members: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      // Bentuk respons bisa: List langsung, {data: [...]}, atau objek
      // paginator {data: {data: [...], total, current_page, last_page}}.
      List<dynamic> items = const [];
      int? total;
      int? currentPage;
      int? lastPage;

      void readPaginator(Map wrapper) {
        items = (wrapper['data'] as List?) ?? const [];
        total = wrapper['total'] as int?;
        currentPage = wrapper['current_page'] as int?;
        lastPage = wrapper['last_page'] as int?;
      }

      if (data is List) {
        items = data;
      } else if (data is Map && data['members'] is Map) {
        readPaginator(data['members'] as Map);
      } else if (data is Map && data['data'] is Map) {
        readPaginator(data['data'] as Map);
      } else if (data is Map && data['members'] is List) {
        items = data['members'] as List;
        total = data['total'] as int?;
      } else if (data is Map && data['data'] is List) {
        items = data['data'] as List;
        total = data['total'] as int?;
      }

      if (page == 1) {
        print('MEMBERS_PAGE_INFO: total=$total currentPage=$currentPage lastPage=$lastPage items=${items.length}');
        if (items.isNotEmpty) {
          const encoder = JsonEncoder.withIndent('  ');
          for (final line in encoder.convert(items.first).split('\n')) {
            print('MEMBER_JSON: $line');
          }
        }

        // Cari tahu APA KAH endpoint members memang mengirim data sosial, dan
        // kalau iya dalam bentuk apa (URL penuh atau username saja). Selama
        // ini bentuknya cuma ditebak, jadi ikon sosial bisa jadi tidak pernah
        // muncul sama sekali karena field-nya memang tidak ada di respons.
        // Cetak SEMUA key `meta` yang isinya tidak kosong, dari member mana
        // pun di halaman ini. Sampel pertama (akun sendiri) belum tentu
        // mengisi profil sosial, jadi memeriksa satu member saja menyesatkan.
        final metaKeysSeen = <String>{};
        var withSocial = 0;
        for (final item in items) {
          if (item is! Map) continue;
          final meta = item['meta'] ??
              (item['xprofile'] is Map ? item['xprofile']['meta'] : null);
          if (meta is! Map) continue;

          final filled = <String, dynamic>{};
          meta.forEach((key, value) {
            metaKeysSeen.add('$key');
            final isEmptyish = value == null ||
                (value is String && value.trim().isEmpty) ||
                (value is List && value.isEmpty);
            if (!isEmptyish) filled['$key'] = value;
          });

          if (filled.isNotEmpty) {
            withSocial++;
            if (withSocial <= 5) {
              print('MEMBER_META_FILLED: ${item['username'] ?? item['slug']} -> ${json.encode(filled)}');
            }
          }
        }
        print('MEMBER_META_ALL_KEYS: ${metaKeysSeen.toList()}');
        print('MEMBER_META_SUMMARY: $withSocial dari ${items.length} member punya isi meta');
      }

      return MembersPage(
        members: items.map((json) => MemberModel.fromJson(json)).toList(),
        total: total ?? items.length,
        currentPage: currentPage ?? page,
        lastPage: lastPage ?? (items.isEmpty ? page : page + 1),
      );
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  /// Ikuti / berhenti mengikuti seorang member.
  ///
  /// Endpoint `POST /profile/{username}/follow` (dan `/unfollow`) **sudah
  /// terbukti benar** — dikonfirmasi dari respons server yang menjawab
  /// dengan pesan bermakna, bukan 404.
  ///
  /// Status 422 diperlakukan sebagai BERHASIL. Server membalas 422 dengan
  /// "You are already following or blocked this user." ketika user memang
  /// sudah mengikuti member itu — kondisi yang justru sudah sesuai keinginan
  /// user. Ini terjadi karena `/members` tidak mengirim status follow sama
  /// sekali (lihat catatan di `_followedUsernamesCache`), jadi tombol selalu
  /// tampil "Follow" walau sebenarnya sudah diikuti.
  ///
  /// Konsekuensi yang perlu diketahui: pesan 422 itu menggabungkan dua
  /// keadaan — "sudah follow" DAN "user diblokir" — dan server tidak
  /// membedakannya. Untuk kasus terblokir, tombol jadi menampilkan
  /// "Following" padahal sebenarnya tidak. Itu kasus yang jauh lebih jarang
  /// daripada "sudah follow", dan menampilkan error di kasus umum lebih
  /// merugikan daripada label yang meleset di kasus langka.
  static Future<bool> toggleFollowMember(String username, {required bool follow}) async {
    if (!AuthService.isLoggedIn) return false;

    // Username kosong bikin URL jadi `/profile//follow` yang pasti ditolak
    // server. Dihentikan lebih awal supaya penyebabnya jelas di log, bukan
    // muncul sebagai 404 yang membingungkan.
    if (username.trim().isEmpty) {
      print('TOGGLE_FOLLOW: dibatalkan — username KOSONG (follow=$follow)');
      return false;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/profile/$username/${follow ? 'follow' : 'unfollow'}',
      );
      print('TOGGLE_FOLLOW REQ: $uri');
      final response = await client
          .post(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));
      print('TOGGLE_FOLLOW RES: ${response.statusCode} - ${response.body}');

      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          // "Sudah dalam keadaan yang diminta" — lihat penjelasan di atas.
          response.statusCode == 422;

      print('TOGGLE_FOLLOW: $uri follow=$follow status=${response.statusCode} ok=$ok '
          'body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      // Simpan ke perangkat supaya tombolnya tetap benar setelah restart,
      // tanpa bergantung field server yang memang tidak ada.
      if (ok) await _setMemberFollowedLocally(username, follow);
      return ok;
    } catch (e) {
      print('TOGGLE_FOLLOW: exception username=$username follow=$follow -> $e');
      return false;
    }
  }

  /// Kirim/batalkan reaksi "like" pada satu item feed, langsung ke server —
  /// bukan cuma perubahan tampilan lokal, supaya statusnya benar-benar
  /// tersimpan dan sinkron dengan portal web secara realtime.
  ///
  /// Endpoint `POST .../feeds/{id}/react` dengan body `{"reaction": "like"}`
  /// dikonfirmasi dari inspeksi request asli portal web — dan terbukti
  /// benar-benar tersimpan permanen di server (dikonfirmasi user).
  ///
  /// Untuk batal-like, sebelumnya dipakai `DELETE` ke endpoint yang sama
  /// (dugaan konvensi REST) — **terbukti salah**, gagal konsisten 2x
  /// (dikonfirmasi user: respons ditolak server). Diganti jadi POST yang
  /// SAMA untuk kedua arah: like/unlike jadi murni TOGGLE di sisi server,
  /// bukan dua method HTTP berbeda. Ini pola yang lazim dipakai endpoint
  /// reaksi semacam ini, dan konsisten dengan bukti yang ada (POST selalu
  /// berhasil, DELETE selalu gagal).
  ///
  /// Status like disimpan lokal via [_setFeedLikedLocally] setelah berhasil
  /// — lihat catatan di sana kenapa ini perlu (server tidak melaporkan
  /// balik status "sudah di-like" dengan andal lewat `/feeds`).
  static Future<bool> toggleFeedLike(int feedId, {required bool like}) async {
    if (!AuthService.isLoggedIn) return false;
    try {
      final uri = Uri.parse('$_baseUrl/feeds/$feedId/react');
      final body = json.encode({'reaction': 'like'});
      final response = await client
          .post(uri, headers: authHeaders, body: body)
          .timeout(const Duration(seconds: 15));
      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      print('TOGGLE_LIKE: feedId=$feedId like=$like method=POST '
          'status=${response.statusCode} ok=$ok body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (ok) await _setFeedLikedLocally(feedId, like);
      return ok;
    } catch (e) {
      print('TOGGLE_LIKE: exception feedId=$feedId like=$like -> $e');
      return false;
    }
  }
  /// Ambil profil lengkap member.
  static Future<MemberModel?> fetchMemberProfile(String slug) async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final uri = Uri.parse('$_baseUrl/profile/$slug?_t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await authorizedGet(uri);
      print('FETCH_MEMBER_PROFILE ($slug) STATUS: ${response.statusCode}');
      print('FETCH_MEMBER_PROFILE BODY: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['profile'] != null) {
          return MemberModel.fromJson(data['profile']);
        } else if (data is Map && data['user'] != null) {
          return MemberModel.fromJson(data['user']);
        }
        return MemberModel.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      print('fetchMemberProfile error: $e');
    }
    return null;
  }

  /// Ambil feed spesifik untuk seorang user.
  static Future<List<ActivityModel>> fetchUserFeeds(String slug) async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final uri = Uri.parse('$_baseUrl/profile/$slug/feeds');
      final response = await authorizedGet(uri);
      print('fetchUserFeeds STATUS: ${response.statusCode}');
      print('fetchUserFeeds BODY: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode == 200) {
        final items = _extractFeedItems(json.decode(response.body));
        print('fetchUserFeeds ITEMS COUNT: ${items.length}');
        return items.map((e) => ActivityModel.fromFluentCommunity(e)).toList();
      }
    } catch (e) {
      print('fetchUserFeeds error: $e');
    }
    return [];
  }

  /// Ambil space spesifik untuk seorang user.
  static Future<List<SpaceModel>> fetchUserSpaces(String slug) async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final uri = Uri.parse('$_baseUrl/profile/$slug/spaces');
      final response = await authorizedGet(uri);
      print('fetchUserSpaces STATUS: ${response.statusCode}');
      print('fetchUserSpaces BODY: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final collected = <int, Map<String, dynamic>>{};
        _collectSpaceLikeObjects(data, collected);
        print('fetchUserSpaces COLLECTED: ${collected.length}');
        // `/profile/{slug}/spaces` = space milik profil ini sendiri, jadi
        // pasti sudah di-join — tapi endpoint ini tidak selalu mengirim
        // `space_pivot` seperti `/spaces/discover`. Tanpa paksaan ini,
        // SpaceModel.isJoined jatuh ke false dan kartu menampilkan tombol
        // "Join" alih-alih "View Space" (Join tidak menavigasi ke mana pun).
        //
        // Cover foto endpoint ini juga tidak bisa dipercaya begitu saja:
        // `cover_photo` di sini sering berisi banner branding portal generik
        // yang sama untuk banyak space (nama filenya "PORTAL-HEADER.webp" /
        // "HEADER-TITC-INDONESIA.webp", terverifikasi dari log
        // SPACE_PROFILE_ITEM — dua space beda bisa punya `cover_photo` dengan
        // nama file identik), sedangkan `settings.og_image` berisi foto asli
        // yang beda-beda per space. Utamakan `og_image` di sini kalau ada.
        return collected.values
            .where((json) => (json['type'] as String?) != 'course')
            .map((e) {
              final settings = e['settings'];
              final ogImage =
                  settings is Map ? settings['og_image'] as String? : null;
              final merged = {...e, 'is_joined': true};
              if (ogImage != null && ogImage.trim().isNotEmpty) {
                merged['cover_photo'] = ogImage;
              }
              return SpaceModel.fromJson(merged);
            })
            .toList();
      }
    } catch (e) {
      print('fetchUserSpaces error: $e');
    }
    return [];
  }

  /// Ambil course spesifik untuk seorang user.
  static Future<List<CourseModel>> fetchUserCourses(String slug) async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final uri = Uri.parse('$_baseUrl/profile/$slug/courses');
      final response = await authorizedGet(uri);
      print('fetchUserCourses STATUS: ${response.statusCode}');
      print('fetchUserCourses BODY: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final collected = <int, Map<String, dynamic>>{};
        _collectSpaceLikeObjects(data, collected);
        print('fetchUserCourses COLLECTED: ${collected.length}');
        // Sama seperti fetchUserSpaces: course di profil sendiri pasti sudah
        // ter-enroll, tapi endpoint ini tidak selalu mengirim `isEnrolled`.
        // Tanpa paksaan ini kartu menampilkan "Enroll" (URL space default,
        // salah untuk course) alih-alih "Continue Learning".
        return collected.values
            .map((e) => CourseModel.fromJson({...e, 'isEnrolled': true}))
            .toList();
      }
    } catch (e) {
      print('fetchUserCourses error: $e');
    }
    return [];
  }

  /// Update profil FCOM (headline, short bio, social links).
  static Future<bool> updateFcomProfile({
    required String slug,
    required Map<String, dynamic> data,
  }) async {
    try {
      final cookies = AuthService.cookies;
      final nonce = AuthService.wpNonce;

      if (cookies == null || nonce == null) {
        print('Missing auth cookies or nonce for updateFcomProfile');
        return false;
      }

      final fcomUrl = Uri.parse('$_baseUrl/profile/$slug');
      // Bentuk persis dikonfirmasi dari cURL DevTools web asli (bukan
      // tebakan): method POST (bukan PUT — PUT membalas 200 tapi diam-diam
      // tidak menyimpan apa pun untuk field selain avatar), dan
      // `query_timestamp` sejajar dengan `data`, bukan di dalamnya.
      final bodyStr = json.encode({
        'data': data,
        'query_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      print('updateFcomProfile PAYLOAD: $bodyStr');
      print('updateFcomProfile URL: $fcomUrl');
      final response = await http.post(
        fcomUrl,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookies,
          'X-WP-Nonce': nonce,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Referer': 'https://titc.or.id/portal/u/$slug/update',
        },
        body: bodyStr,
      );

      print('updateFcomProfile Status: ${response.statusCode}');
      print('updateFcomProfile Body: ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Exception in updateFcomProfile: $e');
      return false;
    }
  }

  static Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? email,
    String? website,
    String? password,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final cookies = AuthService.cookies;
      final nonce = AuthService.wpNonce;

      if (cookies == null || nonce == null) {
        print('Missing auth cookies or nonce for updateProfile');
        return false;
      }

      final url = Uri.parse('https://titc.or.id/wp-json/wp/v2/users/me');
      
      final Map<String, dynamic> body = {};
      if (firstName != null && firstName.isNotEmpty) body['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;
      if (firstName != null && lastName != null) {
        body['name'] = '${firstName.trim()} ${lastName.trim()}'.trim();
      }
      if (bio != null) body['description'] = bio;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (website != null) body['url'] = website;
      if (password != null && password.isNotEmpty) body['password'] = password;
      if (meta != null) body['meta'] = meta;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookies,
          'X-WP-Nonce': nonce,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://titc.or.id/portal/',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update profile: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception in updateProfile: $e');
      return false;
    }
  }

  static Future<bool> uploadAvatar(File imageFile) async {
    try {
      final cookies = AuthService.cookies;
      final nonce = AuthService.wpNonce;
      final slug = AuthService.userSlug;

      if (cookies == null || nonce == null || slug == null) {
        print('Missing auth cookies, nonce, or slug for uploadAvatar');
        return false;
      }

      // 1. Upload to FCOM Media endpoint instead of WP Media (karena WP Media butuh role admin/editor)
      final mediaUrl = Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/feeds/media-upload');
      final mediaReq = http.MultipartRequest('POST', mediaUrl);
      
      mediaReq.headers.addAll({
        'Cookie': cookies,
        'X-WP-Nonce': nonce,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      });
      
      mediaReq.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final mediaStream = await mediaReq.send();
      final mediaRes = await http.Response.fromStream(mediaStream);
      
      if (mediaRes.statusCode != 200 && mediaRes.statusCode != 201) {
        print('Failed to upload to FCOM Media: ${mediaRes.statusCode} - ${mediaRes.body}');
        return false;
      }

      print('FCOM Media Upload Body: ${mediaRes.body}');
      final mediaData = json.decode(mediaRes.body);
      String? uploadedUrl;
      
      if (mediaData is Map) {
        if (mediaData['url'] != null) {
          uploadedUrl = mediaData['url'];
        } else if (mediaData['source_url'] != null) {
          uploadedUrl = mediaData['source_url'];
        } else if (mediaData['file'] is Map && mediaData['file']['url'] != null) {
          uploadedUrl = mediaData['file']['url'];
        } else if (mediaData['image'] != null) {
          uploadedUrl = mediaData['image'];
        } else if (mediaData['data'] is Map && mediaData['data']['url'] != null) {
          uploadedUrl = mediaData['data']['url'];
        } else if (mediaData['media'] is Map && mediaData['media']['url'] != null) {
          uploadedUrl = mediaData['media']['url'];
        } else if (mediaData['media'] is List && mediaData['media'].isNotEmpty && mediaData['media'][0] is Map) {
          uploadedUrl = mediaData['media'][0]['url'];
        }
      } else if (mediaData is List && mediaData.isNotEmpty && mediaData[0] is Map) {
        uploadedUrl = mediaData[0]['url'] ?? mediaData[0]['source_url'];
      }

      if (uploadedUrl == null) {
        print('No url returned from FCOM Media upload. Parsed data: $mediaData');
        return false;
      }

      // 2. Assign the uploaded image URL as the FCOM Avatar
      final fcomUrl = Uri.parse('https://titc.or.id/wp-json/fluent-community/v2/profile/$slug');
      final fcomRes = await http.put(
        fcomUrl,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookies,
          'X-WP-Nonce': nonce,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: json.encode({
          'data': {
            'avatar': uploadedUrl
          }
        })
      );

      print('FCOM Avatar Assign Status: ${fcomRes.statusCode}');
      print('FCOM Avatar Assign Body: ${fcomRes.body}');
      
      return fcomRes.statusCode == 200 || fcomRes.statusCode == 201;
    } catch (e) {
      print('Exception in uploadAvatar: $e');
      return false;
    }
  }
}

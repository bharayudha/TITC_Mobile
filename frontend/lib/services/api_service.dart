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
  static final http.Client _client = http.Client();

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

  /// Headers standar yang menyertakan cookie autentikasi.
  static Map<String, String> get _authHeaders {
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
  static Future<http.Response> _authorizedGet(Uri uri) async {
    var response = await _client
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthService.refreshNonce();
      response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 15));
    }

    return response;
  }

  /// Ambil daftar feed/activity dari Fluent Community. Di-dedupe: kalau
  /// beberapa tab dibuka berdekatan sama-sama memicu fetch ini, mereka
  /// berbagi satu request yang sama alih-alih menembak beberapa request
  /// paralel ke host yang sama (penyebab lambat/timeout saat pindah tab).
  static Future<List<ActivityModel>>? _activitiesInFlight;

  static Future<List<ActivityModel>> fetchActivities() {
    return _activitiesInFlight ??= _doFetchActivities().whenComplete(() {
      _activitiesInFlight = null;
    });
  }

  static Future<List<ActivityModel>> _doFetchActivities() async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      print('--- FETCH FEEDS DEBUG ---');
      print('URL: $_baseUrl/feeds');
      print('Headers: $_authHeaders');

      final response = await _authorizedGet(Uri.parse('$_baseUrl/feeds'));

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('-------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Fluent Community biasanya mengembalikan format:
        // { "data": [...], "meta": {...} } atau langsung array
        List<dynamic> feeds;
        if (data is List) {
          feeds = data;
        } else if (data is Map && data.containsKey('data')) {
          feeds = data['data'] as List;
        } else if (data is Map && data.containsKey('activities')) {
          // Response format for /activities is usually {"activities": {"data": [...]}}
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

        final activities = feeds
            .map((json) => ActivityModel.fromFluentCommunity(json))
            .toList();
        cachedActivities = activities;
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
      // Server bisa mem-paginate /spaces (akun dengan banyak space akan
      // dipecah jadi beberapa halaman). Sebelumnya kode ini cuma baca
      // halaman pertama dan langsung nge-cast `data['spaces']` sebagai
      // List — kalau bentuknya ternyata objek paginator ({data, meta,
      // current_page, last_page, ...}) beberapa/semua space jadi tidak
      // ikut kebaca. Di sini kita loop ambil semua halaman sampai habis.
      final allSpacesJson = <dynamic>[];
      int page = 1;
      while (true) {
        final uri = Uri.parse('$_baseUrl/spaces').replace(
          queryParameters: {
            if (search.isNotEmpty) 'search': search,
            'page': page.toString(),
          },
        );

        final response = await _authorizedGet(uri);

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('Sesi login telah habis. Silakan login ulang.');
        } else if (response.statusCode != 200) {
          throw Exception('Gagal memuat spaces: ${response.statusCode}');
        }

        final data = json.decode(response.body);

        List<dynamic> pageItems;
        int? currentPage;
        int? lastPage;
        if (data is List) {
          pageItems = data;
        } else if (data is Map && data['data'] is Map) {
          final wrapper = data['data'] as Map;
          pageItems = (wrapper['data'] as List?) ?? [];
          currentPage = wrapper['current_page'] as int?;
          lastPage = wrapper['last_page'] as int?;
        } else if (data is Map && data['data'] is List) {
          pageItems = data['data'] as List;
        } else if (data is Map && data['spaces'] is Map) {
          final wrapper = data['spaces'] as Map;
          pageItems = (wrapper['data'] as List?) ?? [];
          currentPage = wrapper['current_page'] as int?;
          lastPage = wrapper['last_page'] as int?;
        } else if (data is Map && data['spaces'] is List) {
          pageItems = data['spaces'] as List;
        } else {
          pageItems = [];
        }

        if (page == 1) {
          print('SPACES_PAGE_INFO: currentPage=$currentPage lastPage=$lastPage itemsOnPage=${pageItems.length}');
          if (pageItems.isNotEmpty) {
            const encoder = JsonEncoder.withIndent('  ');
            final jsonStr = encoder.convert(pageItems.first);
            for (final line in jsonStr.split('\n')) {
              print('FCOM_JSON: $line');
            }
          }
        }

        allSpacesJson.addAll(pageItems);

        final hasMore = currentPage != null && lastPage != null && currentPage < lastPage;
        // Guard `page > 20` cuma jaring pengaman supaya tidak infinite loop
        // kalau field paginasi ternyata berbeda dari dugaan di atas.
        if (!hasMore || pageItems.isEmpty || page > 20) break;
        page++;
      }

      final spaces = allSpacesJson;

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

  /// Bergabung ke dalam suatu Space.
  static Future<bool> joinSpace(String spaceSlug) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/spaces/$spaceSlug/join'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));

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

      final response = await _authorizedGet(uri);

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
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));

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

      final response = await _authorizedGet(uri);

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
  static Future<MembersPage> fetchMembers({
    String search = '',
    int page = 1,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/members').replace(
        queryParameters: {
          if (search.isNotEmpty) 'search': search,
          'page': page.toString(),
        },
      );

      final response = await _authorizedGet(uri);

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
  static Future<bool> toggleFollowMember(int memberId, {required bool follow}) async {
    if (!AuthService.isLoggedIn) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/members/$memberId/${follow ? 'follow' : 'unfollow'}'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Exception in toggleFollowMember: $e');
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

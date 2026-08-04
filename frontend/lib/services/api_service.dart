import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';
import '../models/member_model.dart';
import '../models/space_model.dart';
import 'auth_service.dart';

/// Service untuk mengakses REST API Fluent Community.
///
/// Semua endpoint memerlukan autentikasi (cookie WordPress).
class ApiService {
  static const String _baseUrl =
      'https://titc.or.id/wp-json/fluent-community/v2';
  static const String _wpBaseUrl = 'https://titc.or.id/wp-json/wp/v2';

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
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://titc.or.id/portal/',
      if (AuthService.cookies != null) 'Cookie': AuthService.cookies!,
      if (AuthService.wpNonce != null) 'X-WP-Nonce': AuthService.wpNonce!,
    };
  }

  /// Ambil daftar feed/activity dari Fluent Community.
  static Future<List<ActivityModel>> fetchActivities() async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      print('--- FETCH FEEDS DEBUG ---');
      print('URL: $_baseUrl/feeds');
      print('Headers: $_authHeaders');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/feeds'),
        headers: _authHeaders,
      );

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

        return feeds
            .map((json) => ActivityModel.fromFluentCommunity(json))
            .toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }
  /// Ambil daftar spaces dari Fluent Community.
  static Future<List<SpaceModel>> fetchSpaces({String search = ''}) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/spaces').replace(
        queryParameters: search.isNotEmpty ? {'search': search} : null,
      );

      final response = await http.get(
        uri,
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<dynamic> spaces;
        if (data is List) {
          spaces = data;
        } else if (data is Map && data.containsKey('data')) {
          spaces = data['data'] as List;
        } else if (data is Map && data.containsKey('spaces')) {
          spaces = data['spaces'] as List;
        } else {
          spaces = [];
        }

        if (spaces.isNotEmpty) {
          const encoder = JsonEncoder.withIndent('  ');
          final jsonStr = encoder.convert(spaces.first);
          for (final line in jsonStr.split('\n')) {
            print('FCOM_JSON: $line');
          }
        }

        await _initJoinedCache();

        return spaces.map((json) {
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat spaces: ${response.statusCode}');
      }
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
      );

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

      final response = await http.get(
        uri,
        headers: _authHeaders,
      );

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

  /// Ambil daftar members dari Fluent Community.
  static Future<List<MemberModel>> fetchMembers({String search = ''}) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/members').replace(
        queryParameters: search.isNotEmpty ? {'search': search} : null,
      );

      final response = await http.get(
        uri,
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<dynamic> members;
        if (data is List) {
          members = data;
        } else if (data is Map && data.containsKey('data')) {
          members = data['data'] as List;
        } else if (data is Map && data.containsKey('members')) {
          members = data['members'] as List;
        } else {
          members = [];
        }

        return members.map((json) => MemberModel.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat members: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
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

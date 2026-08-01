import 'dart:convert';
import 'package:http/http.dart' as http;
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
  static Future<List<SpaceModel>> fetchSpaces() async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/spaces'),
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

        return spaces.map((json) => SpaceModel.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Sesi login telah habis. Silakan login ulang.');
      } else {
        throw Exception('Gagal memuat spaces: ${response.statusCode}');
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
  }) async {
    try {
      final cookies = AuthService.cookies;
      final nonce = AuthService.wpNonce;

      if (cookies == null || nonce == null) {
        print('Missing auth cookies or nonce for updateProfile');
        return false;
      }

      final url = Uri.parse('$_baseUrl/wp/v2/users/me');
      
      final Map<String, dynamic> body = {};
      if (firstName != null && firstName.isNotEmpty) body['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;
      if (bio != null) body['description'] = bio;

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
      print('Error in updateProfile: $e');
      return false;
    }
  }
}

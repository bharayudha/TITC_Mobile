import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:magang_titc/services/api_service.dart';
import 'package:magang_titc/services/auth_service.dart';
import 'package:magang_titc/models/notification_model.dart';

class NotificationsService {
  static const String _baseUrl = 'https://titc.or.id/wp-json/fluent-community/v2';

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  static Timer? _pollingTimer;

  static void startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    
    // Initial fetch
    _fetchUnreadCount();
    
    // Poll every 60 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (AuthService.isLoggedIn) {
        _fetchUnreadCount();
      } else {
        stopPolling();
      }
    });
  }

  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    unreadCountNotifier.value = 0;
  }

  static Future<void> _fetchUnreadCount() async {
    try {
      final notifs = await fetchNotifications(type: 'unread');
      unreadCountNotifier.value = notifs.length;
    } catch (e) {
      // Silently fail polling
    }
  }

  static Future<String?> markAllAsRead() async {
    if (!AuthService.isLoggedIn) return 'Not logged in';

    try {
      final headers = Map<String, String>.from(ApiService.authHeaders);
      headers['Content-Type'] = 'application/json';

      final uri = Uri.parse('$_baseUrl/notifications/mark-all-read');
      final response = await ApiService.client.post(
        uri,
        headers: headers,
        body: '{}',
      ).timeout(const Duration(seconds: 30));

      print('MarkAllAsRead response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        unreadCountNotifier.value = 0;
        return null; // Success
      }
      return 'HTTP ${response.statusCode}: ${response.body}';
    } catch (e) {
      print('MarkAllAsRead error: $e');
      return e.toString();
    }
  }

  /// Menandai satu notifikasi sebagai telah dibaca
  static Future<bool> markAsRead(int id) async {
    if (!AuthService.isLoggedIn) return false;

    try {
      final headers = Map<String, String>.from(ApiService.authHeaders);
      headers['Content-Type'] = 'application/json';

      final uri = Uri.parse('$_baseUrl/notifications/mark-read/$id');
      final response = await ApiService.client.post(
        uri,
        headers: headers,
        body: '{}',
      ).timeout(const Duration(seconds: 30));

      print('MarkAsRead response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('MarkAsRead error: $e');
    }
    return false;
  }

  /// Mengambil notifikasi dari endpoint FCOM
  static Future<List<NotificationModel>> fetchNotifications({String type = 'recent'}) async {
    if (!AuthService.isLoggedIn) {
      throw Exception('Anda harus login terlebih dahulu.');
    }

    try {
      Uri uri;
      if (type == 'unread') {
        uri = Uri.parse('$_baseUrl/notifications/unread');
      } else {
        uri = Uri.parse('$_baseUrl/notifications').replace(
          queryParameters: type != 'recent' ? {'type': type} : null,
        );
      }

      final response = await ApiService.authorizedGet(uri);

      print('--- NOTIFICATIONS JSON DEBUG ---');
      print('URL: $uri');
      print('Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final body = response.body;
        // Truncate if too long to prevent console flood, but try to print enough
        final printBody = body.length > 2000 ? body.substring(0, 2000) + '...' : body;
        print('Body: $printBody');
        
        final data = json.decode(body);
        List<dynamic> items = [];
        if (data is Map && data.containsKey('data')) {
           items = data['data'] as List<dynamic>? ?? [];
        } else if (data is List) {
           items = data;
        } else if (data is Map && data.containsKey('notifications')) {
           if (data['notifications'] is Map && data['notifications'].containsKey('data')) {
             items = data['notifications']['data'] as List<dynamic>? ?? [];
           } else if (data['notifications'] is List) {
             items = data['notifications'] as List<dynamic>;
           }
        }
        
        var allItems = items.map((e) => NotificationModel.fromJson(e)).toList();
        
        // Client-side filtering as fallback
        if (type == 'unread') {
          allItems = allItems.where((n) => !n.isRead).toList();
        } else if (type == 'mentions') {
          allItems = allItems.where((n) => n.action.contains('mention')).toList();
        } else if (type == 'following') {
          // If the backend doesn't filter, we might not know which are 'following'
          // We just fallback to showing all or matching specific actions
        }
        
        return allItems;
      } else {
        print('Failed Body: ${response.body}');
        throw Exception('Gagal memuat notifikasi: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }
}

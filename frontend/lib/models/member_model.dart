import 'package:magang_titc/models/json_utils.dart';

/// Model untuk satu entitas Member dari Fluent Community.
class MemberModel {
  final int id;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String lastActivity;
  final String joinedAt;
  final String bio;
  final String status; // misal: 'online', 'offline'
  final bool isFollowed;

  /// Tautan sosial yang dipakai untuk ikon kecil di kartu member,
  /// mis. `{'linkedin': 'https://...', 'facebook': 'https://...'}`.
  final Map<String, String> socialLinks;

  MemberModel({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.lastActivity,
    this.username = '',
    this.joinedAt = '',
    this.bio = '',
    this.status = 'offline',
    this.isFollowed = false,
    this.socialLinks = const {},
  });

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory MemberModel.fromJson(Map<String, dynamic> json) {
    // Beberapa endpoint FCOM membungkus detail profil di `xprofile`, sebagian
    // lain menaruhnya langsung di root — dukung dua-duanya.
    final xprofile = asJsonMap(json['xprofile']);
    T? pick<T>(String key) => (json[key] ?? xprofile[key]) as T?;

    return MemberModel(
      // Respons `/members` memakai `user_id`, bukan `id`. Tanpa fallback ini
      // semua member ber-id 0 sehingga aksi Follow salah sasaran.
      id: pick<int>('user_id') ?? pick<int>('id') ?? 0,
      displayName:
          pick<String>('display_name') ?? pick<String>('name') ?? 'Unknown Member',
      username: pick<String>('username') ??
          pick<String>('user_name') ??
          pick<String>('slug') ??
          '',
      avatarUrl: pick<String>('avatar') ??
          pick<String>('photo') ??
          pick<String>('avatar_url') ??
          pick<String>('photo_url') ??
          '',
      lastActivity: pick<String>('last_activity') ??
          pick<String>('last_seen') ??
          pick<String>('human_diff') ??
          '',
      joinedAt: pick<String>('joined_at') ??
          pick<String>('created_at') ??
          pick<String>('registered_at') ??
          '',
      bio: pick<String>('short_description') ??
          pick<String>('bio') ??
          pick<String>('description') ??
          '',
      status: pick<String>('status') ?? 'offline',
      isFollowed: pick<bool>('is_followed') ?? pick<bool>('is_following') ?? false,
      socialLinks: _parseSocialLinks(json['meta'] ?? xprofile['meta']),
    );
  }

  /// Provider sosial yang dikenali, dipakai saat memindai key di `meta`.
  static const List<String> _socialProviders = [
    'linkedin',
    'instagram',
    'facebook',
    'twitter',
    'x',
    'youtube',
    'github',
    'tiktok',
    'website',
  ];

  /// Ambil tautan sosial dari `meta`.
  ///
  /// Respons `/members` yang sebenarnya TIDAK punya key `social_links`
  /// (isinya `website`, `cover_photo`, `headline`, `badge_slug`, ...), jadi
  /// tiap provider kemungkinan disimpan sebagai key tersendiri di `meta`.
  /// Karena itu di sini dicoba dua-duanya: `social_links` kalau ada, dan
  /// pemindaian langsung key `meta` untuk nama provider yang dikenal.
  static Map<String, String> _parseSocialLinks(dynamic meta) {
    if (meta is! Map) return const {};
    final result = <String, String>{};

    // Bentuk 1: terkumpul di `social_links` (Map atau List).
    final raw = meta['social_links'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          result['$key'] = value.trim();
        }
      });
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final provider = item['provider'] ?? item['name'] ?? item['type'];
          final url = item['url'] ?? item['link'];
          if (provider is String && url is String && url.trim().isNotEmpty) {
            result[provider] = url.trim();
          }
        }
      }
    }

    // Bentuk 2: tiap provider jadi key tersendiri di `meta`.
    for (final provider in _socialProviders) {
      if (result.containsKey(provider)) continue;
      final value = meta[provider];
      if (value is String && value.trim().isNotEmpty) {
        result[provider] = value.trim();
      }
    }

    return result;
  }
}

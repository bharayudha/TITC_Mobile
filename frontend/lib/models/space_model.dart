import 'package:magang_titc/models/json_utils.dart';

/// Model untuk satu entitas Space (Grup) dari Fluent Community.
class SpaceModel {
  final int id;
  final String slug;
  final String title;
  final String description;
  final String logoUrl;
  final String coverPhotoUrl;
  final int membersCount;
  final bool isJoined;
  final String privacy;

  /// Emoji dari `settings.emoji`. Dipakai sebagai penanda visual saat space
  /// tidak punya logo/cover sama sekali, meniru tampilan di web.
  final String emoji;

  SpaceModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.logoUrl,
    required this.coverPhotoUrl,
    this.membersCount = 0,
    this.isJoined = false,
    this.privacy = 'public',
    this.emoji = '',
  });

  /// Ambil nilai String pertama yang benar-benar berisi.
  ///
  /// Operator `??` saja tidak cukup: API mengirim `""` (string kosong), bukan
  /// `null`, untuk gambar yang belum diisi — sehingga fallback tidak pernah
  /// jalan dan kartu space tampil tanpa gambar padahal ada sumber lain.
  static String _firstNonEmpty(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Factory untuk membuat object dari JSON response Fluent Community API.
  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    final settings = asJsonMap(json['settings']);

    return SpaceModel(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      logoUrl: _firstNonEmpty([json['logo'], json['avatar']]),
      // `settings.og_image` sering terisi walau `cover_photo` kosong, jadi
      // dipakai sebagai cadangan terakhir sebelum menyerah ke placeholder.
      coverPhotoUrl: _firstNonEmpty([
        json['cover_photo'],
        json['cover'],
        settings['og_image'],
      ]),
      membersCount: json['members_count'] ?? json['member_count'] ?? 0,
      // `/spaces/discover` TIDAK mengirim `is_joined`/`is_member`. Yang ada
      // `space_pivot`, yaitu baris relasi user↔space: terisi kalau user
      // anggota, kosong/null kalau bukan. Tanpa cek ini semua space dianggap
      // belum di-join, sehingga space yang sudah diikuti pun menampilkan
      // tombol "Join".
      //
      // Dua field lama tetap dicoba lebih dulu supaya respons endpoint lain
      // yang memang mengirimnya tetap terbaca.
      isJoined: json['is_joined'] ??
          json['is_member'] ??
          asJsonMap(json['space_pivot']).isNotEmpty,
      privacy: json['privacy'] ?? 'public',
      emoji: _firstNonEmpty([settings['emoji']]),
    );
  }
}

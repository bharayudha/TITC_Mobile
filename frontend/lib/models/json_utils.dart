/// Pembantu parsing JSON dari WordPress / Fluent Community.
///
/// Alasannya satu: **PHP menyerialkan array asosiatif KOSONG sebagai `[]`**
/// (array JSON), bukan `{}`. Jadi field objek seperti `meta`, `xprofile`,
/// `settings`, `info`, atau `route` datang sebagai objek saat berisi tapi
/// sebagai ARRAY saat kosong.
///
/// Cast langsung `as Map` hanya menerima bentuk pertama dan melempar
/// `type 'List&lt;dynamic&gt;' is not a subtype of type
/// 'Map&lt;String, dynamic&gt;?'` untuk bentuk kedua. Karena parsing dijalankan di
/// dalam `.map()` atas seluruh daftar, SATU item bermasalah menjatuhkan
/// seluruh layar — bukan cuma dirinya sendiri. Itu yang bikin Feed pernah
/// tampil sebagai pesan error merah gara-gara satu post punya `meta` kosong.
library;

/// Objek bersarang yang aman: mengembalikan map kosong untuk `null`, `[]`,
/// atau nilai bertipe lain.
Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  // Map bertipe longgar (mis. hasil decode bersarang di sebagian versi Dart)
  // tetap diterima daripada dibuang.
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

/// Array bersarang yang aman: mengembalikan list kosong untuk `null`, `{}`,
/// atau nilai bertipe lain.
List<dynamic> asJsonList(dynamic value) => value is List ? value : const [];

/// String yang aman: hanya mengembalikan nilai kalau memang String dan tidak
/// kosong. Dipakai untuk rantai fallback seperti judul/avatar yang boleh
/// diambil dari beberapa key.
String? asJsonString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

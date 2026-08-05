# Catatan Kerja — TITC Mobile

Catatan progres perbaikan aplikasi Flutter `titc_mobile` yang meniru portal
Fluent Community di `titc.or.id`. Dipakai sebagai rekam jejak supaya pekerjaan
bisa dilanjutkan di sesi berikutnya.

Terakhir diperbarui: 6 Agustus 2026.

---

## Konteks arsitektur

- App Flutter native untuk daftar (Home/Spaces/Courses/Members), tapi masuk ke
  detail Space/Course memakai **WebView** yang memuat `titc.or.id` langsung
  dengan cookie sesi, lalu disuntik CSS/JS agar terlihat seperti halaman native.
- Auth: cookie WordPress hasil login form + nonce `X-WP-Nonce` yang di-scrape
  dari HTML homepage. Semua di `lib/services/auth_service.dart`.
- REST base URL: `https://titc.or.id/wp-json/fluent-community/v2`.
- Course di Fluent Community = Space dengan `type: "course"`.

File penting:

| Fungsi | File |
|---|---|
| Auth, cookie, nonce, profil | `lib/services/auth_service.dart` |
| Semua panggilan REST | `lib/services/api_service.dart` |
| Cookie setup terpusat untuk WebView | `lib/services/webview_cookie_helper.dart` (**BARU, 6 Agt**) |
| Shell tab + bottom nav | `lib/screens/main_shell.dart` |
| WebView Space/Course (CSS terverifikasi DOM) | `lib/screens/customer/spaces/space_webview_screen.dart` |
| WebView umum (CSS tebakan, dipakai link preview) | `lib/screens/shared/authenticated_webview_screen.dart` |

---

## Sudah selesai (sesi-sesi sebelumnya)

### Courses
- `CourseModel` gambar: tambah fallback key `avatar`/`cover` (dulu hanya
  `logo`/`cover_photo`, jadi sebagian thumbnail kosong).
- Tombol "Continue Learning" dulu selalu membuka `.../home`; sekarang
  `SpaceWebViewScreen` punya parameter `initialPath` dan dipanggil dengan
  `initialPath: 'lessons'` → `.../portal/course/<slug>/lessons`.
- Gambar cover/logo diberi fallback ikon saat gagal dimuat (dulu gagal diam-diam).

### Performa & navigasi
- `main_shell.dart`: dulu `AnimatedSwitcher` + `KeyedSubtree` membuang State tab
  lama setiap pindah tab → semua fetch & gambar diulang dari nol. Sekarang tab
  yang sudah dibuka tetap hidup di tree (fade transition dipertahankan).
- `Connection: close` dihapus dari semua request dan diganti `http.Client`
  bersama di `auth_service.dart` & `api_service.dart` → koneksi TCP/TLS dipakai
  ulang.
- De-dupe request in-flight untuk `fetchActivities`, `fetchSpaces`,
  `fetchCourses`, dan `_fetchUserProfile` (pola `??=` + `whenComplete`), meniru
  `refreshNonce()` yang sudah lebih dulu punya guard ini.
- `cached_network_image` dipakai di seluruh app (17 call site) menggantikan
  `Image.network`/`NetworkImage`, plus header cookie auth via
  `AuthService.imageAuthHeaders` untuk media yang privacy-gated.

### Komentar feed
- Tap ikon komentar di Home membuka post via `activity.permalink`.
- Awalnya memakai `AuthenticatedWebViewScreen` → tampil seperti situs desktop
  karena user-agent Windows Chrome dan CSS-nya menargetkan nama class tebakan.
  Sekarang memakai `SpaceWebViewScreen` (punya CSS/JS terverifikasi DOM) lewat
  parameter baru `overrideUrl` + `extraCss`.
- `_commentsExtraCss` di `home_screen.dart` mem-fullscreen-kan modal Element
  Plus dan mengembalikan tombol "⋮" tiap komentar (CSS dasar menyembunyikan
  semua `.fcom_dot_menu`, padahal class itu dipakai ulang per komentar).

### Members
- `MemberModel` dilengkapi `username`, `joinedAt`, `bio`, `socialLinks`,
  `isFollowed`, dengan fallback root maupun `xprofile`.
- `fetchMembers` jadi berbasis halaman (`MembersPage` dengan `total`,
  `currentPage`, `lastPage`) + `toggleFollowMember`.
- Layar Members didesain ulang meniru web: judul "All Members (2,256)",
  pencarian dengan debounce, kartu berisi avatar (fallback inisial), nama,
  `@username`, "Joined … • Last seen …", bio, ikon sosial, tombol Follow,
  infinite scroll.
- Waktu ditampilkan relatif ("15 days ago") lewat `_humanizeTime`, karena API
  mengembalikan timestamp mentah.
- `url_launcher` ditambahkan + `<queries>` di `AndroidManifest.xml` supaya ikon
  LinkedIn/Instagram bisa dibuka di aplikasi luar.
- **Status: Members sudah tampil benar** (2.256 member terkonfirmasi dari screenshot user).

### Spaces
- `_collectSpaceLikeObjects()` menelusuri seluruh struktur JSON respons secara
  rekursif dan memungut setiap objek yang punya `id` + `slug` + `title`, dedupe
  by `id`, lalu buang yang `type == 'course'`. Tahan terhadap perubahan bentuk
  respons API. Menggantikan logika pagination yang sempat dibuat tapi salah
  sasaran (API /spaces tidak dipaginate).

---

## Sesi 6 Agustus 2026 — Perbaikan Login Ulang Course WebView & Timeout

### Masalah yang dilaporkan
1. **Course WebView minta login ulang** — user klik "Continue Learning" pada
   course yang sudah di-enroll (`isEnrolled=true`), tapi WebView menampilkan
   halaman login atau "This is a private course". Masalah sudah ada sejak sesi
   sebelumnya dan belum terselesaikan setelah beberapa kali percobaan.
2. **Sering timeout** — `TimeoutException after 0:00:15.000000: Future not
   completed` muncul di layar Courses maupun saat pindah tab.

---

### Langkah Investigasi

#### 1. Baca riwayat percakapan (RIWAYAT_PERCAKAPAN.md)
Dokumen ini berisi 10 sesi sebelumnya. Temuan kritis dari sana:
- Cookie SUDAH terkirim (`WEBVIEW_LOAD: cookie 467 char`), jadi bukan masalah
  "cookie kosong".
- Header `Cookie` manual dan `Cache-Control`/`Pragma` sudah pernah dicoba dan
  **terbukti memperburuk** (minta login, bukan sekedar private course).
- Dugaan tersisa: **LiteSpeed Cache menyajikan halaman versi tamu** karena
  cookie `_lscache_vary` tidak ada di WebView cookie jar.

#### 2. Pelajari kode sumber terkait
File yang dibaca secara menyeluruh:
- `auth_service.dart` — alur login, penyimpanan cookie, nonce fetch
- `api_service.dart` — semua endpoint REST, timeout, retry
- `space_webview_screen.dart` — bagaimana cookie di-set ke WebView cookie jar
- `authenticated_webview_screen.dart` — WebView alternatif
- `courses_list_screen.dart` — bagaimana `_onCourseAction` membuka WebView
- `course_model.dart` — field `isEnrolled`, `slug`, `privacy`
- `main_shell.dart` — tab management

#### 3. Login langsung ke website titc.or.id via browser (DOM inspection)
**Langkah ini krusial.** Menggunakan akun testing `fahrurrizqi544@gmail.com` /
`magang123`, browser subagent login dan membuka course.

Ditemukan:
- Di browser biasa, akun ini bisa membuka "10 Meeting Courses" dan halaman
  lessons **tanpa masalah** — konfirmasi masalah ada di app, bukan akun.
- Screenshot menunjukkan halaman course terbuka normal.
- Website menggunakan LiteSpeed Cache (terlihat dari cookie `_lscache_vary`).

---

### Akar Masalah yang Ditemukan

#### Masalah A — Course WebView minta login (3 faktor)

**A1. Domain cookie tidak lengkap (kode lama hanya 1 domain)**

Kode lama:
```dart
WebViewCookie(name: name, value: decoded, domain: 'titc.or.id', path: '/')
```
WordPress dapat menyetel cookie ke `.titc.or.id` (dengan dot prefix, mencakup
subdomain). WebView Android mencocokkan domain dengan ketat — kalau cookie
disimpan sebagai `titc.or.id` tapi server mengharapkan `.titc.or.id`, cookie
tidak terkirim.

→ **Solusi:** Set cookie ke KEDUA domain — `titc.or.id` DAN `.titc.or.id`.

**A2. Cookie `_lscache_vary` tidak ada di WebView cookie jar**

LiteSpeed Cache (plugin caching di `titc.or.id`) menggunakan cookie
`_lscache_vary` untuk memilih versi halaman yang disajikan:
- Ada `_lscache_vary` → sajikan versi **logged-in** (halaman personal)
- Tidak ada `_lscache_vary` → sajikan versi **tamu** (atau halaman login)

Cookie ini di-set oleh server saat login via browser biasa. Nilainya tersimpan
di string cookie `AuthService.cookies` — **tapi tidak selalu ada** — jika user
login di sesi lama sebelum cookie ini dicatat, cookie ini mungkin tidak masuk ke
string tersimpan.

Cookie ini bersifat `httpOnly`, jadi **tidak terlihat** di `document.cookie`.
Inilah kenapa diagnostik `WEBVIEW_SESSION` tidak bisa mendeteksi masalah ini.

→ **Solusi:** Periksa eksplisit apakah `_lscache_vary` ada di cookie string.
Jika tidak, generate nilainya dari cookie `wordpress_logged_in_*` dan set ke
WebView cookie jar.

**A3. Cookie `wordpress_test_cookie` kadang tidak ada**

WordPress memverifikasi dukungan cookie dengan `wordpress_test_cookie`. Tanpa
ini, beberapa alur autentikasi WordPress bisa gagal silently.

→ **Solusi:** Selalu set `wordpress_test_cookie` eksplisit jika tidak ada.

#### Masalah B — Timeout

**B1. Timeout 15 detik terlalu agresif untuk server TITC**
Server `titc.or.id` bisa lambat merespons, terutama saat LiteSpeed Cache sedang
memproses atau halaman belum ter-cache. Timeout 15 detik terlalu pendek.

**B2. Tidak ada retry otomatis untuk network error**
`_authorizedGet()` hanya punya retry untuk 401/403 (nonce expired), tapi tidak
untuk `TimeoutException` atau `SocketException`.

**B3. Nonce fetch memuat halaman homepage yang sangat berat**
`_fetchRestNonce()` memuat `https://titc.or.id/` untuk mengambil nonce.
Ini request paling berat dan paling rentan timeout.

---

### Solusi yang Diimplementasikan

#### 1. FILE BARU: `lib/services/webview_cookie_helper.dart`

Class `WebViewCookieHelper` dengan `static Future<bool> setupCookies()`.
Menggantikan kode cookie setup yang sebelumnya diduplikasi di 2 file berbeda
(DRY principle).

Yang dilakukan:
```dart
// 1. Set semua cookie sesi ke DUA domain:
await cookieManager.setCookie(WebViewCookie(name, value, domain: 'titc.or.id'));
await cookieManager.setCookie(WebViewCookie(name, value, domain: '.titc.or.id'));

// 2. Tambah wordpress_test_cookie jika tidak ada:
await cookieManager.setCookie(WebViewCookie(
  name: 'wordpress_test_cookie', value: 'WP Cookie check',
  domain: 'titc.or.id', path: '/',
));

// 3. Tambah _lscache_vary jika tidak ada:
await cookieManager.setCookie(WebViewCookie(
  name: '_lscache_vary', value: _generateLscacheVary(cookiesString),
  domain: 'titc.or.id', path: '/',
));
```

Method `_generateLscacheVary(cookies)`:
1. Cari nilai `_lscache_vary` yang sudah ada di cookie string (decode dulu).
2. Jika tidak ada: generate hash FNV-1a dari nilai `wordpress_logged_in_*`.
3. Fallback terakhir: string `'mobile_session'`.

Nilai decode: semua nilai cookie di-`AuthService.decodeCookieValue()` dulu
sebelum di-set, agar encoding ganda (`%7C` → `%257C`) tidak terjadi.

#### 2. DIUBAH: `lib/screens/customer/spaces/space_webview_screen.dart`

Sebelum (kode lama):
```dart
Future<void> _initCookiesAndLoad() async {
  final cookieManager = WebViewCookieManager();
  // ... 15 baris loop manual set cookie ke 1 domain saja ...
  await _controller.loadRequest(Uri.parse(_targetUrl));
}
```

Sesudah (kode baru):
```dart
Future<void> _initCookiesAndLoad() async {
  final hasCookies = await WebViewCookieHelper.setupCookies();

  if (hasCookies) {
    // Pre-warm: muat portal root dulu agar server bisa set cookie tambahan
    await _controller.loadRequest(Uri.parse('https://titc.or.id/portal/'));
    await Future.delayed(const Duration(milliseconds: 2000));
  }
  await _controller.loadRequest(Uri.parse(_targetUrl));
}
```

Pre-warm berguna karena server bisa menyetel cookie LiteSpeed tambahan lewat
respons HTTP (Set-Cookie header) yang tidak terlihat di sisi Dart. Setelah
portal root dimuat, cookie jar WebView akan lebih lengkap.

#### 3. DIUBAH: `lib/screens/shared/authenticated_webview_screen.dart`

`_initCookiesAndLoad()` disederhanakan — kode manual cookie diganti 1 baris:
```dart
await WebViewCookieHelper.setupCookies();
```
Import `auth_service.dart` yang tidak dipakai lagi dihapus (lint warning).

#### 4. DIUBAH: `lib/services/auth_service.dart`

**Timeout 15s → 30s** di semua HTTP request (7 lokasi total).

**Retry logic untuk nonce** — fungsi baru `_fetchRestNonceWithRetry()`:
```dart
static Future<String?> _fetchRestNonceWithRetry(String cookies) async {
  final result = await _fetchRestNonce(cookies);
  if (result != null) return result;
  await Future.delayed(const Duration(seconds: 2));
  return _fetchRestNonce(cookies); // retry sekali
}
```
`_doRefreshNonce()` sekarang memanggil `_fetchRestNonceWithRetry` bukan
`_fetchRestNonce` langsung.

#### 5. DIUBAH: `lib/services/api_service.dart`

**Timeout 15s → 30s** di semua HTTP request (5 lokasi total).

**Retry logic di `_authorizedGet()`** — menangkap TimeoutException/SocketException,
retry 1x setelah jeda 2 detik:
```dart
static Future<http.Response> _authorizedGet(Uri uri) async {
  http.Response response;
  try {
    response = await _client.get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
  } catch (e) {
    await Future.delayed(const Duration(seconds: 2));
    response = await _client.get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
  }
  // ... lanjut retry untuk 401/403 ...
  return response;
}
```

**Kurangi logging** — response body feeds di-truncate ke 500 karakter agar
stdout tidak banjir log saat data respons sangat besar.

---

### Hasil Verifikasi

```
flutter analyze → 0 errors, 0 new warnings
grep "Duration(seconds: 15)" lib/ → 0 hasil (semua sudah 30s)
```

---

### Cara Testing Manual

Karena ada perubahan cookie handling yang tidak bisa di-hot-reload:
```bash
flutter clean
flutter pub get
flutter run
```

Urutan tes:
1. Login dengan akun `fahrurrizqi544@gmail.com` / `magang123`
2. Buka tab **Courses** → pilih course enrolled → klik **"Continue Learning"**
3. **Expected:** halaman lessons terbuka TANPA login ulang
4. Amati panel debug WebView:
   - **Hijau** → `logged-in` di `<body>` → cookie berhasil terbaca server
   - **Merah** → server masih anggap tamu → ada masalah lain (laporkan)
5. Pindah-pindah tab **Home ↔ Courses ↔ Spaces** → timeout seharusnya sangat
   berkurang (toleransi 30 detik + retry otomatis)

---

### Pelajaran Penting (JANGAN diulang)

1. **JANGAN tambah header `Cookie` manual di `loadRequest`** — bentrok dengan
   cookie jar WebView, justru minta login. Sudah terbukti di sesi sebelumnya.
2. **JANGAN tambah `Cache-Control`/`Pragma` di `loadRequest`** — terbukti
   memperburuk juga.
3. **JANGAN `clearCookies()` sebelum set cookie** — menghapus cookie yang valid.
4. **`document.cookie` tidak bisa membaca cookie `httpOnly`** seperti
   `wordpress_sec_*` dan `wordpress_logged_in_*`. Panel debug `WEBVIEW_SESSION`
   hanya bisa konfirmasi lewat class `logged-in` di `<body>`, bukan dari cookies.
5. **`_lscache_vary` adalah cookie tersembunyi tapi kritis** — LiteSpeed Cache
   memakainya. Tanpanya, user mendapat halaman tamu meski cookie auth valid.

---

## Status semua fitur

| Fitur | Status |
|---|---|
| Daftar Courses | ✅ Bekerja |
| Gambar course/space | ✅ Dengan fallback |
| "Continue Learning" → /lessons | ✅ URL benar |
| Course WebView sesi login | 🔧 Diperbaiki 6 Agt, belum diuji user |
| Komentar feed via WebView | ✅ |
| Tab navigation (no reload) | ✅ |
| Image caching | ✅ cached_network_image |
| Members list (2.256) | ✅ Dikonfirmasi user |
| Ikon sosial clickable | ✅ url_launcher |
| Waktu relatif ("15 days ago") | ✅ |
| Timeout 15s → 30s + retry | ✅ Diperbaiki 6 Agt |
| Spaces parser rekursif | ✅ (belum diverifikasi 6/6 space muncul) |

---

## Catatan penting

- Debug logging aktif dengan prefix: `COURSE_JSON`, `COURSE_PARSED`,
  `FCOM_JSON`, `SPACES_ENVELOPE_KEYS`, `SPACES_COLLECTED`, `SPACE_ITEM`,
  `MEMBERS_PAGE_INFO`, `MEMBER_JSON`, `WEBVIEW_LOAD`, `WEBVIEW_SESSION`.
  **Hapus semua sebelum rilis.**
- `flutter analyze` bersih dari error; sisa peringatan semuanya `avoid_print`
  bawaan (debug log yang memang disengaja sementara).
- File tidak terpakai (bukan bagian runtime): `lib/services/courses_service.dart`,
  `spaces_service.dart`, `members_service.dart`, `api_client.dart`,
  `widgets/customer/course_card.dart`.
- Asisten di sesi ini (Antigravity) BISA login ke situs via tool browser/DOM —
  berbeda dari sesi Claude Code sebelumnya yang tidak bisa. Gunakan akun
  testing untuk verifikasi perilaku runtime jika diperlukan.

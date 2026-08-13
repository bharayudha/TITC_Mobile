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
| Buka Space/Course dari judul (drawer & Home) | `lib/services/portal_navigator.dart` (**BARU, 7 Agt**) |
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

### Profil (commit `58726eb`)
- Ikon profil di app bar (`widgets/shared/profile_menu.dart`) dulu selalu
  `PhosphorIconsRegular.userCircle` generik; sekarang menampilkan foto profil
  user seperti tampilan web, lewat widget `_ProfileAvatarIcon`.
- Fallback bertingkat: inisial nama selama foto dimuat → balik ke ikon lama
  kalau user belum punya foto atau URL-nya gagal diambil. Pemuatannya ikut
  mengirim `AuthService.imageAuthHeaders` sama seperti call site gambar lain,
  karena avatar termasuk media yang bisa privacy-gated.
- `_userAvatarUrl` di `auth_service.dart` diubah jadi getter/setter di atas
  `ValueNotifier avatarUrlNotifier`. Alasannya: app bar hidup di luar
  `ProfileScreen`, jadi `setState` di layar profil tidak menjangkaunya —
  padahal avatar harus langsung berganti begitu upload selesai
  (`ApiService.uploadAvatar` → `AuthService.init()`), tanpa buka ulang halaman.
  Semua kode lama tetap baca/tulis lewat nama yang sama, jadi tidak ada call
  site yang perlu disesuaikan.

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

## Sesi 6 Agustus 2026 (lanjutan) — Menu Drawer Tersambung & Perombakan Navbar WebView

### Selesai

**Semua item drawer (☰) kini bisa diklik** (`widgets/customer/side_drawer.dart`).
Sebelumnya seluruh item `onTap: () {}` kosong.

- MEMBERSHIP AREAS (6 item) → `SpaceWebViewScreen`.
- TOEFL Preparation & English for Specific Purposes → course, mengikuti alur
  `_onCourseAction` di `courses_list_screen.dart`: sudah enroll → langsung
  `portalSegment: 'course'` + `initialPath: 'lessons'`; belum enroll → coba
  `enrollCourse()` dan teruskan pesan penolakan dari server apa adanya.
- Ditambahkan **10, 15, 20 Meeting Courses** yang ada di web tapi belum ada di app.
- **Slug tidak di-hardcode.** Label drawer dicocokkan dengan judul dari
  `fetchSpaces()`/`fetchCourses()`, lalu slug asli dari API yang dipakai — supaya
  menu tetap benar kalau admin mengubah slug di WordPress. Helper generik
  `_findByTitle<T>` (SpaceModel & CourseModel tidak punya supertype bersama).
- Pencocokan sebagian hanya dipakai kalau hasilnya **tunggal**. Ada lima course
  bernama nyaris sama ("3/7/10/15/20 Meeting Courses"); membuka yang salah lebih
  membingungkan daripada jujur bilang tidak ketemu.

**Navbar `SpaceWebViewScreen` diganti `TitcAppBar`** (sama persis dengan Home,
sesuai permintaan user agar mirip web: ☰ + "TITC Indonesia" + search + lonceng
+ foto profil).

- `drawer: const SideDrawer()` WAJIB ikut ditambahkan — hamburger di `TitcAppBar`
  memanggil `Scaffold.of(context).openDrawer()` yang diam saja tanpa itu.
- Tombol ⋮ Flutter **dilepas**, `.fcom_dot_menu` milik web dimunculkan kembali
  (`opacity: 1`). Jembatan ⋮ buatan tim itu ada *karena* header web dulu
  di-collapse ke 0px; setelah header ditampilkan normal, tombol aslinya punya
  tempat dan masalah koordinat dropdown di PRD §11.2 hilang sendiri.
  **Belum diverifikasi user** — kalau ⋮ ternyata tidak muncul/tidak jalan,
  jembatan lama ada di riwayat git.
- Konsekuensi: **tidak ada tombol back** di app bar. Sebagai gantinya, teks
  "TITC Indonesia" diketuk = pulang ke Home.

**Judul navbar sebagai tombol pulang** (`widgets/shared/top_app_bar.dart`).

- Pakai `popUntil((route) => route.isFirst)`, **bukan** `maybePop()`. Berpindah
  antar space/course lewat drawer menumpuk banyak halaman, jadi mundur selangkah
  malah mendarat di space yang tadi dibuka. `MainShell` dijamin route pertama:
  lewat `home:` di `app.dart` saat sesi hidup, lewat `pushReplacement` setelah login.
- Hanya aktif kalau `Navigator.canPop()` true. `TitcAppBar` dipakai bersama oleh
  Home/Messages/Profil; di Home tidak ada yang bisa ditutup, dan memberi efek
  sentuh pada sesuatu yang tidak berbuat apa-apa itu menyesatkan.

**Menu profil tersambung** (`widgets/shared/profile_menu.dart`). Dulu hanya
"Lihat Profil" dan "Log Out" yang berfungsi.

- **My Courses** → tab Courses, **My Spaces** → tab Spaces, sekaligus menutup
  halaman yang menumpuk di atas shell.
- **Certificate** → `https://titc.or.id/certificate-verification/` lewat
  `AuthenticatedWebViewScreen` (WebView umum), **bukan** `SpaceWebViewScreen`:
  itu halaman WordPress biasa, bukan portal FCOM, jadi CSS shell Vue tidak
  relevan di sana.
- Pindah tab dari luar shell dilakukan lewat `MainShell.openTab()` yang
  menulis ke `MainShell.requestedTab` (`ValueNotifier<int?>`), lalu
  `_MainShellState` mendengarkannya. **JANGAN diganti dengan
  `pushAndRemoveUntil(MainShell(initialIndex: ...))`** — itu membuat shell
  BARU sehingga semua tab yang sudah terbuka dibuang dan di-fetch ulang dari
  nol, persis masalah yang dihindari mekanisme `_openedTabs`.
- Nilainya dikosongkan segera setelah dibaca. Tanpa itu, memilih menu yang
  sama dua kali berturut-turut tidak bereaksi di kali kedua, karena
  `ValueNotifier` diam kalau nilainya tidak berubah.
- Indeks tab diberi nama (`MainShell.tabHome/tabSpaces/tabCourses/tabMembers`)
  supaya tidak ada angka telanjang yang diam-diam salah kalau urutan tab
  digeser.

**Home disamakan dengan web** (`screens/customer/home/home_screen.dart`).

- Ditambahkan deretan **link cepat** di bawah header Feed, digulir mendatar,
  meniru Home web: Daftar Tes TOEFL ITP Resmi ETS, Daftar Preparation Test
  Online, Check Readiness, Certificate Tracking, EPT Certificate Verification,
  FREE Placement Test.
- **Baris ikon shortcut di paling atas dihapus** (TOEFL ITP / Prep Test /
  Readiness / Tracking / Placement). Isinya duplikat lima dari enam link cepat
  di atas, dan di web memang hanya ada satu deret. Method
  `_buildShortcutItem` ikut dihapus supaya tidak jadi kode mati.
- Lima link membuka `AuthenticatedWebViewScreen`; FREE Placement Test adalah
  Space portal sehingga slug-nya dicari lewat judul.

> [!IMPORTANT]
> **URL link cepat mudah salah — jangan "dibetulkan" tanpa cek.**
> - Dua link pendaftaran memakai landing page Fluent Forms:
>   `https://titc.or.id/?ff_landing=21` (Daftar Tes TOEFL ITP Resmi ETS) dan
>   `https://titc.or.id/?ff_landing=15` (Daftar Preparation Test Online).
>   Keduanya dikonfirmasi langsung oleh user dan sudah diverifikasi memuat
>   "Form Pendaftaran" yang benar.
>   **Halaman publik `titc.or.id/toefl-itp` BUKAN tujuan yang benar** —
>   itu link dari homepage publik, sedangkan chip di portal member mengarah
>   ke landing form. Sempat salah dipakai karena diambil dari homepage.
>   URL `?ff_landing=<angka>` memang buram, tapi itu yang benar.
> - Certificate Tracking → `/certificate-distribution/`.
>   `/certificate-tracking/` **404**, jangan dipakai.

**Helper baru: `services/portal_navigator.dart`.**
Logika "buka Space/Course berdasarkan judul" tadinya method privat di
`side_drawer.dart`. Karena Home juga membutuhkannya, diangkat jadi helper
bersama alih-alih disalin (langkah yang sama dengan `WebViewCookieHelper`).
Menerima `NavigatorState` & `ScaffoldMessengerState`, **bukan** `BuildContext`,
karena drawer harus menutup dirinya lebih dulu dan setelah itu context-nya
sudah tidak mounted.

### BELUM SELESAI — baris breadcrumb + "Continue Course" masih meleset

Header web (`.fhr_content_layout_header`, isinya breadcrumb + tombol
"Continue Course") dulu di-collapse ke `height: 0`. User minta header itu
**ditampilkan** seperti di web, rapi di bawah navbar, tidak tumpang tindih.
Sampai akhir sesi **masih belum benar**.

Kunci pemahaman: `height: 0` + `overflow: visible` membuat isi header tetap
tergambar tanpa menempati ruang → menimpa konten di bawahnya. Itu penyebab
tumpang tindih yang awalnya dilaporkan.

**Data probe DOM (dari perangkat user, header masih di-collapse saat itu):**

```
HEADER  DIV.fhr_content_layout_header [pos=relative top=56 h=52]
SEBELUM tidak ada
SESUDAH DIV.fhr_content_layout_body   [pos=static  top=52 h=1306]
ANAK[0] DIV.el-breadcrumb             [pos=static  top=75 h=14]
ANAK[1] DIV.fhr_page_actions          [pos=static  top=66 h=32]
```

Dua fakta penting dari angka itu:
1. Header anak pertama (`SEBELUM: tidak ada`) tapi mulai di `top=56` → ada 56px
   jarak yang disumbang induk-induknya. 56px ≈ tinggi `.fcom_top_menu` yang
   kita `display: none`; besar dugaan `padding-top` untuk menu `position: fixed`
   itu tertinggal.
2. Body mulai di `top=52`, padahal header menempati 56–108 → keduanya bertumpuk.

**Sudah dicoba, belum menuntaskan** (jangan diulang tanpa data baru):
- `overflow: hidden` pada header → menghilangkan tumpang tindih tapi ikut
  menyembunyikan breadcrumb & tombol; user menolak, mau keduanya tetap tampil.
- `.fhr_content_layout_header > *:not(.fcom_dot_menu) { position: static }` →
  **berhasil** untuk isi header (probe membuktikan anak-anaknya jadi `static`
  dan rapi di dalam kotak). Pertahankan.
- `.fhr_content_layout_body { margin-top: 0; position: static }` → menyasar
  hipotesis margin negatif; belum terbukti benar/salah.
- Induk header dipaksa `display: block` → menyasar hipotesis induk `grid`
  yang menumpuk header & body di sel sama; belum terbukti.
- Sapu `padding-top`/`margin-top` = 0 ke **seluruh rantai induk** header sampai
  `<body>` → menyasar pita kosong 56px; belum terbukti.

**Langkah berikutnya:** jalankan app, buka course, ambil baris `WEBVIEW_DOM:`
yang baru. Probe sekarang sudah melaporkan `INDUK[0..5]` lengkap dengan `top`,
`mt`, `pt`, dan `display` masing-masing. Itu memisahkan dua hipotesis yang
tersisa: kalau ada induk ber-`display: grid` → penyebabnya penumpukan sel;
kalau ada induk dengan `pt`/`mt` bukan 0 → penyebabnya padding sisa.
**Jangan menebak selector lagi — baca angkanya dulu.**

### Alat debug yang ditambahkan (HAPUS SEBELUM RILIS)

| Log | Isi | Lokasi |
|---|---|---|
| `WEBVIEW_DOM:` | Struktur & posisi header + rantai induk, dikirim lewat `JavaScriptChannel('TitcDebug')` | `space_webview_screen.dart` |
| `WEBVIEW_NAV:` | Setiap URL yang dinavigasi di dalam WebView — dipakai untuk melacak tujuan tombol "Continue Course", yang belum sempat diperiksa | `space_webview_screen.dart` |

Keduanya ada karena portal FCOM butuh login sehingga DOM-nya **tidak bisa
diperiksa dari luar** — dicoba `WebFetch` ke `/portal/course/.../lessons`, yang
keluar hanya form login. Jadi app-nya sendiri yang harus melapor.

### Hasil audit — DISERAHKAN KE TIM, belum dikerjakan

Dua fitur diperiksa atas permintaan user dan sengaja **tidak** dikerjakan di
sesi ini. Catatan ini supaya yang mengerjakan tidak perlu menelusuri ulang.

#### Notifikasi — belum tersambung sama sekali

Ada DUA hal berbeda yang sama-sama disebut "notifikasi", keduanya kosong:

**(a) Daftar di ikon lonceng** — `widgets/shared/notifications_popup.dart`
**Status: ✅ SELESAI**.
- **Model**: FCOM menyimpan data pengirim di dalam `xprofile` (bukan `actor`), dan informasi url di dalam objek `route` (nama route vue dan param slug). File `notification_model.dart` sudah diperbaiki untuk membongkar JSON ini.
- **Service & Fetch**: Menggunakan endpoint `/wp-json/fluent-community/v2/notifications`. Karena API FCOM kadang mengabaikan parameter *query* `?type=`, penyaringan (*filtering*) untuk tab *Recent, Unread, Mentions, Following* dilakukan juga secara lokal (sisi klien).
- **Polling Background**: `NotificationsService` memiliki `Timer.periodic` yang berjalan setiap 60 detik selama user *logged in*. Timer ini me- *request* ulang endpoint untuk menghitung jumlah *unread*. Ini memberikan pengalaman *Soft Real-time*: jika user membuka web dan membaca notifikasi, di siklus menit berikutnya badge aplikasi akan otomatis hilang.
- **Navigasi Klik**: Membuka notifikasi sekarang menggunakan `SpaceWebViewScreen(overrideUrl: targetUrl)` alih-alih `AuthenticatedWebViewScreen`. Hal ini menjamin halaman *feed* yang terbuka langsung disuntik CSS/JS penyembunyi *header/footer* FCOM web, sehingga rasanya sangat *native*.
- **Mark As Read**: Klik tunggal notifikasi akan mengubah status `isRead` lokal dan mengurangi angka *badge*. Klik tombol "Mark all as read" akan mengirimkan `POST` ke `/notifications/mark-all-read` (terverifikasi dari inspeksi dokumentasi API FCOM dev) dan mereset UI.

**(b) Push notification (FCM)** — `services/firebase_messaging_service.dart`
**0 baris**, dan `pubspec.yaml` belum punya dependency Firebase apa pun.
Plugin backend `backend/titc-mobile-notification/` masih rangka: kelima file
PHP isinya cuma deklarasi class kosong 5 baris, dan
`titc_mobile_notification_init()` hanya berisi komentar. Kalau diaktifkan di
WordPress sekarang, plugin ini tidak melakukan apa pun.
Komentarnya juga masih menyebut **BuddyBoss**, padahal proyek sudah pindah ke
Fluent Community sejak lama (PRD §3) — tanda file ini belum disentuh sejak
scaffolding awal.
Perlu prasyarat dari perusahaan menurut PRD §8 (`google-services.json`, akses
admin WordPress), statusnya belum diketahui.

#### Search — sebagian saja yang tersambung

**Search di app bar (ikon 🔍) praktis tombol mati.** Overlay-nya benar:
`_close(query)` mengembalikan kata kunci lewat `Navigator.pop(query)`. Tapi di
`top_app_bar.dart` pemanggilnya `onPressed: () => showSearchOverlay(context)` —
`onPressed` bertipe `VoidCallback`, jadi `Future<String?>` yang berisi kata
kuncinya **dibuang**. User mengetik, overlay menutup, tidak terjadi apa-apa.
Tombol cakupan "ALL Post" di sebelahnya juga masih `onTap: () {}`.

| Layar | Cara kerja | Terhubung ke web? |
|---|---|---|
| Members | `fetchMembers(search:)` + debounce 450ms + pagination | ✅ Ya, server yang mencari |
| Spaces | Filter lokal atas data yang sudah dimuat | ❌ Tidak |
| Courses | Filter lokal | ❌ Tidak |
| Messages | Filter lokal atas daftar thread | ❌ Tidak |

**Catatan penting untuk yang mengerjakan:** `ApiService.fetchSpaces()` dan
`fetchCourses()` **sudah mendukung pencarian sisi server** — keduanya menerima
parameter `search` dan mengirimkannya sebagai `?search=`, bahkan sudah sengaja
tidak men-cache hasil pencarian supaya tidak mengotori cache daftar penuh.
Layar Spaces & Courses tinggal memakainya, tidak perlu bikin dari nol.

---

## Sesi 13 Agustus 2026 — Search tersambung & daftar Spaces diperbaiki

### Perilaku API yang tidak terduga (BACA SEBELUM MENGUBAH `api_service.dart`)

Empat hal berikut **tidak bisa disimpulkan dari membaca kode** — ketahuannya
hanya setelah membandingkan respons server dengan tampilan web. Kronologi
lengkapnya ada di RIWAYAT_PERCAKAPAN.md.

**1. `/spaces` hanya mengembalikan space yang SUDAH di-join user.**
Bukan daftar lengkap. Ini penyebab "TOEFL - Mockup Test" muncul di web tapi
hilang di app — satu-satunya space yang belum di-join.
→ Untuk daftar lengkap pakai **`/spaces/discover?type=all&sort_by=alphabetical`**.
Endpoint inilah yang dipakai portal web (dikonfirmasi lewat cURL DevTools user).

> [!IMPORTANT]
> Jangan cari penyebab space hilang di parser. Sempat diduga filter
> `type == 'course'` yang membuangnya — **salah**, dibantah log sendiri
> (`total=6 nonCourse=6`, tidak ada yang terbuang). Masalahnya di endpoint,
> bukan di parsing.

**2. `/spaces/discover` TIDAK mengirim `is_joined` maupun `is_member`.**
Penanda keanggotaan ada di **`space_pivot`** — baris relasi user↔space: terisi
kalau anggota, kosong/null kalau bukan. Tanpa cek ini semua space dianggap
belum di-join, jadi space yang sudah diikuti pun menampilkan tombol "Join".
Lihat `space_model.dart`.

> **Petunjuk untuk tim backend:** di dalam `space_pivot` ada field `role`
> (`member`, dst). Ini kemungkinan besar sumber yang dicari untuk membedakan
> admin/moderator **komunitas FCOM** — role WordPress-nya tetap `subscriber`
> untuk semua akun, jadi penandanya memang bukan di sana.

**3. Endpoint search post FCOM.**
`/feeds?search=<kata>&search_in[0]=post_content&search_in[1]=comments`
plus `feed_base_url=feeds`, `order_by_type=latest`, dan `space=<slug>` (kosong =
semua). Parameter disalin persis dari cURL DevTools user. Nilai `comments`
untuk `search_in[1]` masih **inferensi** — yang tertangkap hanya `post_content`.

**4. PHP menserialisasi array asosiatif KOSONG sebagai `[]`, bukan `{}`.**
Ini jebakan paling sering memakan korban di proyek ini. Akibatnya
`json['x'] as Map<String, dynamic>?` **melempar exception**, bukan menghasilkan
null — dan `json['a'] ?? json['b']` tidak pernah jatuh ke `b` karena `[]` bukan
null. Penyebab crash feed `type 'List<dynamic>' is not a subtype of type
'Map<String, dynamic>?'`.
→ Selalu lewat helper di **`lib/models/json_utils.dart`**
(`asJsonMap` / `asJsonList` / `asJsonString`). Sudah dipakai di 6 model.

> [!WARNING]
> Rantai `x as Map? ?? y as Map?` **tidak menyelamatkan apa pun** — cast kiri
> sudah melempar sebelum `??` sempat dievaluasi.

### Selesai di sesi ini

**Search app bar berfungsi penuh** (dulu tombol mati, query dibuang).
- `top_app_bar.dart`: `onPressed` di-`async` + `await` hasil overlay, lalu push
  `SearchResultsScreen`. Sebelumnya `Future<String?>`-nya dibuang begitu saja.
- `search_overlay.dart` ditulis ulang: mengembalikan `SearchRequest`
  (`query`, `spaceSlug`, `spaceLabel`, `includeComments`), dropdown cakupan
  **"All Posts" + grup "Membership Areas"**, dan baris centang "Search in:"
  (Post Title & Content selalu aktif, Comments opsional) — meniru web.
- File baru `screens/customer/search/search_results_screen.dart` menampilkan
  hasil sebagai kartu post; diketuk → `SpaceWebViewScreen(overrideUrl: permalink)`.
- `ApiService.searchFeeds()` baru. Logika ekstraksi item dipakai bersama feed
  Home lewat `_extractFeedItems()` supaya tidak ada dua parser yang bisa
  berbeda diam-diam.

**Daftar Spaces jadi lengkap.** Satu perubahan endpoint memperbaiki empat hal
sekaligus: toggle All/Joined di tab Spaces (dulu dua-duanya isinya sama),
"TOEFL - Mockup Test" di drawer, isi dropdown search, dan pencarian space
sisi server.

> [!NOTE]
> Grup **"Courses" di dropdown search sengaja DIHAPUS.** Itu tambalan dari
> dugaan yang sudah terbukti salah (lihat blok IMPORTANT di atas) dan membuat
> dropdown berisi 9 entri yang tidak ada di web. Jangan dikembalikan.
> Yang **dipertahankan**: fallback ke daftar course di `portal_navigator.dart` —
> label drawer memang tidak tahu sebuah area itu space atau course, jadi itu
> jaring pengaman yang masuk akal berdiri sendiri.

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
| Foto profil jadi ikon app bar | ✅ Commit `58726eb`, belum diuji user |
| Menu drawer (☰) tersambung | ✅ Space & Course, 6 Agt |
| 10/15/20 Meeting Courses di drawer | ✅ Ditambahkan 6 Agt |
| Navbar WebView = TitcAppBar | ✅ 6 Agt, tombol ⋮ web belum diverifikasi |
| Judul navbar → pulang ke Home | ✅ 6 Agt |
| Menu profil (My Courses/Spaces/Certificate) | ✅ 6 Agt |
| Link cepat di Home (6 item, seperti web) | ✅ 7 Agt |
| Baris ikon shortcut lama di Home | 🗑️ Dihapus 7 Agt, duplikat link cepat |
| Notifikasi in-app (lonceng) | ✅ Selesai (Polling & FCOM parse) |
| Push notification (FCM + plugin PHP) | ⬜ Masih rangka kosong — diserahkan ke tim |
| Search di app bar | ✅ Selesai 13 Agt — cakupan per space + opsi Comments |
| Search Spaces/Courses pakai server | ⬜ Jalur API sudah ada, layar belum memakai |
| Daftar Spaces lengkap (6/6) | ✅ 13 Agt, lewat `/spaces/discover?type=all` |
| Tombol Join/View Space benar | ✅ 13 Agt, lewat `space_pivot` |
| Deteksi admin/moderator FCOM | ⬜ Diserahkan ke tim backend — petunjuk: `space_pivot.role` |
| Header web (breadcrumb + Continue Course) | ❌ **Masih tumpang tindih / meleset** |
| Tujuan tombol "Continue Course" | ❓ Belum diperiksa, pakai log `WEBVIEW_NAV:` |
| Members list (2.256) | ✅ Dikonfirmasi user |
| Ikon sosial clickable | ✅ url_launcher |
| Waktu relatif ("15 days ago") | ✅ |
| Timeout 15s → 30s + retry | ✅ Diperbaiki 6 Agt |
| Spaces parser rekursif | ✅ Masih dipakai — tapi penyebab space hilang ternyata di endpoint, bukan parser (13 Agt) |

---

## Catatan penting

- Debug logging aktif — daftar terverifikasi per 13 Agt (hasil grep, bukan
  ingatan): `SEARCH_FEEDS`, `URL`, `SPACES_ENVELOPE_KEYS`, `SPACES_COLLECTED`,
  `SPACE_ITEM`, `SPACE_KEYS`, `COURSE_JSON`, `COURSE_PARSED`,
  `MEMBERS_PAGE_INFO`, `MEMBER_JSON`, `MEMBER_META_FILLED`,
  `MEMBER_META_ALL_KEYS`, `MEMBER_META_SUMMARY` (`api_service.dart`),
  `URL` (`notifications_service.dart`), `WEBVIEW_DOM`, `WEBVIEW_NAV`,
  `WEBVIEW_LOAD` (`space_webview_screen.dart`).
  **Hapus semua sebelum rilis.** Prefix `URL` sengaja disebut walau generik —
  paling mudah terlewat saat menyapu.
- `flutter analyze` bersih dari error; sisa peringatan semuanya `avoid_print`
  bawaan (debug log yang memang disengaja sementara).
- File tidak terpakai (bukan bagian runtime): `lib/services/courses_service.dart`,
  `spaces_service.dart`, `members_service.dart`, `api_client.dart`,
  `widgets/customer/course_card.dart`.
- Asisten di sesi ini (Antigravity) BISA login ke situs via tool browser/DOM —
  berbeda dari sesi Claude Code sebelumnya yang tidak bisa. Gunakan akun
  testing untuk verifikasi perilaku runtime jika diperlukan.

  > [!WARNING]
  > **Berlaku HANYA untuk Antigravity, jangan dianggap umum.** Sesi Claude Code
  > tidak punya akses browser — portal FCOM butuh login, dan `WebFetch` ke
  > `/portal/...` hanya mengembalikan form login. Karena itu setiap verifikasi
  > perilaku runtime butuh **user yang menjalankan app dan mengirim log**, atau
  > cURL dari DevTools browser user. Beberapa temuan terpenting di dokumen ini
  > (endpoint `discover`, parameter search) datang persis dari cURL semacam itu.

- **Rute dokumen** (disepakati 13 Agt): CLAUDE.md hanya untuk **aturan yang
  masih berlaku** — perilaku API tak terduga, "jangan diulang", status fitur,
  sisa utang. Kronologi investigasi, hipotesis yang gugur, diff kode
  sebelum/sesudah, dan hasil verifikasi bertanggal → **RIWAYAT_PERCAKAPAN.md**.
  Alasannya: CLAUDE.md dibaca ulang otomatis tiap sesi, jadi isi yang basi
  bukan sekadar sampah — ia menyesatkan sesi berikutnya.

### ✅ SELESAI — Perbaikan Feed Home & Double Loading WebView

Rencana di bawah ini (dulu "dibatalkan agar tidak merusak stabilitas") **sudah diterapkan**:

1. **Double Loading WebView (`SpaceWebViewScreen`)** — persis rencana di atas:
   `bool _isPrewarming` di-set `true` sebelum pre-warm portal root, `false`
   sesudahnya; `onPageFinished` skip reveal (`if (_isPrewarming) return;`)
   selama flag itu true. Berlaku untuk SEMUA pemakai `SpaceWebViewScreen`
   (View Space, Admin Settings, dll) karena satu file yang sama.
2. **Feed Home tidak tampil semua** — akar masalah baru: `/feeds` dipanggil
   TANPA parameter halaman sama sekali, jadi hanya batch pertama (±10 item)
   yang pernah termuat, selamanya — bukan soal parsing. Ditambah
   `ApiService.fetchActivitiesPage({page, perPage})` (parameter sama persis
   dengan `searchFeeds`, terverifikasi DevTools) dan infinite scroll di
   `home_screen.dart` (`ScrollController` + `_loadMore` saat mendekati
   bawah). `fetchActivities()` lama sekarang jadi alias page 1.
3. **Like real-time** — `ApiService.toggleFeedLike(feedId, {like})`:
   `POST .../feeds/{id}/react` body `{"reaction":"like"}` untuk like
   (endpoint ini yang terverifikasi), `DELETE` ke endpoint sama untuk
   unlike (konvensi toggle REST FCOM, **belum ada capture DevTools
   terpisah** — kalau gagal, UI di-revert otomatis oleh `_toggleLike`,
   jadi aman meski dugaan method HTTP-nya salah). `Set<int> _likedFeedIds`
   untuk optimistic UI persis seperti rencana.
4. **Kotak feed bisa diklik** — seluruh `Card` dibungkus `InkWell` →
   `_openComments`. Ikon Like dibungkus `GestureDetector(behavior:
   HitTestBehavior.opaque)` supaya tap-nya tidak ikut ditelan `InkWell`
   kotak utama.

**Belum diverifikasi user.** Yang perlu dicek terutama: apakah `DELETE
.../feeds/{id}/react` benar-benar unlike (poin 3) — kalau ternyata salah,
tap kedua pada like akan terlihat "gagal" (snackbar merah) lalu balik ke
status liked, bukan crash.

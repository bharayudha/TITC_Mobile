# Riwayat Percakapan Lengkap — Sesi 5–6 Agustus 2026

Rekam jejak kronologis seluruh sesi kerja perbaikan aplikasi `titc_mobile`.
Dokumen ini mencatat **urutan permintaan, temuan, dan tindakan** apa adanya —
termasuk percobaan yang gagal — supaya konteksnya utuh saat dilanjutkan.

Ringkasan teknis yang lebih padat ada di [CLAUDE.md](CLAUDE.md).

---

## Permintaan 1 — Gambar course tidak muncul & "Continue Learning" salah halaman

**Laporan user:** Di menu Courses, gambar konten tidak muncul semua seperti di
web. Saat klik "Continue Learning" tidak masuk ke halaman yang sesuai (harusnya
seperti `titc.or.id/portal/course/course-1-.../lessons`).

**Temuan investigasi:**
- App bukan native penuh — daftar course native, tapi masuk ke course memakai
  WebView yang memuat `titc.or.id`.
- `CourseModel.fromJson` hanya membaca `json['logo']` dan `json['cover_photo']`
  tanpa fallback, padahal `SpaceModel` (endpoint serupa) sudah punya fallback
  `avatar`/`cover`. Course yang memakai key berbeda → gambar kosong diam-diam.
- Gambar dirender lewat `DecorationImage(NetworkImage(...))` **tanpa** handler
  error, jadi kegagalan muat tidak terlihat sama sekali.
- Tombol "Continue Learning" memanggil `SpaceWebViewScreen` yang meng-hardcode
  suffix `/home`. String `/lessons` **tidak ada sama sekali** di seluruh
  codebase.

**Tindakan:**
1. `course_model.dart` — tambah fallback `json['avatar']` dan `json['cover']`.
2. `courses_list_screen.dart` — ganti ke widget gambar dengan `errorBuilder`
   (ikon placeholder saat gagal).
3. `space_webview_screen.dart` — tambah parameter `initialPath` (default
   `'home'` supaya alur Spaces tidak berubah).
4. `courses_list_screen.dart` — panggil dengan `initialPath: 'lessons'`.

**Hasil:** `flutter analyze` bersih.

---

## Permintaan 2 — Error koneksi service protocol

**Laporan user:** Muncul error:
```
Error connecting to the service protocol: failed to connect to
http://127.0.0.1:50960/... HttpException: Connection closed before full header
was received
```
disertai log auth yang berhenti.

**Jawaban:** Ini **bukan bug aplikasi** — koneksi Dart VM service (`flutter run`)
yang putus, sementara app tetap berjalan normal. Penyebab umum: layar perangkat
terkunci/sleep, kabel/ADB putus, app di-kill OS, atau firewall memblok port
loopback. Solusi: stop `flutter run` lalu jalankan ulang, pastikan perangkat
tidak sleep, cek `adb devices`.

*(Isu ini muncul lagi di Permintaan 8 — lihat di bawah.)*

---

## Permintaan 3 — Fitur lihat komentar di feed Home

**Laporan user:** Ingin fitur lihat komentar penuh di feed Home berfungsi
seperti di website WordPress-nya.

**Temuan investigasi:**
- Kartu feed di Home **tidak punya tap handler sama sekali** — jumlah komentar
  hanya teks statis.
- **Tidak ada** `CommentModel`, **tidak ada** endpoint komentar di
  `api_service.dart`, dan `/feeds` hanya mengembalikan `comments_count`.
- `PostDetailScreen` yang ada hanya menampilkan ulang satu post, tanpa daftar
  komentar.
- Field `permalink` sudah diambil dari API tapi **tidak pernah dipakai**.

**Keputusan (dikonfirmasi user):** Pakai pendekatan WebView ke halaman post
asli — cepat, persis sama dengan web, realtime, dan tidak butuh endpoint baru.
Opsi alternatif (native penuh) ditolak karena butuh riset endpoint dulu.

**Tindakan:** Bungkus ikon komentar dengan `InkWell` → buka
`AuthenticatedWebViewScreen` dengan `activity.permalink`.

---

## Permintaan 4 — Perpindahan tab stuck, timeout, gambar lambat

**Laporan user:** Pindah tab Home ↔ Spaces ↔ Courses sering stuck dengan error
`TimeoutException after 0:00:15` pada fetch profil. Minta perpindahan cepat dan
gambar cepat muncul, tetap realtime dengan web.

**Temuan investigasi (3 akar masalah yang saling memperparah):**
1. `main_shell.dart` memakai `AnimatedSwitcher` + `KeyedSubtree` → State tab
   lama **dibuang** setiap pindah tab, jadi `initState` (dan semua fetch
   jaringan + download gambar) terulang dari nol setiap kali kembali ke tab.
2. **Semua** request di `auth_service.dart` & `api_service.dart` memakai header
   `Connection: close` → handshake TCP/TLS baru tiap panggilan, tanpa keep-alive.
   Ditambah tidak ada de-dupe request (kecuali `refreshNonce()` yang sudah
   punya guard). `_fetchUserProfile` melakukan 3 request berantai, masing-masing
   timeout 15 detik.
3. **Tidak ada** package image caching; semua `Image.network`/`NetworkImage`
   tanpa disk cache → gambar re-download setiap tab dibangun ulang.

**Tindakan:**
1. `main_shell.dart` — tab yang sudah dibuka tetap hidup di tree
   (`AnimatedOpacity` + `IgnorePointer` + `TickerMode`), transisi fade
   dipertahankan.
2. Hapus `Connection: close` di semua request; pakai `http.Client` bersama di
   kedua service.
3. Tambah guard in-flight (`??=` + `whenComplete`) untuk `fetchActivities`,
   `fetchSpaces`, `fetchCourses`, `_fetchUserProfile`.
4. Tambah `cached_network_image`, konversi **17 call site** di seluruh app.

---

## Permintaan 5 — Komentar masih tampil seperti website

**Laporan user:** Fitur komentar sudah terhubung tapi tampilannya terlempar ke
website langsung — tidak pas di mobile. Minta semua fitur di komentar bisa
dipakai seperti di screenshot (like, reply, tulis komentar, emoji, Post Comment).

**Temuan:** `AuthenticatedWebViewScreen` mengirim user-agent **desktop Windows
Chrome**, jadi server menyajikan layout desktop (dialog kecil melayang di atas
latar gelap). Screen Spaces/Courses tidak bermasalah karena memakai UA mobile.

**Tindakan (tahap 1):** Ganti UA ke Android mobile + tambah CSS
`_commentsExtraCss` untuk mem-fullscreen-kan modal Element Plus.

**Ternyata belum cukup** — lihat Permintaan 6.

---

## Permintaan 6 — Komentar MASIH seperti website + Courses ter-lock

**Laporan user:** Komentar masih terlempar ke tampilan WordPress. Selain itu,
akun yang sudah unlock courses masih kena "This is a private course". User
menawarkan kredensial akun testing agar asisten login sendiri lewat DOM.

**Temuan komentar:** Perbaikan UA saja tidak cukup karena CSS di
`AuthenticatedWebViewScreen` menargetkan **nama class tebakan** yang tidak
cocok dengan DOM asli. Sementara `SpaceWebViewScreen` memakai class name yang
sudah **diverifikasi lewat DOM debug** plus JS reflow layout Element Plus.

**Tindakan:**
- `SpaceWebViewScreen` diberi parameter baru `overrideUrl` (untuk memuat URL
  absolut seperti permalink post) dan `extraCss`.
- `home_screen.dart` dialihkan memakai `SpaceWebViewScreen`, bukan
  `AuthenticatedWebViewScreen`.

**Soal kredensial:** Asisten menolak/menjelaskan tidak bisa memakainya — tidak
ada tool browser/DOM di environment ini, hanya baca-tulis kode dan shell. Yang
dilakukan sebagai gantinya: tambah logging `COURSE_JSON` dan `COURSE_PARSED`
untuk melihat data asli dari API.

---

## Permintaan 7 — Menu titik-3 komentar, courses masih lock, space kurang

**Laporan user (3 hal):**
1. Tombol "⋮" di tiap komentar belum ada / belum berfungsi.
2. Akun yang sudah unlock courses masih kena lock.
3. Di akun `fahrur`, daftar Spaces ada yang kurang; gambar konten masih ada
   yang belum tampil.

**Temuan & tindakan:**

1. **Titik-3 komentar:** CSS dasar `SpaceWebViewScreen` menyembunyikan
   `.fcom_dot_menu` secara total (`opacity: 0` + `pointer-events: none`) supaya
   hanya bisa dipicu tombol "⋮" kustom di app bar. Tapi FCOM memakai class yang
   **sama** untuk tombol "⋮" milik **setiap komentar** → semuanya ikut mati.
   → Tambah override `.el-dialog .fcom_dot_menu` di `_commentsExtraCss`.

2. **Space kurang:** Ditemukan `fetchSpaces` satu-satunya dari tiga fetch daftar
   yang **tidak** menangani respons berhalaman — langsung cast ke `List`.
   → Dibuat loop pagination + log `SPACES_PAGE_INFO`.
   *(Catatan: perbaikan ini ternyata SALAH SASARAN — lihat Permintaan 9.)*

3. **Gambar belum tampil:** Dugaan media privacy-gated butuh cookie sesi,
   padahal request gambar polos tidak mengirim cookie.
   → Tambah `AuthService.imageAuthHeaders` dan pasang di **semua 17 call site**
   gambar.

---

## Permintaan 8 — Log COURSE_PARSED + minta Members dibuat

**Data yang dikirim user (kunci penting):**
```
COURSE_PARSED: slug=course-1-1775480860-1775480875 isEnrolled=true privacy=private title=10 Meeting Courses
... (9 course, SEMUANYA isEnrolled=true)
```
Plus screenshot halaman lessons di web yang berhasil dibuka, dan screenshot
halaman `/portal/members` yang diminta ditiru.

**Analisis:** `isEnrolled=true` untuk semua course membuktikan **data API sudah
benar** — akun memang punya akses. Jadi masalahnya bukan parsing, melainkan
**sesi WebView** tidak terbawa sehingga server merender halaman sebagai tamu.

**Tindakan Courses (percobaan):**
1. Kirim cookie sebagai **header eksplisit** di `loadRequest`.
2. `clearCookies()` sebelum set cookie baru (antisipasi sisa sesi akun lama).
3. Header anti-cache (`Cache-Control`, `Pragma`) — situs pakai LiteSpeed Cache,
   terlihat dari cookie `_lscache_vary`.

**Tindakan Members (permintaan baru):**
- `MemberModel` dilengkapi `username`, `joinedAt`, `bio`, `socialLinks`,
  `isFollowed` dengan fallback root maupun `xprofile`.
- `fetchMembers` jadi berbasis halaman → class `MembersPage`
  (`total`, `currentPage`, `lastPage`, `hasMore`) + `toggleFollowMember`.
- Layar Members didesain ulang meniru web: judul "All Members (2,256)",
  pencarian debounce, kartu (avatar + fallback inisial, nama, `@username`,
  "Joined … • Last seen …", bio, ikon sosial, tombol Follow), infinite scroll,
  pull-to-refresh.

**Permintaan user:** mulai sekarang balasan memakai bahasa Indonesia.

---

## Permintaan 9 — Courses malah minta LOGIN ULANG

**Laporan user:** Di Courses sekarang malah diminta login lagi (harusnya tidak).
Space masih ada yang belum tampil (contoh: "Update - Certification"). Menanyakan
apa yang dibutuhkan untuk melanjutkan bagian Members.

**Temuan:** Ini **regresi akibat perbaikan di Permintaan 8**. WebView Android
sudah otomatis mengirim cookie dari cookie jar-nya sendiri; menambah header
`Cookie` manual di atasnya membuat cookie ganda/konflik sehingga server gagal
memvalidasi sesi sama sekali — lebih parah dari kondisi awal.

**Tindakan:** Revert — hapus header `Cookie` manual **dan** `clearCookies()`,
sisakan hanya header anti-cache.

---

## Permintaan 10 — Log SPACES_PAGE_INFO + berbagai isu

**Data yang dikirim user (kunci penting):**
```
SPACES_PAGE_INFO: currentPage=null lastPage=null itemsOnPage=5
FCOM_JSON: { "id": 16, "title": "FREE Placement Test", "slug": "placement-test",
             "parent_id": "13", "type": "community", "privacy": "public", ... }
```
Plus screenshot Members di app yang **sudah berhasil** menampilkan 2.256 member.

**Laporan user:**
1. Space masih belum muncul semua.
2. Members sudah tampil — minta ikon LinkedIn/Instagram bisa diklik.
3. Courses masih minta login ulang.
4. Terminal tidak menampilkan log, stuck di baris Impeller/Vulkan, disertai
   error service protocol lagi.

**Analisis Spaces (temuan penting):** `currentPage=null lastPage=null`
membuktikan `/spaces` **TIDAK dipaginate sama sekali**. Jadi perbaikan
pagination di Permintaan 7 salah sasaran. API mengembalikan 5 space dalam satu
respons sementara web menampilkan 6 → space ke-6 berada di **bagian lain
struktur JSON** yang parser tidak baca.

**Tindakan:**
1. **Spaces:** Hapus seluruh logika pagination. Ganti dengan
   `_collectSpaceLikeObjects()` — menelusuri seluruh struktur JSON secara
   rekursif, memungut setiap objek ber-`id` + `slug` + `title`, dedupe by `id`,
   buang `type == 'course'`. Tahan terhadap bentuk respons apa pun.
   Tambah log `SPACES_ENVELOPE_KEYS`, `SPACES_COLLECTED`, `SPACE_ITEM`.
2. **Ikon sosial:** Tambah `url_launcher` + deklarasi `<queries>` di
   `AndroidManifest.xml` (wajib Android 11+, tanpa ini tap tidak melakukan
   apa-apa), ikon dibungkus `InkWell` → `launchUrl` mode external.
3. **Format waktu:** Screenshot menunjukkan "Joined 2026-07-21 13:42:26" masih
   timestamp mentah → tambah `_humanizeTime` supaya jadi "15 days ago" seperti web.
4. **Log/timeout:** Dijelaskan ini masalah tooling, bukan kode — app tetap jalan
   (terbukti UI normal). Solusi: `adb logcat -s flutter` untuk lihat log tanpa
   bergantung VM service, plus `adb kill-server && adb start-server` dan
   rebuild bersih.

---

## Status akhir sesi

### Selesai & terverifikasi user
- **Members** — tampil benar dengan 2.256 member (dikonfirmasi screenshot).

### Selesai, menunggu verifikasi user
- Gambar course/space (fallback key + error handler + cookie auth).
- "Continue Learning" → `/lessons`.
- Performa navigasi tab (state dipertahankan, keep-alive, de-dupe, image cache).
- Komentar feed via `SpaceWebViewScreen` + tombol "⋮" per komentar.
- Spaces dengan parser rekursif.
- Ikon sosial clickable + format waktu relatif.

### Belum selesai
- **Courses ter-lock / minta login ulang** — sudah di-revert ke kondisi aman,
  tapi belum dites user setelah revert.

### Kendala yang bukan masalah kode
- Koneksi VM service putus → log tidak muncul di terminal.
- Beberapa laporan "timeout" ternyata perangkat tanpa koneksi
  (`Failed host lookup: 'titc.or.id'` = DNS gagal).

---

## Langkah berikutnya

1. **Rebuild bersih WAJIB** — ada dependency baru (`url_launcher`) dan
   perubahan `AndroidManifest.xml` yang tidak terpakai lewat hot reload:
   ```
   flutter clean
   flutter pub get
   flutter run
   ```
2. Kalau log tidak muncul di terminal, pakai: `adb logcat -s flutter`
3. Kirim log berikut untuk melanjutkan diagnosis:
   - `SPACES_ENVELOPE_KEYS`, `SPACES_COLLECTED`, semua `SPACE_ITEM`
     → memastikan "Update - Certification" ikut terkumpul
   - `WEBVIEW_LOAD:` saat membuka course → memastikan cookie tidak kosong
   - `MEMBER_JSON:` → mencocokkan nama field asli members

---

## Catatan penting untuk sesi berikutnya

- **Asisten tidak punya akses browser/DOM/perangkat**, jadi tidak bisa login ke
  situs atau menjalankan app untuk verifikasi sendiri. Setiap perbaikan yang
  menyangkut perilaku runtime **selalu butuh konfirmasi dari user**. Kredensial
  akun tidak bisa dipakai dan sebaiknya tidak dikirim.
- **Pelajaran dari regresi Permintaan 8→9:** jangan menumpuk mekanisme auth yang
  sudah otomatis (cookie jar WebView) dengan yang manual (header `Cookie`) —
  justru bikin konflik.
- **Pelajaran dari Permintaan 7→10:** jangan menebak bentuk respons API.
  Pagination yang ditambahkan ternyata tidak dibutuhkan sama sekali. Lebih baik
  log dulu bentuk aslinya, baru tulis parser.
- Debug logging masih aktif dengan prefix: `COURSE_JSON`, `COURSE_PARSED`,
  `FCOM_JSON`, `SPACES_ENVELOPE_KEYS`, `SPACES_COLLECTED`, `SPACE_ITEM`,
  `MEMBERS_PAGE_INFO`, `MEMBER_JSON`, `WEBVIEW_LOAD`. **Hapus sebelum rilis.**

---

## Sesi 13 Agustus 2026 — Search & space yang hilang

Aturannya sejak sesi ini: kronologi & hipotesis yang gugur ditulis di sini,
aturan yang masih berlaku ditulis di CLAUDE.md.

### Permintaan A — "kenapa muncul tulisan gitu" (error di Feed)

Feed menampilkan pesan error. Log menunjukkan
`type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>?'`.

**Akar masalah:** PHP menserialisasi array asosiatif **kosong** sebagai `[]`,
bukan `{}`. Jadi `json['x'] as Map<String, dynamic>?` melempar exception alih-alih
menghasilkan null.

Efek samping yang ikut ketahuan: pola `json['xprofile'] ?? json['actor']` di
`notification_model.dart` tidak pernah jatuh ke `actor`, karena `[]` bukan null.
Dan rantai `x as Map? ?? y as Map?` sama sekali tidak menolong — cast kiri sudah
melempar sebelum `??` dievaluasi.

**Tindakan:** file baru `lib/models/json_utils.dart` (`asJsonMap`, `asJsonList`,
`asJsonString`), diterapkan ke 6 model.

### Permintaan B — Search disamakan dengan web

User mengirim tangkapan layar search bar web: ada dropdown "All Posts" yang
isinya **Membership Areas**, plus baris centang "Search in:".

Parameter API didapat dari cURL DevTools yang dikirim user langsung — bukan
tebakan:
```
/feeds?feed_base_url=feeds&page=1&per_page=20&space=&order_by_type=latest
       &search=free&search_in[0]=post_content
```

**Tindakan:** `searchFeeds()` baru di `api_service.dart`, `search_overlay.dart`
ditulis ulang mengembalikan `SearchRequest`, file baru
`search_results_screen.dart`, dan `top_app_bar.dart` diperbaiki agar `await`
hasil overlay (sebelumnya `Future`-nya dibuang — itu sebabnya tombol search
terasa mati).

### Permintaan C — "kamu ketinggalan TOEFL Mockup Test"

Ini bagian yang paling banyak salah duga. Ditulis lengkap supaya tidak diulang.

**Hipotesis 1 — filter `type == 'course'` di app membuang space itu.**
❌ GUGUR. Log sendiri membantahnya: `total=6 nonCourse=6` (dan sebelumnya
`total=5 nonCourse=5`). Tidak ada satu pun yang terbuang oleh filter.
Komentar kode yang terlanjur saya tulis berdasarkan dugaan ini ikut diralat.

**Hipotesis 2 — server memang cuma punya 5 space.**
❌ GUGUR. User mengirim tangkapan layar web: di sana jelas ada 6.

**Hipotesis 3 — `/spaces` hanya mengembalikan space yang sudah di-join.**
✅ TERBUKTI. Petunjuk penentunya: di web, "TOEFL - Mockup Test" adalah
satu-satunya kartu yang tombolnya **"Join"**, sisanya "View Space".

**Hipotesis 4 — web memakai endpoint lain.**
✅ TERBUKTI lewat cURL DevTools user:
`/spaces/discover?type=all&search=&sort_by=alphabetical&page=1&per_page=24`

**Kejutan setelah pindah endpoint:** log `SPACE_KEYS` menunjukkan respons
`discover` **tidak punya** `is_joined` maupun `is_member` — yang ada
`space_pivot`. Tanpa menyadari ini, perbaikan tadi akan "berhasil" tapi semua
space menampilkan tombol "Join", termasuk yang sudah diikuti.

**Hasil:** satu perubahan endpoint memperbaiki empat hal — toggle All/Joined di
tab Spaces (dulu dua-duanya identik), TOEFL - Mockup Test di drawer, isi
dropdown search, dan pencarian space sisi server.

### Permintaan D — "ni bug baru ni jadi ikutan yang course nya"

Dropdown search ikut menampilkan grup "Courses" (10/15/20 Meeting Courses, dst)
yang tidak ada di web.

**Penyebab:** tambalan dari Hipotesis 1 yang sudah gugur. Waktu itu saya
menambahkan seluruh course ke dropdown sebagai jalan pintas, dan setelah
penyebab asli ketemu tambalan itu tidak dicabut.

**Tindakan:** grup Courses, field `_courses`, panggilan `fetchCourses()`, dan
import `course_model.dart` dihapus dari `search_overlay.dart`. Fallback ke
daftar course di `portal_navigator.dart` **dipertahankan** — lahir dari dugaan
yang sama, tapi masuk akal berdiri sendiri karena label drawer memang tidak tahu
sebuah area itu space atau course.

**Pelajaran:** tambalan berbasis dugaan harus dicabut begitu penyebab asli
ketemu, bukan ditinggal "siapa tahu berguna".

### Kondisi akhir sesi

`flutter analyze` → **0 error**. Sisa 104 issue semuanya `avoid_print` (debug
log yang disengaja) plus 3 `unused_import` bawaan tim di `profile_screen.dart`,
`test_fetch.dart`, `test_js.dart`.

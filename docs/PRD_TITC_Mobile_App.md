# PRD — Aplikasi Mobile TITC Indonesia

## 0. Profil Resmi TITC Indonesia™

**TITC Indonesia** merupakan lembaga penyedia tes TOEFL ITP® dan TOEFL iBT® resmi yang tersertifikasi oleh **Educational Testing Service (ETS)**. 

- **Tanggal Berdiri**: 8 Januari 2023
- **Pendiri / Leader**: Heri Setio A, S.Pd., M.I.Kom. (Managing Director of One Stop English Education Yogyakarta)
- **Naungan Resmi**: One Stop English Education Yogyakarta — *The Authorized TOEFL Test Center* partner resmi **IIEF** (Indonesian International Education Foundation) dan **ITC** (International Testing Center)
- **Cakupan Layanan**: Penyelenggaraan tes TOEFL ITP®, TOEFL iBT® Home Edition, dan TOEIC® resmi ETS.
- **Pencapaian**: Memfasilitasi 2.000+ Test Taker per tahun untuk pemberkasan Beasiswa LPDP, AAS, BUMN, CPNS, serta institusi pendidikan di seluruh Indonesia.
- **Alamat Kantor**: Sedayu, Bantul, Daerah Istimewa Yogyakarta, Indonesia.

## 1. Ringkasan Produk

Aplikasi mobile Android (dan iOS di fase berikutnya) yang menampilkan konten dari website WordPress **titc.or.id** dengan dua jenis pengalaman:

1. **Menu Shortcut** — ikon-ikon di halaman utama yang membuka halaman WordPress publik (misal `titc.or.id/toefl-itp`, `titc.or.id/jadwal`) lewat WebView, dengan tampilan CSS yang disesuaikan untuk layar mobile.
2. **Forum/Komunitas Native** — satu menu khusus yang mengarah ke fitur komunitas (`titc.or.id/portal`, berbasis plugin **Fluent Community**), tapi tampilannya **dibangun ulang secara native** (bukan WebView) menggunakan Flutter, dengan data ditarik dari WordPress REST API / Fluent Community REST API.

Prinsip inti: **WordPress + Fluent Community tetap menjadi satu-satunya sumber data (single source of truth)**. Aplikasi mobile tidak menyimpan data forum sendiri — semua post, komentar, pesan, dan member data tetap tersimpan dan tersinkron di database WordPress yang sama dengan versi web.

## 2. Tujuan

- Memberi pengalaman mobile yang nyaman (native-like) untuk fitur komunitas TITC.
- Tidak mengubah/mengganggu tampilan desktop/browser dari website WordPress yang sudah berjalan.
- Notifikasi realtime (push notification) untuk aktivitas forum.
- Siap disubmit ke Google Play Store dalam waktu 30 hari (lihat dokumen Timeline terpisah).

## 3. Tech Stack

| Layer | Teknologi | Alasan |
|---|---|---|
| Mobile Framework | **Flutter** | Performa native, pengembangan lintas platform (Android & iOS) dari satu basis kode, mendukung integrasi WebView untuk menu shortcut |
| Data Source Utama | **WordPress REST API** (`/wp-json/wp/v2/`) | Untuk halaman/post publik |
| Data Forum | **Fluent Community REST API** (`/wp-json/fluent-community/v2/`) | Untuk Activity Feed, Spaces, Members, Chat |
| Autentikasi | **WordPress Cookie Authentication** | Login disubmit via POST form, mengembalikan cookie `wordpress_logged_in` yang disisipkan ke Header tiap request API. |
| Backend Notifikasi | **Custom WordPress Plugin (PHP)** | Menjembatani trigger notifikasi ke Firebase (FCM) langsung dari action hooks Fluent Community/WordPress tanpa perlu server terpisah. |
| Push Notification | **Firebase Cloud Messaging (FCM)** | Satu-satunya jalur resmi push notification Android |
| Version Control | **GitHub** (private repo) | Kolaborasi tim |
| Build Target | Android APK/AAB (fase 1), iOS (fase berikutnya) | Sesuai scope 30 hari |

## 4. Arsitektur Sistem (Alur Data)

```
[ Flutter App ]
        |
        |  1. Menu Shortcut → WebView langsung ke halaman WordPress
        |     (titc.or.id/toefl-itp, /jadwal, dst — CSS mobile-only disuntik via Customizer)
        |
        |  2. Menu Forum → fetch data via REST API
        v
[ WordPress + Fluent Community + LearnDash (di hosting perusahaan) ]
        |
        |  Trigger saat ada activity baru (post/comment/message)
        v
[ Custom WordPress Plugin (PHP) ]
        |
        |  Panggil FCM API untuk kirim push notification
        v
[ Firebase Cloud Messaging ]
        |
        v
[ HP User — Notifikasi masuk ]
```

Catatan: Plugin PHP ini berjalan di dalam WordPress dan bertugas sebagai "penerus sinyal" dari aktivitas Fluent Community ke Firebase.

## 5. Struktur Fitur & Layar (Screens)

### 5.1 Halaman Utama (Home)
- Grid menu/ikon sesuai desain Figma.
- Setiap ikon punya `type`: `webview` (buka URL WordPress biasa) atau `native` (buka layar native Forum).

### 5.2 Menu Shortcut (WebView)
- Layar generik yang menerima parameter URL, contoh: `toefl-itp`, `jadwal`, `info`.
- WebView load `https://titc.or.id/{slug}` dengan header custom (misal `X-App-Client: titc-mobile`) supaya WordPress bisa mendeteksi request dari aplikasi dan menyajikan CSS mobile-only.

### 5.3 Forum — Feed
- List activity terbaru (post, like, comment).
- Data: `GET /wp-json/fluent-community/v2/feeds`

### 5.4 Forum — Groups/Spaces
- Daftar grup yang bisa diikuti user.
- Data: `GET /wp-json/fluent-community/v2/spaces`

### 5.5 Forum — Members
- Daftar anggota komunitas + profil dasar.
- Data: `GET /wp-json/fluent-community/v2/members`

### 5.6 Forum — Messages (Chat)
- Chat pribadi antar user.
- Data: `GET /wp-json/fluent-community/v2/chat/threads`

### 5.7 Notifikasi In-App (Real-time Web Sync)
- Menampilkan notifikasi interaktif pada ikon lonceng di *app bar*.
- **Data & Endpoint**: `GET /wp-json/fluent-community/v2/notifications` (dengan filter *client-side* untuk tab *Unread*, *Mentions*, *Recent*, *Following* karena parameter query `?type=` sering diabaikan backend).
- **Mekanisme "Real-time" (Polling)**: Karena arsitektur backend saat ini belum memiliki WebSocket atau eksekusi *push notification* FCM yang lengkap, aplikasi menjalankan **Polling Background** setiap 60 detik selama aplikasi aktif.
- **Sinkronisasi Web & Unread State**: Aplikasi melakukan *background polling* untuk memeriksa jumlah notifikasi yang belum dibaca (`unreadCount`) ke spesifik *endpoint* `/wp-json/fluent-community/v2/notifications/unread`. Hal ini sangat krusial, sebab *endpoint* utama `/notifications` selalu mengembalikan semua notifikasi dan mengabaikan atribut `is_read` (tidak ada di JSON balasan).
- **Mark As Read (Penting)**: Server memiliki perlindungan keamanan untuk metode `POST`. Fitur "Mark all as read" di aplikasi diarahkan ke `POST /wp-json/fluent-community/v2/notifications/mark-all-read` yang diiringi dengan header `Content-Type: application/json` serta *body* JSON kosong `{}` untuk menghindari penolakan. Klik tunggal sebuah notifikasi akan dikirimkan ke `/wp-json/fluent-community/v2/notifications/mark-read/{id}` secara asinkron.
- **Navigasi Klik**: Membuka notifikasi (misal: *Space Feed*) akan menggunakan `SpaceWebViewScreen` yang otomatis menyuntikkan CSS *native-like shell*, sehingga user tidak merasa terlempar ke tampilan browser web desktop.

### 5.8 Login
- Autentikasi menggunakan form action `login` yang mengembalikan Cookie WordPress (`wordpress_logged_in`).
- Disimpan lokal dengan `flutter_secure_storage`.
- Signup menggunakan alur 2-Step (Submit Data -> Verifikasi Kode Email 2FA).

### 5.8 Profile Settings & Edit Profile
- Menu profil dipisahkan menjadi komponen *Native* dan *WebView* untuk menjamin pengalaman pengguna (UX) yang seamless:
  1. **Edit Profil (Ikon Pensil)**: Menggunakan halaman *100% Native Flutter* (`ProfileEditScreen`) untuk mengubah First Name, Last Name, Email, Website URL, Bio, Social Links, dan Password.
     - Endpoint: `POST /wp-json/wp/v2/users/me` (untuk data standar WP).
  2. **Avatar Upload (Ikon Kamera/Awan)**: Diubah menjadi fitur *100% Native* menggunakan `image_picker` (bukan WebView).
     - **Alasan**: Tampilan upload WebView FCOM sangat bertabrakan dengan navigasi mobile dan merusak UX.
     - **Solusi UX (Bypass Upload)**: Karena *user* standar (Subscriber) diblokir untuk mengunggah ke WP Media Library (`/wp/v2/media`), aplikasi secara langsung melakukan POST *multipart/form-data* foto ke endpoint internal FCOM: `POST /wp-json/fluent-community/v2/feeds/media-upload`. 
     - **Metode Sinkronisasi**: Setelah mendapatkan URL *image* sukses dari balasan *upload*, aplikasi mengambil *Username Slug* rahasia milik user (yang dilacak saat `AuthService.init()`) lalu mengirim `PUT /wp-json/fluent-community/v2/profile/{slug}` dengan `{"data": {"avatar": "URL_FOTO"}}`. Data foto akan otomatis terefresh lewat mekanisme *Pull-to-Refresh* (`RefreshIndicator`) di `ProfileScreen`.

## 6. Kebutuhan Non-Fungsional

- **Keamanan token**: token JWT disimpan pakai secure storage, bukan localStorage biasa.
- **Tidak mengubah tampilan desktop**: semua CSS mobile-only wajib conditional (deteksi header/User-Agent khusus dari aplikasi).
- **Kompatibilitas**: uji di minimal 3 varian perangkat Android (ukuran layar & versi OS berbeda).
- **Fallback offline**: tampilkan pesan "tidak ada koneksi" yang ramah jika API tidak terjangkau, bukan layar putih/error mentah.
- **Privasi data**: data pribadi user (chat, profil) hanya diakses lewat token milik user tersebut, tidak lewat Application Password generik untuk permintaan spesifik-user.

## 7. Yang TIDAK Termasuk di Scope Ini (Fase 2 / Perlu Klarifikasi Lanjutan)

- Fitur tambahan yang belum didetailkan oleh perusahaan (lihat catatan di Timeline).
- Versi iOS (aplikasi akan dibuat Android dahulu).
- Payment/transaksi di dalam aplikasi (dialihkan ke `titc.or.id` via browser/WebView terpisah, di luar sesi login forum).

## 8. Dependensi & Prasyarat Sebelum Development Dimulai

- Akses Administrator WordPress (atau role dengan capability setara — lihat dokumen Requirement terpisah).
- Konfirmasi REST API Fluent Community & LearnDash aktif dan bisa diakses dari luar (tidak diblokir plugin security).
- Application Password sudah digenerate untuk keperluan testing awal.
- Firebase project sudah dibuat, `google-services.json` sudah didapat untuk dimasukkan ke project Android.
- Daftar final menu shortcut beserta URL tujuan masing-masing.
- Desain Figma final untuk seluruh layar (Home, Feed, Groups, Members, Messages, Login).

## 9. Referensi Dokumen Terkait

- `Laporan_Kebutuhan_Teknis.docx` — daftar lengkap akses/data yang diminta ke perusahaan.
- `Timeline_Pengembangan_Aplikasi_Mobile_TITC.docx` — jadwal kerja 30 hari per anggota tim.

## 10. Detail Koneksi API & Alur Autentikasi

### Mapping Endpoint Fluent Community
- **Feed**: `GET /wp-json/fluent-community/v2/feeds`
  - *Struktur Response*: Mengembalikan JSON dengan objek utama `"feeds"`, yang di dalamnya terdapat array `"data"`. Pembacaan di aplikasi harus membongkar struktur ini (`data['feeds']['data']`).
- **Spaces**: `GET /wp-json/fluent-community/v2/spaces`
- **Members**: `GET /wp-json/fluent-community/v2/members`
- *Catatan: Semua endpoint di atas memerlukan Cookie WordPress valid di header request.*

### Alur Autentikasi (Cookie-Based)
Karena standar JWT API atau BuddyBoss sudah digantikan, login & register dilakukan dengan "meniru" form browser via WebView-like request:
1. **Login**: GET halaman `/portal/?fcom_action=auth` -> ekstrak `_fcom_login_nonce` -> POST username, password, nonce ke `/login/`.
2. **Register**: GET halaman form register -> ekstrak `_fcom_signup_nonce` -> POST data ke `admin-ajax.php?action=fcom_user_registration` -> Ekstrak Token 2FA dari HTML response -> Tampilkan Dialog OTP di Flutter -> POST kode OTP ke admin-ajax.php.
3. **Penyimpanan Sesi (Persistent Login)**: Cookie `wordpress_logged_in` yang didapat dari Set-Cookie disimpan menggunakan `flutter_secure_storage` lalu disisipkan ke header `Cookie` di setiap request ke `/fluent-community/v2/`.
   - **Handling Hot Restart / App Resume**: Pada `AuthService.init()`, sistem akan memuat *cookies* dan menembak `/portal/` untuk mendapatkan *REST API Nonce* terbaru dari HTML. Jika fetch *nonce* gagal, sesi/cookie **tidak dihapus** untuk mencegah user ter-*logout* secara tidak sengaja akibat isu jaringan.
   - **Routing Otomatis**: Layar utama (`app.dart`) akan mengecek `AuthService.isLoggedIn` dan secara otomatis mengarahkan ke `MainShell()` jika login masih valid.

> [!IMPORTANT]
> **Catatan Penting Proteksi Firewall/Anti-Bot**: 
> Semua *request* HTTP (baik GET data maupun POST login/register) WAJIB menyertakan header `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36` dan `Referer: https://titc.or.id/portal/`. Jika menggunakan *User-Agent* default Dart/Flutter (seperti `TITC-Mobile-App/1.0`), *request* akan diblokir dengan status `401/403 Forbidden` oleh sistem anti-DDOS / WordFence / LiteSpeed yang berjalan di server.

## 11. Pembagian Jobdesk & Timeline (4 Minggu)

Proyek pengembangan tahap awal ini dibagi ke dalam 4 minggu sprint. Berikut adalah detail fokus pengerjaan untuk masing-masing anggota tim pada **Minggu ke-1 dan ke-2**:

### Anggota 1: Fahrur & Anggota 4: Jidan (Tim UI/UX & Frontend)
Fokus pada perancangan antarmuka visual dan implementasi kerangka UI di Flutter.
*   **Minggu 1 (UI/UX Design)**: Membuat desain *mockup* dan prototipe aplikasi mobile menggunakan Figma. Menyesuaikan panduan warna (brand guidelines) TITC Indonesia dan menyusun tata letak (*layout*) untuk layar Home, Forum, Profil, dan Login.
*   **Minggu 2 (Frontend Slicing)**: Menerjemahkan desain Figma ke dalam kode Flutter (*UI Slicing*). Menyusun komponen visual (*widgets*) statis untuk tampilan aplikasi tanpa logika data backend.

### Anggota 2: Arnanda (Backend)
Fokus pada kerangka kerja logika aplikasi, autentikasi, dan komunikasi API utama.
*   **Minggu 1 (Setup & Authentication)**: Menyiapkan arsitektur struktur *project* Flutter, mengatur konfigurasi WordPress REST API, serta meneliti dan mengimplementasikan alur sistem Autentikasi berbasis *Cookie* (Login/Register/Sesi).
*   **Minggu 2 (API Integration & Profile Logic)**: Membangun `ApiService` untuk menarik data halaman Home dan Profil. Mengimplementasikan logika khusus seperti pengiriman *multipart/form-data* untuk fitur *Native Avatar Upload* dan sistem *Pull-to-Refresh*.

### Anggota 3: Bhara (Tim Fitur & Data Engineer)
Fokus pada integrasi data pihak ketiga, fitur interaktif (komunitas), dan pengolahan *state*.
*   **Minggu 1 (Data Modeling & API Research)**: Menganalisis *endpoint* dari Fluent Community API. Membuat struktur Data Models (JSON ke Dart Object) untuk *Feed*, *Spaces*, *Members*, dan *Messages*, serta mempersiapkan *environment* Firebase.
*   **Minggu 2 (Fitur Forum Messages/Chat)**: Mengimplementasikan logika komunikasi obrolan secara penuh (membuat `messages_service.dart`, mengolah *state* manajemen obrolan, dan menyambungkannya ke komponen UI milik tim *Frontend*).

## 12. Solusi Masalah "Terlempar ke Tampilan Web" pada Halaman WebView (CSS Injection + MutationObserver)

### Konteks Masalah

Beberapa halaman di aplikasi menggunakan **WebView** untuk menampilkan konten langsung dari website `titc.or.id`. Contoh utama: halaman detail **Space** yang dimuat dari URL `https://titc.or.id/portal/space/{slug}/home`.

Masalah yang terjadi: ketika halaman web dimuat di dalam WebView, elemen-elemen bawaan website seperti **Header, Sidebar, dan Bottom Navigation** dari *Fluent Community (FCOM)* serta *WordPress Theme (Spectra One/Astra)* ikut tampil. Ini membuat user merasa "terlempar" ke browser/website karena tampilan tidak menyatu dengan aplikasi mobile.

### Akar Masalah Teknis

1. **Fluent Community Portal adalah Vue.js SPA (Single Page Application)**: Halaman portal FCOM (`/portal/...`) bukan halaman HTML statis biasa. Ia dirender secara dinamis oleh JavaScript Vue.js dari file `app.js`. Elemen-elemen navigasi (menu atas, sidebar, bottom nav) di-*mount* oleh Vue setelah DOM selesai dimuat.
2. **CSS injection biasa tidak cukup**: Jika CSS hanya disuntikkan sekali saat `onPageFinished`, Vue.js bisa me-*re-render* komponen navigasinya dan mengembalikan elemen-elemen yang sudah disembunyikan.
3. **Selector CSS harus tepat**: Selector generik seperti `header`, `footer`, `nav` tidak selalu mengenai elemen FCOM yang spesifik. Harus menggunakan **class name persis** dari DOM aktual website.

### Solusi: File `SpaceWebViewScreen` dengan 3 Lapisan Pertahanan

Solusi yang diterapkan ada di file `lib/screens/customer/spaces/space_webview_screen.dart` dan menggunakan **3 lapisan pertahanan** untuk memastikan elemen web selalu tersembunyi:

#### Lapisan 1: CSS Injection (Menyembunyikan Elemen)

CSS disuntikkan ke dalam `<head>` halaman web untuk menghilangkan seluruh elemen navigasi. Berikut adalah **daftar lengkap class CSS** yang harus disembunyikan, didapat dari inspeksi langsung DOM website:

| Kategori | Selector CSS | Deskripsi |
|---|---|---|
| **Top Navigation Bar** | `.fcom_top_menu` | Container utama menu atas FCOM |
| | `.top_menu_left` | Bagian kiri menu atas (logo, home) |
| | `.top_menu_center` | Bagian tengah menu atas (search) |
| | `.top_menu_right` | Bagian kanan menu atas (notif, avatar) |
| **Left Sidebar** | `.spaces` | Container daftar Space di sidebar kiri |
| | `.space_contents` | Konten detail sidebar |
| | `#fluent_community_sidebar_menu` | ID sidebar menu |
| | `.fcom_sidebar_wrap` | Wrapper sidebar |
| | `.fcom_side_footer` | Footer sidebar |
| | `.space_opener` | Tombol buka/tutup sidebar |
| **Mobile Bottom Nav** | `.fcom_mobile_menu` | Container menu bawah mobile |
| | `.focm_menu_items` | Wrapper item-item menu |
| | `.focm_menu_item` | Setiap item menu individual |
| **Hamburger Button** | `.fcom_space_opener_btn` | Tombol hamburger untuk buka sidebar di mobile |
| **WordPress Theme** | `header`, `.site-header`, `#masthead` | Header bawaan WordPress |
| | `footer`, `.site-footer`, `#colophon` | Footer bawaan WordPress |
| | `.spectra-header-template` | Header dari theme Spectra One |
| | `.ast-site-header`, `.ast-site-footer` | Header/Footer dari theme Astra |
| | `.elementor-location-header/footer` | Header/Footer dari Elementor |

**Layout Fix** (penting!):
- `.feed_layout`: Harus di-set `padding-left: 0 !important; margin-left: 0 !important;` karena secara default halaman web memberikan offset 280px untuk ruang sidebar.
- `.fcom_wrap`, `.fluent_com`, `.fhr_content`, `#fluent_comminity_body`: Harus di-set `max-width: 100% !important; width: 100% !important;` agar konten mengisi layar penuh.

#### Lapisan 2: MutationObserver (Memantau Re-render Vue.js)

Karena FCOM adalah Vue.js SPA, elemennya bisa di-*re-render* secara dinamis. Untuk menangani hal ini, setelah CSS disuntikkan, sebuah **JavaScript `MutationObserver`** dipasang untuk memantau perubahan pada DOM:

```javascript
var observer = new MutationObserver(function(mutations) {
  if (!document.getElementById('titc-mobile-hide-chrome')) {
    // Re-inject CSS jika style element hilang karena re-render
    var s = document.createElement('style');
    s.id = 'titc-mobile-hide-chrome';
    s.innerHTML = `... CSS rules ...`;
    document.head.appendChild(s);
  }
});
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});
```

Observer ini memastikan bahwa meskipun Vue.js menghapus atau me-*replace* elemen `<style>` yang kita suntikkan, ia akan langsung disuntikkan kembali.

#### Lapisan 3: Opacity Control (Mencegah "Kilatan" Web)

Untuk mencegah user melihat tampilan web mentah sebelum CSS berhasil disuntikkan:

```dart
Opacity(
  opacity: _isLoading ? 0 : 1,
  child: WebViewWidget(controller: _controller),
),
if (_isLoading)
  const Center(child: CircularProgressIndicator()),
```

WebView di-set `opacity: 0` selama loading, dan baru ditampilkan setelah CSS injection selesai dieksekusi (dengan delay 300ms untuk memberi waktu render). Selama itu, user melihat loading spinner.

#### Tambahan: Konfigurasi WebView

- **User-Agent**: Di-set ke User-Agent Android mobile (`Mozilla/5.0 (Linux; Android 13) ...`) agar website mengenali request sebagai perangkat mobile.
- **onNavigationRequest**: Selalu mengembalikan `NavigationDecision.navigate` untuk **mencegah WebView melempar navigasi ke browser eksternal (Chrome)**.
- **Cookie**: Cookie `wordpress_logged_in` dari `AuthService.cookies` disuntikkan ke WebView agar user tetap terautentikasi.

### Cara Menerapkan Pola Ini ke Halaman Lain

Jika di kemudian hari ada halaman FCOM lain yang perlu ditampilkan via WebView (misalnya halaman Post detail, halaman Chat web), gunakan pola yang sama:

1. Buat file WebView screen baru (atau reuse `SpaceWebViewScreen` dengan parameter URL yang berbeda).
2. Suntikkan CSS yang sama (selector FCOM sudah lengkap di tabel di atas).
3. Pasang `MutationObserver` untuk menangani re-render SPA.
4. Gunakan `Opacity` untuk mencegah kilatan tampilan web.
5. Pastikan `onNavigationRequest` selalu mengembalikan `NavigationDecision.navigate`.

> [!IMPORTANT]
> **Catatan: Jika website TITC memperbarui plugin Fluent Community ke versi lebih baru**, nama-nama class CSS di atas bisa berubah. Jika tampilan mulai "terlempar" lagi setelah update plugin, lakukan inspeksi ulang DOM website untuk menemukan selector yang baru. Gunakan Chrome DevTools (Inspect Element) pada halaman `https://titc.or.id/portal/space/{slug}/home` untuk memeriksa class name terbaru.

## 13. Metode Inspeksi Langsung Website & Detail Alur Autentikasi Terverifikasi

### Metode Inspeksi DOM Website

Untuk menemukan class CSS yang tepat (sebagaimana didokumentasikan di Section 12), dilakukan **inspeksi langsung** ke halaman web `titc.or.id` dengan langkah-langkah berikut:

#### Langkah 1: Akses Halaman Login FCOM

1. Buka browser (Chrome/Brave) dan navigasi ke `https://titc.or.id/portal/`.
2. Jika belum login, halaman akan otomatis redirect ke `https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal`.
3. Halaman ini menampilkan form login Fluent Community (bukan form login WordPress bawaan).

#### Langkah 2: Login ke Website

1. Masukkan email/username dan password di form login FCOM.
2. Klik tombol "Login" / "Sign In".
3. Setelah login berhasil, browser akan redirect ke `/portal/` (halaman utama komunitas).

#### Langkah 3: Navigasi ke Halaman Space

1. Buka URL `https://titc.or.id/portal/space/{slug}/home` (contoh: `https://titc.or.id/portal/space/update/home`).
2. Halaman Space akan tampil dengan semua elemen navigasi web (header, sidebar, bottom nav).

#### Langkah 4: Inspeksi DOM dengan Chrome DevTools

1. Klik kanan pada halaman → pilih **"Inspect"** (atau tekan `F12`).
2. Gunakan **"Select an element"** tool (ikon panah kiri atas di DevTools) lalu klik pada setiap elemen navigasi untuk melihat class name-nya.
3. Catat semua class CSS dari:
   - **Menu atas**: Klik pada bar navigasi paling atas → lihat class di panel Elements.
   - **Sidebar kiri**: Klik pada panel di sisi kiri yang berisi daftar space → lihat class.
   - **Bottom nav (mode mobile)**: Resize browser ke lebar ≤500px, lalu klik pada bar navigasi bawah.
   - **Hamburger button**: Klik pada ikon ≡ yang muncul di mode mobile.
4. Untuk memvalidasi, jalankan JavaScript berikut di Console:
   ```javascript
   // Cari semua elemen yang mengandung "fcom" di class-nya
   JSON.stringify(Array.from(document.querySelectorAll('[class*="fcom"]'))
     .map(el => el.tagName + '.' + el.className).slice(0, 30))
   
   // Cari semua elemen navigasi
   JSON.stringify(Array.from(document.querySelectorAll(
     'nav, header, footer, aside, [class*="sidebar"], [class*="menu"], [class*="header"], [class*="footer"], [class*="nav"]'))
     .map(el => el.tagName + '.' + el.className).slice(0, 30))
   ```
5. Untuk melihat tampilan mobile, resize DevTools ke viewport 375×812 menggunakan **Device Toolbar** (Ctrl+Shift+M).

#### Langkah 5: Uji CSS Injection di Console

Sebelum memasukkan CSS ke dalam kode Flutter, uji dulu langsung di Console DevTools:
```javascript
var style = document.createElement('style');
style.innerHTML = `.fcom_top_menu, .spaces, .fcom_mobile_menu, .fcom_space_opener_btn { display: none !important; }`;
document.head.appendChild(style);
```
Jika elemen-elemen navigasi hilang dan hanya konten Space yang tersisa, berarti selector CSS sudah benar.

> [!TIP]
> **Tips Inspeksi Cepat**: Jika perlu menemukan selector baru di masa depan, cara paling cepat adalah login ke website lalu jalankan script JavaScript di atas di Console. Hasilnya bisa langsung di-copy ke dalam kode `SpaceWebViewScreen`.

### Detail Alur Login — Terverifikasi dari Inspeksi Langsung

Berikut adalah alur login yang sudah terverifikasi bekerja, berdasarkan inspeksi langsung terhadap form HTML dan network request di website:

#### Step 1: Fetch Halaman Auth (GET)
```
GET https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal
Headers:
  User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ...
  Referer: https://titc.or.id/portal/
```
**Tujuan**: Mendapatkan HTML yang mengandung `_fcom_login_nonce` (token keamanan CSRF).
**Ekstraksi Nonce**: Parse HTML body dengan regex:
```dart
RegExp(r'name="_fcom_login_nonce"\s+value="([^"]+)"')
```
**Simpan Cookies**: Ambil semua `Set-Cookie` headers dari response ini (biasanya berisi session cookies awal).

#### Step 2: POST Login
```
POST https://titc.or.id/login/
Content-Type: application/x-www-form-urlencoded
Headers:
  Cookie: wordpress_test_cookie=WP+Cookie+check;{cookies_dari_step_1}
  User-Agent: Mozilla/5.0 ...
  Referer: https://titc.or.id/portal/

Body (form-encoded):
  log={email_atau_username}
  pwd={password}
  action=fcom_user_login_form
  _fcom_login_nonce={nonce_dari_step_1}
  wp-submit=Login
  redirect_to=/portal
  rememberme=forever
  testcookie=1
```

**Response Sukses**: Status `302 Redirect` + header `Set-Cookie` yang berisi `wordpress_logged_in_{hash}=...`.
**Response Gagal**: Status `200` dengan HTML yang berisi pesan error di body.

#### Step 3: Simpan Cookie & Fetch Nonce REST API
Setelah login berhasil:
1. **Merge cookies**: Gabungkan cookies dari Step 1 dan Step 2.
2. **Simpan ke `flutter_secure_storage`** dengan key `wp_cookies`.
3. **Fetch REST Nonce**: GET `/portal/` dengan cookies, lalu ekstrak `rest_nonce` dari HTML:
   ```dart
   RegExp(r'"rest_nonce"\s*:\s*"([^"]+)"')  // atau
   RegExp(r'wp\.apiFetch\.use\(\s*wp\.apiFetch\.createNonceMiddleware\(\s*["\x27]([^"\x27]+)')
   ```
4. **Fetch Profil User**: GET `/wp-json/wp/v2/users/me` dengan header `X-WP-Nonce` untuk mendapatkan nama, slug, dan avatar.

### Detail Alur Register (Signup) — Terverifikasi dari Inspeksi Langsung

Pendaftaran menggunakan **2-Step Verification** (Email OTP):

#### Step 1: Fetch Halaman Register (GET)
```
GET https://titc.or.id/portal/?fcom_action=auth&redirect_to=/portal&form=register
```
**Ekstraksi Nonce**: Parse HTML body dengan regex:
```dart
RegExp(r'name="_fcom_signup_nonce"\s+value="([^"]+)"')
```

#### Step 2: POST Data Registrasi
```
POST https://titc.or.id/wp-admin/admin-ajax.php
Content-Type: application/x-www-form-urlencoded

Body (form-encoded):
  action=fcom_user_registration
  full_name={nama_lengkap}
  email={email}
  username={username}
  password={password}
  conf_password={password}
  terms=on
  register=yes
  _fcom_signup_nonce={nonce_dari_step_1}
  redirect_to=/portal
```

**Response Sukses (Tahap 1)**: JSON berisi `verifcation_html` (typo "verifcation" memang dari plugin FCOM, bukan "verification") dan `__two_fa_signed_token`.
**Ekstraksi Token 2FA**:
```dart
RegExp(r'"__two_fa_signed_token"\s*value="([^"]+)"')  // atau
RegExp(r'__two_fa_signed_token[^>]*value="([^"]+)"')
```

#### Step 3: POST Kode Verifikasi Email (OTP)
Setelah user memasukkan kode OTP dari emailnya:
```
POST https://titc.or.id/wp-admin/admin-ajax.php
Content-Type: application/x-www-form-urlencoded

Body (form-encoded):
  action=fcom_user_registration
  __two_fa_signed_token={token_dari_step_2}
  _email_verification_code={kode_6_digit_dari_email}
```

**Response Sukses**: JSON berisi `redirect_url` dan `Set-Cookie` header berisi `wordpress_logged_in`.
**Response Gagal**: JSON berisi `message` error (misalnya "Kode verifikasi salah").

> [!WARNING]
> **Perhatian pada Typo Plugin FCOM**: Field `verifcation_html` (bukan `verification_html`) di response adalah **typo resmi dari plugin Fluent Community**. Jangan "perbaiki" typo ini di kode Dart karena itu memang string asli yang direturn oleh server. Jika developer FCOM memperbaiki typo ini di versi mendatang, regex ekstraksi perlu diperbarui.

### Penyimpanan Sesi & Handling App Restart

| Item | Tempat Simpan | Key | Keterangan |
|---|---|---|---|
| Cookie WordPress | `flutter_secure_storage` | `wp_cookies` | Seluruh cookie string (termasuk `wordpress_logged_in`) |
| Email User | `flutter_secure_storage` | `wp_user_email` | Email yang dipakai login |
| Nama User | `flutter_secure_storage` | `wp_user_name` | Nama dari profil WP |
| Slug User | `flutter_secure_storage` | `wp_user_slug` | Slug profil FCOM (untuk upload avatar) |
| Avatar URL | `flutter_secure_storage` | `wp_user_avatar` | URL foto profil terbaru |
| Joined Spaces | `SharedPreferences` | `joined_spaces` | List slug space yang sudah di-join (cache lokal) |

**Pada `AuthService.init()` (saat app start/restart)**:
1. Muat semua data dari `flutter_secure_storage`.
2. Jika cookies ada → fetch nonce baru dari `/portal/`.
3. Jika fetch nonce berhasil → fetch profil user terbaru.
4. Jika fetch nonce **gagal** → **JANGAN hapus cookies/logout**. Bisa jadi jaringan lambat. Biarkan user tetap login dengan data cache.
5. `app.dart` mengecek `AuthService.isLoggedIn` → jika `true`, langsung ke `MainShell()`.

## 11. Integrasi WebView Halaman Space (Fluent Community)

Untuk menyajikan forum detail space dengan performa optimal dan navigasi native, halaman detail Space menggunakan WebView (`SpaceWebViewScreen`) dengan penyesuaian CSS dan JavaScript dinamis:

### 11.1 Penyesuaian Layout DOM & CSS Injection
Supaya WebView terasa menyatu dengan aplikasi native Flutter, elemen-elemen web dibersihkan melalui CSS Injection (`_injectScript`):
- **Menghilangkan Top/Bottom Nav Bawaan Web**: Kelas CSS `.fcom_top_menu` dan `.fcom_mobile_menu` disembunyikan.
- **Hiding Sidelist / Sidebar Kiri**: `.spaces`, `.space_contents`, dan `#fluent_community_sidebar_menu` di-hide.
- **Responsivitas Layout Feed & Right Sidebar**:
  - Parent `.el-container` diubah menjadi `flex-direction: column !important` agar main feed (`.feed_layout`) dan right sidebar (`ASIDE.el-aside.fcom_resp_side` berisi widget About & Recent Space Activities) mengalir secara vertikal ke bawah, bukan horizontal (mencegah tumpeng tindih layout).
  - Main feed dan sidebar dibuat `width: 100%` dengan `position: static` dan `order: 10` untuk sidebar agar berada di bawah feed utama.

### 11.2 Penanganan Double Header & Bridge Opsi 3-Dot (⋮)
- **Hiding Container Judul Web**: Header asli di WebView (`.fhr_content_layout_header` yang membungkus teks judul space, emoji, dan menu navigation desktop `nav.fcom_desktop_only`) disembunyikan menggunakan CSS/JS dengan mengurangi tingginya menjadi 0 (`height: 0`, `overflow: visible`, `border: none`, `box-shadow: none`, `background: transparent`). Ini mencegah terjadinya "double header" karena aplikasi sudah menggunakan AppBar Flutter biru di bagian atas.
- **Implementasi Bridge Tombol 3-Dot (⋮)**:
  - Tombol 3-dot di AppBar Flutter dihubungkan ke tombol menu asli di webview (`BUTTON.fcom_dot_menu` yang memiliki atribut `el-tooltip`).
  - Saat tombol 3-dot Flutter ditekan, ia mengirimkan perintah JavaScript untuk memaksa tombol asli di webview mendapatkan event `mouseenter` dan `click`:
    ```javascript
    var dotBtn = document.querySelector('.fcom_dot_menu');
    dotBtn.style.setProperty('opacity', '1', 'important');
    dotBtn.style.setProperty('pointer-events', 'auto', 'important');
    dotBtn.click();
    ```
  - Karena container aslinya disembunyikan (berukuran 0px), koordinat posisi menu dari Element Plus tooltip/popover akan terganggu. Oleh karena itu, script mendeteksi kemunculan menu `.el-dropdown-menu` di `<body>` dan memaksa koordinat posisinya secara mutlak (`position: fixed; top: 10px; right: 10px; z-index: 999999; display: block; opacity: 1`) tepat di bawah/pojok kanan atas layar agar mudah diklik pengguna.

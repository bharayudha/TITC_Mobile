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

### 5.7 Login
- Autentikasi menggunakan form action `login` yang mengembalikan Cookie WordPress (`wordpress_logged_in`).
- Disimpan lokal dengan `flutter_secure_storage`.
- Signup menggunakan alur 2-Step (Submit Data -> Verifikasi Kode Email 2FA).

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
3. **Penyimpanan Sesi**: Cookie `wordpress_logged_in` yang didapat dari Set-Cookie disimpan menggunakan `flutter_secure_storage` lalu disisipkan ke header `Cookie` di setiap request ke `/fluent-community/v2/`.

> [!IMPORTANT]
> **Catatan Penting Proteksi Firewall/Anti-Bot**: 
> Semua *request* HTTP (baik GET data maupun POST login/register) WAJIB menyertakan header `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36` dan `Referer: https://titc.or.id/portal/`. Jika menggunakan *User-Agent* default Dart/Flutter (seperti `TITC-Mobile-App/1.0`), *request* akan diblokir dengan status `401/403 Forbidden` oleh sistem anti-DDOS / WordFence / LiteSpeed yang berjalan di server.

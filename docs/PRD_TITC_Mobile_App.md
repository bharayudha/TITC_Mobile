# PRD — Aplikasi Mobile TITC Indonesia

## 1. Ringkasan Produk

Aplikasi mobile Android (dan iOS di fase berikutnya) yang menampilkan konten dari website WordPress **titc.or.id** dengan dua jenis pengalaman:

1. **Menu Shortcut** — ikon-ikon di halaman utama yang membuka halaman WordPress publik (misal `titc.or.id/toefl-itp`, `titc.or.id/jadwal`) lewat WebView, dengan tampilan CSS yang disesuaikan untuk layar mobile.
2. **Forum/Komunitas Native** — satu menu khusus yang mengarah ke fitur komunitas (`titc.or.id/portal`, berbasis plugin **BuddyBoss Platform**), tapi tampilannya **dibangun ulang secara native** (bukan WebView) menggunakan React + Capacitor, dengan data ditarik dari WordPress REST API / BuddyBoss REST API.

Prinsip inti: **WordPress + BuddyBoss tetap menjadi satu-satunya sumber data (single source of truth)**. Aplikasi mobile tidak menyimpan data forum sendiri — semua post, komentar, pesan, dan member data tetap tersimpan dan tersinkron di database WordPress yang sama dengan versi web.

## 2. Tujuan

- Memberi pengalaman mobile yang nyaman (native-like) untuk fitur komunitas TITC.
- Tidak mengubah/mengganggu tampilan desktop/browser dari website WordPress yang sudah berjalan.
- Notifikasi realtime (push notification) untuk aktivitas forum.
- Siap disubmit ke Google Play Store dalam waktu 30 hari (lihat dokumen Timeline terpisah).

## 3. Tech Stack

| Layer | Teknologi | Alasan |
|---|---|---|
| Frontend UI | **React** (build jadi static HTML/JS/CSS) | Tim sudah familiar, komponen reusable, cocok dibungkus Capacitor |
| Mobile Wrapper | **Capacitor** | Membungkus React app jadi APK/AAB Android asli, mendukung WebView native untuk menu shortcut |
| Data Source Utama | **WordPress REST API** (`/wp-json/wp/v2/`) | Untuk halaman/post publik |
| Data Forum | **BuddyBoss REST API** (`/wp-json/buddyboss/v1/`) | Untuk Activity Feed, Groups, Members, Messages |
| Autentikasi | **Application Password** (development/testing) → **JWT Authentication for WP REST API** (produksi, per-user) | Application Password untuk koneksi awal/testing; JWT untuk login user individual di aplikasi |
| Backend Tambahan | **Node.js + Express** (atau **Firebase Cloud Functions** sebagai alternatif serverless) | Menjembatani trigger notifikasi ke Firebase; tidak menyimpan data forum, murni pass-through/logic tambahan |
| Push Notification | **Firebase Cloud Messaging (FCM)** | Satu-satunya jalur resmi push notification Android |
| Version Control | **GitHub** (private repo) | Kolaborasi tim |
| Build Target | Android APK/AAB (fase 1), iOS (fase berikutnya) | Sesuai scope 30 hari |

## 4. Arsitektur Sistem (Alur Data)

```
[ React App (dibungkus Capacitor) ]
        |
        |  1. Menu Shortcut → WebView langsung ke halaman WordPress
        |     (titc.or.id/toefl-itp, /jadwal, dst — CSS mobile-only disuntik via Customizer)
        |
        |  2. Menu Forum → fetch data via REST API
        v
[ WordPress + BuddyBoss Platform + LearnDash (di hosting perusahaan) ]
        |
        |  Trigger saat ada activity baru (post/comment/message)
        v
[ Backend Tambahan (Node.js/Express atau Firebase Functions) ]
        |
        |  Panggil FCM untuk kirim push notification
        v
[ Firebase Cloud Messaging ]
        |
        v
[ HP User — Notifikasi masuk ]
```

Catatan: Backend tambahan TIDAK menyimpan salinan data forum. Perannya murni sebagai "penerus sinyal" dari WordPress ke Firebase.

## 5. Struktur Fitur & Layar (Screens)

### 5.1 Halaman Utama (Home)
- Grid menu/ikon sesuai desain Figma.
- Setiap ikon punya `type`: `webview` (buka URL WordPress biasa) atau `native` (buka layar native Forum).

### 5.2 Menu Shortcut (WebView)
- Layar generik yang menerima parameter URL, contoh: `toefl-itp`, `jadwal`, `info`.
- WebView load `https://titc.or.id/{slug}` dengan header custom (misal `X-App-Client: titc-mobile`) supaya WordPress bisa mendeteksi request dari aplikasi dan menyajikan CSS mobile-only.

### 5.3 Forum — Feed
- List activity terbaru (post, like, comment).
- Data: `GET /wp-json/buddyboss/v1/activity`
- Aksi: like, comment (POST ke endpoint activity/comment).

### 5.4 Forum — Groups/Spaces
- Daftar grup yang bisa diikuti user.
- Data: `GET /wp-json/buddyboss/v1/groups`
- Aksi: join/leave group, lihat diskusi dalam grup.

### 5.5 Forum — Members
- Daftar anggota komunitas + profil dasar.
- Data: `GET /wp-json/buddyboss/v1/members`

### 5.6 Forum — Messages (Chat)
- Chat pribadi antar user.
- Data: `GET /wp-json/buddyboss/v1/messages/{thread_id}`
- Update berkala (polling tiap beberapa detik) untuk kesan realtime, dilengkapi push notification untuk pesan saat aplikasi tertutup.

### 5.7 Login
- Form login (username/password WordPress) → autentikasi via JWT → simpan token secara aman di penyimpanan lokal aplikasi (bukan localStorage biasa; gunakan penyimpanan aman native seperti Capacitor Preferences/Secure Storage).

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
- Konfirmasi REST API BuddyBoss & LearnDash aktif dan bisa diakses dari luar (tidak diblokir plugin security).
- Application Password sudah digenerate untuk keperluan testing awal.
- Firebase project sudah dibuat, `google-services.json` sudah didapat untuk dimasukkan ke project Android.
- Daftar final menu shortcut beserta URL tujuan masing-masing.
- Desain Figma final untuk seluruh layar (Home, Feed, Groups, Members, Messages, Login).

## 9. Referensi Dokumen Terkait

- `Laporan_Kebutuhan_Teknis.docx` — daftar lengkap akses/data yang diminta ke perusahaan.
- `Timeline_Pengembangan_Aplikasi_Mobile_TITC.docx` — jadwal kerja 30 hari per anggota tim.

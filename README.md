# TITC Indonesia™ Mobile Application

Aplikasi Mobile Resmi **TITC Indonesia™** — Lembaga Penyedia Tes TOEFL ITP® & TOEFL iBT® Resmi Tersertifikasi **Educational Testing Service (ETS)** di bawah naungan *One Stop English Education Yogyakarta* (Partner Resmi IIEF & ITC).

Aplikasi ini dibangun menggunakan arsitektur hybrid modern: **React + Capacitor (Android Native Wrapper)** dan **Node.js / Express Backend**, terhubung langsung (*single source of truth*) dengan server WordPress & Portal Komunitas `https://titc.or.id`.

---

## 🏛️ Profil Singkat TITC Indonesia™

- **Nama Lembaga**: TITC Indonesia™ (*One Stop English Education*)
- **Sertifikasi**: Authorized Test Center Partner Resmi ETS (Educational Testing Service), IIEF, & ITC
- **Layanan Utama**: Penyelenggaraan Tes TOEFL ITP® Online, TOEFL iBT® Home Edition, TOEIC® Resmi, serta Pembekalan Beasiswa (LPDP, AAS, BUMN, CPNS)
- **Pendiri**: Heri Setio A, S.Pd., M.I.Kom.
- **Lokasi**: Sedayu, Bantul, Daerah Istimewa Yogyakarta, Indonesia
- **Website**: [https://titc.or.id](https://titc.or.id) | [https://titc.or.id/portal/](https://titc.or.id/portal/)

---

## 📁 Struktur Direktori Proyek

```text
titc_mobile/
├── frontend/              # Aplikasi Mobile UI (React + Vite + Capacitor Android)
│   ├── src/
│   │   ├── components/    # Komponen UI Portal (Header, Tabs, QuickChips, HeroBanner, Drawer, Sidebar)
│   │   ├── pages/         # Halaman Utama (Home, WebViewPage, Feed, Groups, Members, Messages, Login)
│   │   ├── services/      # Layanan API (WordPress REST API, Activity, Auth, Groups, Members)
│   │   └── App.jsx        # Routing utama & Hardware Back Button Listener
│   └── android/           # Proyek Native Android Studio (Capacitor Bridge)
├── backend/               # Server Node.js/Express (FCM Push Notification & WP Pass-through)
├── docs/                  # Dokumen PRD, Spesifikasi Teknis, & Timeline 30 Hari
├── .gitignore             # Git ignore global
└── README.md              # Dokumentasi utama proyek
```

---

## 🛠️ Tech Stack & Arsitektur

- **Frontend App**: React 19 (Vite), Lucide Icons, Capacitor 7 (Android Native Bridge)
- **Backend Service**: Node.js, Express, Firebase Admin SDK (Push Notification FCM)
- **Single Source of Truth**: WordPress REST API (`/wp-json/wp/v2/`), Fluent Community REST API (`/wp-json/fluent-community/v2/`)
- **Navigasi Mobile**: Tombol Back Header Visual & Hardware Back Button Handler (`@capacitor/app`)

---

## 🚀 Panduan Memulai Development

### 1. Jalankan Frontend (React + Vite)
```bash
cd frontend
npm install
npm run dev
```

### 2. Sinkronkan ke Android Studio
```bash
cd frontend
npm run build
npx cap copy android
npx cap open android
```

### 3. Jalankan Backend Server
```bash
cd backend
npm install
npm run dev
```

---

## 📄 Dokumentasi Terkait

Seluruh dokumen teknis dan kebutuhan proyek berada pada folder [`docs/`](./docs/):
- [`docs/PRD_TITC_Mobile_App.md`](./docs/PRD_TITC_Mobile_App.md) — Product Requirement Document (PRD)
- `Laporan_Kebutuhan_Teknis.docx` — Dokumen Kebutuhan Akses & API
- `Timeline_Pengembangan_Aplikasi_Mobile_TITC.docx` — Timeline Kerja 30 Hari

--- 

## Struktur Folder Frontend (Flutter)

Struktur direktori ini dirancang untuk memisahkan antara UI, logika bisnis, dan integrasi API 
agar lebih modular, mudah di-*maintain*, dan aman.

```text
frontend/
├── android/                  → project Android native (auto-generate, jangan diedit manual)
├── ios/                      → project iOS native (auto-generate, jangan diedit manual)
│
├── assets/
│   ├── images/               → logo, gambar background, ilustrasi
│   └── icons/                → ikon custom (kalau tidak pakai icon pack bawaan)
│
├── lib/                      → SEMUA kode Dart ada di sini
│   ├── main.dart             → entry point aplikasi (jangan taruh logic di sini)
│   ├── app.dart              → setup MaterialApp, tema warna/font, routing awal
│   │
│   ├── constants/            → nilai tetap yang dipakai di banyak tempat
│   │   ├── api_endpoints.dart      → base URL WordPress & BuddyBoss, path tiap endpoint
│   │   ├── app_colors.dart         → kode warna brand TITC (biar tidak hardcode di tiap file)
│   │   └── app_text_styles.dart    → gaya teks standar (judul, subjudul, dst)
│   │
│   ├── models/               → BENTUK data (bukan logic), satu file per jenis data
│   │   ├── user_model.dart
│   │   ├── space_model.dart
│   │   ├── course_model.dart
│   │   ├── member_model.dart
│   │   └── message_model.dart
│   │
│   ├── services/               → SEMUA kode yang berkomunikasi ke API/server
│   │   ├── api_client.dart          → setup dasar http/dio, header, error handling umum
│   │   ├── auth_service.dart        → login, register, logout
│   │   ├── spaces_service.dart      → ambil data Spaces & Membership Areas
│   │   ├── courses_service.dart     → ambil data Courses & sub-kategorinya
│   │   ├── members_service.dart     → ambil daftar member
│   │   ├── messages_service.dart    → kirim/ambil pesan chat
│   │   ├── token_storage.dart       → simpan & ambil token login secara aman
│   │   └── firebase_messaging_service.dart → push notification
│   │
│   ├── screens/                → SEMUA halaman (UI penuh 1 layar), dikelompokkan per fitur
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart          → Scaffold utama + Bottom Nav + Drawer
│   │   ├── spaces/
│   │   │   ├── spaces_list_screen.dart   → daftar: Free Placement Test, Institutional Prep, dst
│   │   │   └── space_detail_screen.dart  → isi konten 1 space
│   │   ├── courses/
│   │   │   ├── courses_list_screen.dart  → daftar: 4 Hours Intensive, 3 Meeting Courses, dst
│   │   │   └── course_detail_screen.dart → isi materi 1 course
│   │   ├── members/
│   │   │   └── members_list_screen.dart  → daftar nama member
│   │   ├── preparation_test/
│   │   │   └── preparation_test_webview_screen.dart → WebView ke situs eksternal
│   │   └── messages/
│   │       ├── messages_list_screen.dart → daftar percakapan
│   │       └── chat_detail_screen.dart   → isi 1 percakapan
│   │
│   ├── widgets/                → komponen KECIL yang dipakai ULANG di banyak screen
│   │   ├── bottom_nav_bar.dart
│   │   ├── top_app_bar.dart          → search, notifikasi, ikon profil
│   │   ├── side_drawer.dart          → menu hamburger (Membership Areas, TOEFL Preparation, dst)
│   │   ├── chat_fab_button.dart      → tombol chat bubble mengambang
│   │   ├── space_card.dart
│   │   ├── course_card.dart
│   │   ├── member_tile.dart
│   │   ├── chat_bubble.dart
│   │   ├── loading_indicator.dart
│   │   └── error_view.dart
│   │
│   └── routes/
│       └── app_router.dart      → daftar semua named route aplikasi
│
├── test/                     → unit test & widget test
├── pubspec.yaml               → daftar package/dependency
├── .gitignore
└── README.md                  → dokumentasi project
```

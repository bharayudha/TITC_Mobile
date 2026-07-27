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

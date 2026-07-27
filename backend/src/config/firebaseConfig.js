import admin from 'firebase-admin';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serviceAccountPath = path.resolve(__dirname, '../../firebase-service-account.json');

const adminApp = admin.default || admin;
const apps = adminApp.apps || [];

let firebaseApp = null;

if (!apps.length) {
  if (fs.existsSync(serviceAccountPath)) {
    try {
      const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
      firebaseApp = adminApp.initializeApp({
        credential: adminApp.credential.cert(serviceAccount)
      });
      console.log('[Firebase Admin] Berhasil diinisialisasi menggunakan firebase-service-account.json');
    } catch (err) {
      console.error('[Firebase Admin Error] Gagal membaca firebase-service-account.json:', err.message);
    }
  } else {
    console.warn(
      '[Firebase Admin Warning] File firebase-service-account.json tidak ditemukan di folder backend.\n' +
      'Silakan unduh dari Firebase Console (Project Settings > Service Accounts) dan letakkan di folder backend/'
    );
  }
} else {
  firebaseApp = adminApp.app();
}

export default adminApp;

import admin from '../config/firebaseConfig.js';

export async function sendPushNotification(userToken, title, body, data = {}) {
  const apps = admin.apps || [];
  if (!apps.length) {
    throw new Error(
      'Firebase Admin SDK belum diinisialisasi. Pastikan file firebase-service-account.json sudah ada.'
    );
  }

  const message = {
    token: userToken,
    notification: { title, body },
    data: Object.keys(data).reduce((acc, key) => {
      acc[key] = String(data[key]);
      return acc;
    }, {})
  };

  const response = await admin.messaging().send(message);
  return response;
}

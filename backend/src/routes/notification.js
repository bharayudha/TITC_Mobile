import express from 'express';
import { sendPushNotification } from '../services/firebaseService.js';

const router = express.Router();

// Endpoint dipanggil WordPress saat ada aktivitas baru
router.post('/trigger', async (req, res) => {
  try {
    const { userToken, title, body, data } = req.body;

    if (!userToken || !title || !body) {
      return res.status(400).json({ 
        error: 'userToken, title, dan body wajib diisi' 
      });
    }

    const result = await sendPushNotification(userToken, title, body, data);
    res.json({ success: true, result });
  } catch (error) {
    console.error('Gagal kirim notifikasi:', error.message);
    res.status(500).json({ error: error.message || 'Gagal mengirim notifikasi' });
  }
});

export default router;

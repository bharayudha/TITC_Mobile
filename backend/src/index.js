import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'TITC Mobile Backend API is running' });
});

// Placeholder FCM Push Notification Endpoint
app.post('/api/notifications/trigger', (req, res) => {
  const { title, body, topic } = req.body;
  // TODO: Integrate Firebase Admin SDK / FCM API
  res.json({
    success: true,
    message: 'Notification trigger received',
    data: { title, body, topic }
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

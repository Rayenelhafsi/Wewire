const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');
const cors = require('cors'); // ✅ Add this

// Load service account key
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
const PORT = process.env.PORT || 3000;

// ✅ Enable CORS for all routes
app.use(cors());
app.use(bodyParser.json());

app.post('/sendNotification', async (req, res) => {
  const { token, title, body } = req.body;

  if (!token || !title || !body) {
    return res.status(400).send('Missing token, title, or body');
  }

  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ Successfully sent:', response);
    res.status(200).send('Notification sent successfully');
  } catch (error) {
    console.error('❌ Error sending message:', error);
    res.status(500).send('Error sending notification');
  }
});

app.listen(PORT, () => {
  console.log(`Notification server running on port ${PORT}`);
});

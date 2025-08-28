const admin = require("firebase-admin");
const express = require('express');
const cors = require('cors'); // Import CORS

const app = express();
app.use(cors()); // Enable CORS for all routes
app.use(express.json()); // Middleware to parse JSON bodies

// Load service account key
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Function to send push notification
async function sendPushNotification(token, title, body) {
  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("✅ Successfully sent notification to:", token.substring(0, 20) + "...");
    console.log("Title:", title);
    console.log("Body:", body);
  } catch (error) {
    console.error("❌ Error sending message to", token.substring(0, 20) + "...", ":", error.message);
  }
}

// API endpoint
app.post('/api/sendNotification', (req, res) => {
  const { token, title, body } = req.body;

  if (!token || !title || !body) {
    return res.status(400).send("❌ Usage: Provide token, title, and body in the request body.");
  }

  sendPushNotification(token, title, body)
    .then(() => res.status(200).send("✅ Notification sent successfully."))
    .catch((error) => {
      console.error(error);
      res.status(500).send("❌ Error sending notification.");
    });
});

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

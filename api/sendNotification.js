
const admin = require("firebase-admin");

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

// Get command line arguments
const args = process.argv.slice(2);

if (args.length < 3) {
  console.error("❌ Usage: node sendNotification.js <token> <title> <body>");
  process.exit(1);
}

const token = args[0];
const title = args[1];
const body = args[2];

// Send the notification
sendPushNotification(token, title, body);

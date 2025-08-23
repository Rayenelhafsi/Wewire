// Import the Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyBfhan6LH7r5TYWHn-7aOGhnPD5HH5GaXY",
  authDomain: "wewire-18bc2.firebaseapp.com",
  projectId: "wewire-18bc2",
  storageBucket: "wewire-18bc2.firebasestorage.app",
  messagingSenderId: "505805164580",
  appId: "1:505805164580:web:330e793dd2337730f548b1"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

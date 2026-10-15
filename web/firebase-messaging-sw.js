importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAGFPkblOwpDT4HERNS90Ofcfvum5jSxbg",
  authDomain: "smart-plant-595ab.firebaseapp.com",
  projectId: "smart-plant-595ab",
  messagingSenderId: "1037719364189",
  appId: "1:1037719364189:web:d44af9e6c0f4c7475de3b4",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  // FCM displays notification payloads automatically. Only display data-only
  // messages here to avoid duplicate notifications.
  if (payload.notification || !payload.data?.title) return;
  return self.registration.showNotification(payload.data.title, {
    body: payload.data.body || '',
  });
});

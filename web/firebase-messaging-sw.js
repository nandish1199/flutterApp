importScripts(
  "https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js",
);

const firebaseConfig = {
  apiKey: "AIzaSyD1jERLWS1ZdmZC_7PhOUZRrbzp3_L83xc",
  authDomain: "elatefit-49091.firebaseapp.com",
  projectId: "elatefit-49091",
  storageBucket: "elatefit-49091.firebasestorage.app",
  messagingSenderId: "120148446375",
  appId: "1:120148446375:web:f296838ef166b2041adf82",
  measurementId: "G-5KQMW60L1V",
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle =
    payload.notification?.title || payload.data?.title || "Water Reminder";
  const notificationOptions = {
    body:
      payload.notification?.body ||
      payload.data?.body ||
      "Time to stay hydrated!",
    icon: "/icons/Icon-192.png",
  };
  return self.registration.showNotification(
    notificationTitle,
    notificationOptions,
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(
      (windows) => {
        const appWindow = windows.find((client) => "focus" in client);
        return appWindow ? appWindow.focus() : self.clients.openWindow("/");
      },
    ),
  );
});

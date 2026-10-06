# ElateFit

## Web push reminders

Water reminder notifications are sent as Firebase Cloud Messaging web push messages.
Local notifications are not used; scheduled reminders are available in the web app.

Before running or deploying:

1. In Firebase project `elatefit-49091`, enable Anonymous Authentication and create
   a Firestore database.
2. Confirm the Firebase Web Push certificate uses the public VAPID key configured
   in `lib/firebase-notification.dart`.
3. Serve the web app over HTTPS (localhost is also supported for development) so
   the browser can register `web/firebase-messaging-sw.js`.
4. Install the Firebase CLI and Node.js 20 or newer, install the functions
   dependencies with `npm --prefix functions install`, then run
   `firebase deploy --only firestore:rules,functions` from the repository root.
   The scheduled Cloud Function runs every minute; deploying it requires the
   Firebase Blaze plan with Cloud Scheduler enabled. The scheduler checks all
   active water-reminder documents each minute, so Firestore reads grow with the
   number of saved reminders.
5. Build and host the Flutter web app with `flutter build web`. The Firebase
   service worker must be hosted at the site root.

Users enable browser notification permission from the Water Intake Reminder
screen. Their schedules and FCM token are stored in their anonymous-authenticated
Firestore user document; Firestore rules prevent access across users.

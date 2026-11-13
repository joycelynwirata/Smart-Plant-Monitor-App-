# Firebase Hosting deployment

This app uses the existing Firebase project **smart-plant-595ab** and its default
Hosting site. No new project is needed.

**Publication awaits owner confirmation.** The current request covers the whole
app, including AI; follow [FULL_DEPLOYMENT.md](FULL_DEPLOYMENT.md). The optional
approval rules in [SECURITY_REVIEW.md](SECURITY_REVIEW.md) are deferred and will
not be activated. The initial deployment preserves the existing firmware and
live rules without requiring a device UID. No live changes have been made.

- Website after deployment: https://smart-plant-595ab.web.app
- Alternate Hosting domain: https://smart-plant-595ab.firebaseapp.com
- Hosting files: `build/web`
- SPA routing: unmatched paths serve `/index.html`
- Deployment scope: Hosting only, with no database, rules, or functions deployment

## Build and redeploy

From the project directory, after reviewing and approving the release:

```sh
flutter build web --release
firebase deploy --only hosting --project smart-plant-595ab
```

Firebase CLI is already installed. The project is selected explicitly in the
command, so there is no need to run `firebase init` or create a project. If the
CLI login expires, run `firebase login --reauth` and sign in to an account that
has access to this project. Do not paste login tokens into source files or chat.

Do not run an unrestricted `firebase deploy`: that can also deploy the local
Firestore rules and functions. The local rules differ from the rules currently
live in the project. This Hosting setup does not change either set of rules.

Hosting serves only compiled web files. Functions source, local secrets, Git
history, firmware, and CLI credentials are not part of the public directory.
Firebase web configuration keys and the web push public key are intentionally
client-visible; Gemini and service-account credentials must remain server-side.
Responses are revalidated to avoid stale entry scripts and notification workers.

## Read-only deployment audit — November 13, 2026

- The existing Hosting site is accessible with the installed Firebase CLI login.
- Email/password sign-in is enabled. Both Hosting domains are already authorized.
- Firestore exists in `nam5`; the app continues using the existing database.
- Realtime Database continues using
  `https://smart-plant-595ab-default-rtdb.firebaseio.com`.
- Flutter Web is configured. The notification worker uses a dedicated push scope
  so it does not compete with Flutter's root service worker.

Two existing cloud issues need an explicit decision before publication:

1. **Live security rules are open.** Firestore allows anyone to read and write
   every document. Realtime Database allows public reads and writes under
   `liveData/plant1` and `history/plant1`, including the manual watering command.
   Hosting-only deployment leaves these permissions unchanged. Do not assume
   the application's login screen protects database access. Changing RTDB rules
   without first checking how the ESP32 authenticates could break the hardware;
   no firmware or rules changes have been made.
2. **The AI backend is not deployed.** The project currently lists no Cloud
   Functions. The app calls `getPlantAdvice`, so Plant Doctor and Sprout AI need
   that backend and its server-side secret configured separately. A Hosting-only
   deployment cannot enable those features. The main README describes backend
   setup, but deploying functions or rules requires separate authorization.

Full signed-in integration testing requires a test account and can write history,
trigger alerts, or control the pump. It is intentionally excluded from the
non-mutating deployment preparation. Browser smoke tests use a fresh signed-out
profile; they do not use the owner's existing browser session.

## After an approved deployment

Preparation checks passed: `flutter analyze --no-pub`, all 20 Flutter tests,
and `flutter build web --release`. The Hosting emulator returned the app for
both `/` and `/dashboard`, served JavaScript with the correct MIME type, and
applied the configured response headers. An isolated Chrome profile rendered
the login screen at desktop and phone sizes and loaded `/dashboard` directly
without runtime exceptions. Flutter and push workers registered in separate
scopes. A scan of `build/web` found no private-key, OAuth-token, or old Gemini
credential patterns. These checks do not substitute for authenticated hardware
or backend testing.

Verify the returned Hosting URL and load the page in a fresh browser tab. Use an
existing test account to check the authenticated dashboard only when hardware and
email side effects are acceptable. Browser notification permission is optional;
notifications also depend on browser support and the existing FCM sender setup.

The app's authenticated dashboard keeps its existing desktop-oriented layout.
Publishing it does not redesign the dashboard or change its hardware protocol.

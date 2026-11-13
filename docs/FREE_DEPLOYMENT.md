# Free deployment plan — current preferred rollout

Firebase Hosting is live at https://smart-plant-595ab.web.app (November 13, 2026).
AI backend is live at https://smart-plant-ai-phi.vercel.app/api/advice.
A real authenticated Gemini response passed on November 13, 2026.
This plan supersedes the paid Cloud Functions
setup in FULL_DEPLOYMENT.md. Do not enable Blaze or deploy any rules.

## Hosting and AI

Keep the Flutter website on Firebase Hosting in existing project
`smart-plant-595ab`, at https://smart-plant-595ab.web.app. Keep Firebase Auth,
Firestore, RTDB, all database paths, and the ESP32 firmware unchanged.

The current Firebase Cloud Function requires Blaze to deploy. Instead, the
optional `functions/api/advice.js` Vercel Node entry point reuses the existing
advice handler, Gemini request, Firebase token verification. It has no database access and needs no Firebase
service-account secret. A per-instance request limiter supplements Gemini quotas. Vercel Hobby is a free option within its usage and eligibility limits.
Vercel Hobby scope `joy-1479` / project `smart-plant-ai` is created and linked. No automatic GitHub
publishing is needed: deploy only the `functions` directory.
Set Vercel project root to `functions`, framework Other, Node 22, no build command.
The API route is `/api/advice`; production deployment protection must permit the
Flutter browser's requests. Firebase ID tokens still protect the endpoint.

Server-only environment variables (never Flutter build flags or git files):

- `GEMINI_API_KEY`: privately enter an existing valid key from a free-tier Gemini
  project. An exposed/revoked old key should be replaced. The ignored local
  functions/.env contains legacy email settings, not a configured Gemini key.
- `GEMINI_MODEL`: configurable, default `gemini-3.5-flash-lite`, which has free
  input/output pricing. The earlier `gemini-2.5-flash` model is configurable too,
  but is deprecated and scheduled to route to 3.5 Flash-Lite December 1, 2026.

Keep the Gemini project's API billing disabled. Hosting on another provider does
not itself upgrade Gemini. Free Gemini quotas are project/account dependent;
a real response with the owner's configured key has passed. Free-tier prompts
may be used by Google to improve products. No paid fallback is implemented.
The app reports quota/upstream failures rather than switching to a paid plan.

For future frontend redeployments from the repository root:

```sh
flutter build web --release
firebase deploy --only hosting --project smart-plant-595ab
```

The working Vercel production URL is now the default in PlantAdviceService;
PLANT_ADVICE_URL remains an optional override. Never use an unrestricted
`firebase deploy`. For backend-only updates, run from `functions`:

```sh
npx vercel deploy --prod --yes --scope joy-1479
```

The existing Production GEMINI_API_KEY stays in Vercel; do not pull it into source.

## Feature findings

| Feature | What this checkout implements |
| --- | --- |
| Registration/login | Existing email/password Firebase Auth; enabled and Hosting domains authorized in prior read-only audit. Registration and login passed local emulator tests. No approval gate enabled. |
| Sensors | RTDB `liveData/plant1`: soilMoisture, light, waterLevel. Live read confirmed compatible fields; timestamp freshness/device online status not certified. |
| Manual watering | Existing waterNow false→200 ms→true sequence. Tested with an anonymous simulated device receiving/resetting it. Real pump must be checked with professor. |
| Automatic watering | No automatic pump command is issued by the Flutter app. Existing ESP32 firmware must implement this autonomously. Firmware was not available for inspection; thresholds, timing, and safety behavior cannot be certified here. |
| Plant status | Dashboard computes status and alerts using current readings and selected profile. Existing client alert timers require an open/running dashboard. |
| Settings | Name/species/location/profile stored per account in Firestore. Changes do not update firmware thresholds. No ESP32 local HTTP API call exists in this checkout. Any separate LAN-only feature needs suitable remote connectivity; Hosting cannot supply it. |
| History charts | Reads each user's own plant history/lightHistory Firestore collections, latest 20 timestamped values. Dashboard records soil changes greater than 1 and light changes greater than 10 while open. It does not import shared RTDB history, backfill prior owners' charts, or record continuously while closed. New accounts initially have empty charts. |
| AI Plant Doctor/Sprout | Shared authenticated backend; server-only key; conversation, sensor context and prompt preserved. Live authenticated Gemini response verified using a temporary registered account; the account was removed afterward. |

No migrations, deletions, firmware edits, live watering commands, IAM changes,
or billing changes have been performed. Hosting was deployed with --only hosting. The proposed broad database-admin
role was rejected by automatic approval review; the free backend was changed to
need no Firebase credentials and no database access instead. Live rules
remain unchanged, including the existing public plant access. Optional stricter
rule files are excluded from this rollout.

## Verification and approval

Existing checks: clean Flutter analyzer, successful release build, 23 Flutter
regressions, seven Auth/Firestore/RTDB workflow tests, and desktop/mobile Hosting
browser smoke tests. Updated backend: 18 passing tests, including shared Gemini
payload and free-host preflight/missing-credential handling. Unit tests mock
Gemini. The deployed backend subsequently passed real CORS, unsigned-request
rejection, Firebase registration/token verification, and a live Gemini response.
The temporary Auth-only account was deleted and no plant records were written.
Vercel source/config paths returned 404. Hobby and Node 22 were confirmed. Live Firebase Hosting passed
desktop/mobile login rendering, SPA deep links, headers and service-worker checks
with no browser runtime exceptions.

Owner approval received: use/link a free Vercel Hobby account, store the Gemini
key privately, and publish the AI endpoint plus Firebase Hosting. No Firebase
runtime credentials or IAM grants are now required. No paid plans or live rule changes are included.
The owner completed login and private key entry. Firebase billing remains
disabled and live rules were rechecked unchanged. Coordinate sensor, manual pump
and autonomous watering checks with the professor.

Sources checked November 13, 2026:

- https://firebase.google.com/docs/functions/get-started (Blaze requirement)
- https://vercel.com/docs/plans/hobby (free plan limits)
- https://vercel.com/docs/functions/runtimes/node-js (Node API functions)
- https://ai.google.dev/gemini-api/docs/pricing (free models and 2.5 deprecation)

## Credential-free Firebase verification

The Vercel endpoint verifies the ID token signature, audience, issuer, and expiry
using Firebase Admin public signing certificates and an explicit project ID. It
then calls Firebase Auth accounts:lookup using that user token and the existing
public Firebase web API key to reject deleted/disabled accounts and invalidated
sessions. It never receives an admin OAuth token or a database credential.
The Gemini secret is the only private runtime environment variable. The local
limiter allows ten calls per user per minute per warm instance; it is not a
distributed quota and resets on cold starts. Gemini free-tier project quotas
remain the global bound. Keep Gemini billing disabled.

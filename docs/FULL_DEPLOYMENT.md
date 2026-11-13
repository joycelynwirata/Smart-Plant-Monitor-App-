# Complete app deployment — simplest existing-firmware rollout

**Latest preference: no paid services. See [FREE_DEPLOYMENT.md](FREE_DEPLOYMENT.md)
for the prepared Firebase Hosting + free external AI backend option. The Blaze
setup below is an alternative only and is not approved.**

**Historical paid-backend alternative; not the active rollout.** The free
Hosting + Vercel deployment is live; see FREE_DEPLOYMENT.md. The project remains
`smart-plant-595ab` and website https://smart-plant-595ab.web.app.

This is the current deployment plan. It supersedes the earlier requirement to
finish device enrollment before publishing. Do not activate the optional draft
security rules as part of this rollout.

## Professor Alonso's workflow

Open the website, register or sign in, go to **My Plant**, and add a plant profile
if the account has none. The existing dashboard, Water Now button, plant settings,
and AI pages then use that account and the existing `plant1` device.

Login/registration pages are unchanged. The default build goes directly from
Firebase sign-in to the existing dashboard. No operator approval, email
verification redesign, device UID enrollment, or firmware update is required for
this initial rollout. The optional approval gate is disabled by default in both
the Flutter build and AI function (`REQUIRE_DEVICE_APPROVAL=false`).

## What works remotely, and what remains conditional

| Feature | Current implementation and deployment status |
| --- | --- |
| Website | Flutter web release and Hosting SPA routing are prepared for the existing site. |
| Registration/sign-in | Existing Firebase email/password provider is enabled; both Hosting domains are authorized. Tested using the local Auth emulator. |
| Live readings | Uses the existing cloud RTDB node `liveData/plant1`, not a LAN HTTP call. A read-only live check confirmed compatible numeric sensor fields. Current values alone do not prove the device is online now. |
| Manual watering | Writes `waterNow=false`, then `true`, to that same RTDB node. The exact sequence was tested with a simulated anonymous ESP32 listener and acknowledgment. Actual pump operation requires the real ESP32 to be online and processing commands; it was not triggered here. |
| Plant settings | Name, species, location, and profile are stored in the signed-in user's Firestore plant document. The existing save/update path is unchanged and was tested in emulators. Each account retains its own profiles. |
| Hardware watering thresholds | The current Flutter settings page does not send those values to the ESP32. Changing a profile affects app logic/AI context; it does not establish a new firmware-control feature. |
| AI Plant Doctor and Sprout | Backend code is ready for deployment, but cloud billing/API setup and a private Gemini key are still required. No paid request has been made. |
| Email/push | Existing client-side EmailJS/FCM integration is retained. Email delivery depends on existing EmailJS account/domain settings; push depends on browser permission and a configured sender. No emails or push messages were sent during preparation. Client timers do not become a 24/7 server alert service merely by using Hosting. |

### ESP32 local HTTP APIs

No ESP32 HTTP address, endpoint, or HTTP call exists in this checkout's plant
settings implementation or the committed version of that file. No such integration
was removed or replaced during preparation.

If a separate firmware/API feature uses a private LAN address, publishing Flutter
on Firebase does not make that address reachable from an arbitrary remote
browser or Cloud Function. Browser mixed-content/CORS/local-network restrictions
can also apply to HTTPS-to-local-HTTP calls. Such a feature would need the exact
API plus suitable network connectivity (for example a managed gateway/VPN) or a
future firmware/cloud-command integration. None has been configured or invented
here. The professor does not need that local API for the current RTDB-based
Water Now button or Firestore-based profile settings.

## Existing firmware and data remain intact

The rollout does **not** deploy Firestore or Realtime Database rules. Therefore
it does not interfere with the ESP32's existing anonymous sign-in, unknown UID,
reading path, or command path, including after restart. Anonymous Auth stays on.
No migration, overwrite, deletion, or firmware modification is planned.

The existing public database permissions remain in effect. They allow more
access than the login UI suggests; this rollout preserves that known limitation
at the owner's request. The stricter local files `firestore.rules` and
`database.rules.json` are future proposals only. An unrestricted `firebase deploy`
would be inappropriate because it could deploy those proposals.

## AI backend setup needed after approval

The last read-only audit found billing disabled, Secret Manager disabled or
unavailable, and no deployed Cloud Functions.

The prepared `getPlantAdvice` function uses Node 22, verifies Firebase ID tokens
including revocation/disabled-user checks, and allows newly registered app
accounts without a separate approval record in the default deployment mode.
Anonymous device accounts cannot use it. Gemini calls remain server-side, with
input/output limits, timeouts, and ten requests per user per minute.

Rate limits now use an atomic transaction under **RTDB `_aiRateLimits/{uid}`**.
The current live RTDB rules already deny client access outside the public
`liveData/plant1` and `history/plant1` nodes. Local tests reproduced those rules and
confirmed clients cannot read/reset the counters, and concurrent requests cannot
bypass the quota. This avoids relying on the currently public Firestore rules
and does not require a rules rollout. The function creates only these new quota
records when invoked; it does not edit plant, sensor, or history records.

Cloud prerequisites requiring approval/input:

1. Enable/link Firebase Blaze billing and authorize the required Cloud
   Functions/build/Secret Manager services and runtime permissions. This can
   incur hosting-backend/API costs; a per-user quota is not a project spending cap.
2. Supply a valid replacement Gemini key privately using Secret Manager:

   ```sh
   firebase functions:secrets:set GEMINI_API_KEY --project smart-plant-595ab
   ```

   Do not paste the key into chat, Flutter source, or a browser build flag. Revoke
   old exposed Gemini credentials through the owning account. No secret values
   were read or stored in the repository during preparation.
3. Keep `REQUIRE_DEVICE_APPROVAL=false` for this initial function deployment.
   `GEMINI_MODEL` defaults to `gemini-3.5-flash-lite`; confirm access/billing for
   that model on the key's project. The runtime account needs Auth checks, RTDB
   counter access, and access to the bound secret. No private key file belongs in
   Hosting.

## Scoped deployment after confirmation

The prepared Flutter release uses the existing project configuration and AI URL.
After the prerequisites and explicit deployment approval:

```sh
flutter build web --release
firebase deploy --only functions:getPlantAdvice,hosting --project smart-plant-595ab
```

Those targets deploy the AI function and public web files, **not rules or
existing data**. Do not add `database` or `firestore:rules` to this command. No
project initialization or new Firebase project is needed.

No deploy command, billing change, secret creation, IAM change, or live database
write has been executed as part of preparation. Once approved, these operations
can be handled here except private billing/key input that requires the owner.
If AI setup remains unavailable, the complete AI-enabled deployment remains
blocked; it will not be represented as finished by publishing Hosting alone.

## Verification

- Clean Flutter analyzer and 23 passing Flutter regression tests.
- Flutter web release builds successfully.
- Twelve passing backend tests cover authenticated access, initial mode without approval,
  anonymous rejection, optional approval mode, input validation, and errors.
- Seven passing local demo Auth/Firestore/RTDB workflow tests exercise registration, sign-in,
  sensor transfer, Water Now delivery to a simulated device, profile/settings
  storage, private quota access, and concurrent quota enforcement.
- Earlier Hosting/Chrome smoke tests passed for desktop/mobile login, SPA deep
  links, response headers, and separate service-worker scopes.
- Live reads verified Auth/provider/domain configuration and sensor field
  compatibility; no real command was sent.

The simulator is not the physical ESP32. Real pump behavior, any unprovided LAN
API, actual EmailJS delivery, and a paid Gemini response cannot be certified from
these checks. Coordinate real watering tests with the professor after deployment.

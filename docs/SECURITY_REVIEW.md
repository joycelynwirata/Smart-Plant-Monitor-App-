# Proposed Firebase security rollout

**Deferred optional plan.** For the current initial rollout, follow
[FULL_DEPLOYMENT.md](FULL_DEPLOYMENT.md). Both Flutter and the AI backend default
to `REQUIRE_DEVICE_APPROVAL=false`, preserving account registration without
enrollment. The stricter rules below must not be deployed as part of that rollout.
AI rate limits now use the already client-protected RTDB `_aiRateLimits` path;
they no longer depend on Firestore quota rules. To activate this proposal later,
both approval flags, verified memberships, and a coordinated rules deployment
would need separate approval.

**Local proposal only. Nothing in this review has been deployed. No live rules,
authentication settings, existing application data, or firmware were changed.**

## What the live audit found

The November 13, 2026 read-only audit confirmed:

- Email/password and Anonymous Authentication are both enabled.
- Firestore currently allows public reads and writes to every document.
- Realtime Database currently allows public reads and writes under
  `liveData/plant1` and `history/plant1`.
- The project has no deployed Cloud Functions. Billing is disabled and the
  Secret Manager API is disabled/unavailable. No secret values were retrieved.

## Minimal proposed permissions

| Identity | Private Firestore account/plant data | Shared device readings | `waterNow` | Sensor writes |
| --- | --- | --- | --- | --- |
| Signed out | Denied | Denied | Denied | Denied |
| Newly registered app account | Own documents only | Denied until approval | Denied until approval | Denied |
| Approved app operator | Own documents only | Allowed | Boolean commands only | Denied |
| Approved ESP32 anonymous UID | Denied | Allowed on existing firmware paths | May read and acknowledge/reset | Allowed on existing firmware paths |
| Any other anonymous UID | Denied | Denied | Denied | Denied |

Firestore ownership is authorization for a user's own private records; it does not
grant access to the physical device. Roles stored in a user's editable profile
have no effect on device authorization. Backend AI quota documents are inaccessible
to all clients. Any path not explicitly allowed by the proposed rules is denied.

The proposed files are `firestore.rules` and `database.rules.json`, referenced
from `firebase.json`. No schema, plant-document IDs, readings, or firmware paths
are renamed. Human operators can update only the `waterNow` Boolean on the shared
Realtime Database node, not replace the node or spoof sensor readings. The device
can still update or replace its normal sensor packet and acknowledge commands.
The ESP32 may preserve a pending `true` command while uploading telemetry, but
cannot create a new `false`-to-`true` command itself; only approved app operators
can do that. Its existing command-reset behavior remains permitted.

## Simple approval for Professor Alonso

The existing login and signup forms are unchanged. He registers normally, or uses
an existing account. After sign-in, an unapproved account sees **Device access
pending**, with its UID and a copy button. It has no shared-device access.

After identity verification and the owner's explicit approval, a trusted project
administrator adds this Boolean in Realtime Database Console:

```text
deviceAccess/plant1/operators/PROFESSOR_AUTH_UID = true
```

The same approval is needed for the owner's app account. Approval changes are
observed live: an approved account can enter the existing dashboard; revoking its
approval removes access. Clients cannot read other users' approvals, list the
approval registry, or write any approvals. Sign-in alone never grants watering
permission. Approvals are scoped to the existing `plant1` device.

The professor can view that shared device and send watering commands. Plant
settings remain under his own account, matching the existing app design. If he
has no saved plant profile, he uses the existing Add Plant flow. This does not
share or overwrite the owner's private plant documents.

Optional admin utility, run from `functions/` with trusted Application Default
Credentials (ADC), never browser credentials:

```sh
npm run device-access -- --uid PROFESSOR_AUTH_UID --role operator
```

That defaults to a read-only preview. Only after explicit approval, the same
command with `--apply` writes that single approval leaf. `--revoke` sets it false.
The utility rejects anonymous app operators and disabled accounts. Firebase CLI
login alone does not necessarily configure ADC; Console approval is the simplest
option if ADC is not already available. No approval command was run against live
data during preparation.

## ESP32 anonymous identity: important limitation

The supplied firmware uses `Firebase.signUp(&config, &auth, "", "")`. Anonymous
Authentication is enabled, but the provider name is not proof that a client is
this ESP32: anyone can request an anonymous account with the public web config.

The secure option requiring **no firmware edit** is to approve the verified
current ESP32 UID separately:

```text
deviceAccess/plant1/devices/VERIFIED_ESP32_AUTH_UID = true
```

The proposed rules require both that exact approval and an anonymous sign-in.
An arbitrary anonymous account cannot acquire device privileges, even if it is
accidentally placed in the human-operator list. An operator cannot grant itself
hardware privileges. The analogous admin preview is:

```sh
npm run device-access -- --uid VERIFIED_ESP32_AUTH_UID --role device
```

The current UID is unknown, and its persistence across restarts is unverified.
Creating a fresh anonymous identity after restart would require approving the
new UID before hardware access resumes. Local tests confirm that a replacement,
unapproved UID is denied. Do not select the newest anonymous account and assume
it is the ESP32; verify its association using existing device logs or another
trusted identification process. The Firebase user list alone does not prove it.

Therefore uninterrupted hardware operation cannot be guaranteed yet. Do not
activate these rules until the real device UID is identified and an enrollment
strategy is agreed. To avoid reapproval on unattended restarts, a future small
firmware authentication change could reuse a dedicated device account rather
than creating anonymous accounts. That would also require a reviewed update to
the proposed device-provider rule. Persistent anonymous-session storage is
another option, but depends on the actual firmware library. Neither change has
been implemented or authorized. Existing `Firebase.begin`, paths, and watering
protocol remain unchanged.

## AI Plant Doctor preparation

The app already sends an ID token to `getPlantAdvice`. The proposed backend now:

- Validates the Firebase ID token, including revocation/disabled-user checking.
- Rejects anonymous identities and registered users without device approval.
- Checks the same protected operator approval used for watering access.
- Stores Gemini credentials only in Secret Manager (`GEMINI_API_KEY`).
- Retains ten requests per user per minute, bounded messages/output, and a timeout.
- Targets Node 22 for its existing first-generation function. Node 24 is not
  supported for that generation in the current runtime support table.
- Uses the configurable `GEMINI_MODEL` parameter, defaulting to
  `gemini-3.5-flash-lite`. The previous 2.5 Flash default is deprecated.

Before AI deployment, the owner must approve enabling billing/Blaze and any
required Google Cloud APIs, creating a replacement Gemini credential, and
storing it as a secret. Confirm model availability and billing on the Gemini
project. Enter the secret privately through the CLI/Console, never in chat,
Flutter source, or a browser build flag. Previously exposed credentials must be
revoked by their owner. No secret has been created, accessed, or replaced here,
and no paid AI request has been made.

Deployment also needs the required Cloud Functions/build services and a runtime
service account authorized to check Firebase Auth revocation, read the RTDB
approval registry, write Firestore quota counters, and access only the bound
Gemini secret. Check those permissions during the approved backend setup; do not
embed a service-account key in the app. No IAM or API-enablement changes were made.

After those approvals, a separate scoped deployment of `getPlantAdvice` is needed;
Hosting-only deployment does not deploy it. A real authenticated AI request must
then be tested with an approved account. Backend tests use mocks and do not prove
Gemini billing/key availability.

## Approval and deployment sequence

Do not execute these steps until explicitly approved:

1. Verify the ESP32 UID and restart behavior. Identify the owner's app UID;
   Professor Alonso can supply his after registration. Review the exact proposed
   rules and the intended operator/device approvals.
2. Add only the new approval metadata under `deviceAccess/plant1`. Preserve all
   existing user, sensor, history, and command data. Confirm the protected registry
   has no existing configuration that would be overwritten.
3. Deploy the reviewed Firestore and Realtime Database rules together. Anonymous
   Auth remains enabled. Check both app and hardware access with the professor;
   do not test a real watering command without coordination.
4. With separate billing/API/secret approval, deploy the AI function and test an
   authorized request. Approvals and quota rules must already be protected.
5. Build the Flutter web release and, after final Hosting approval, deploy only
   Hosting to the existing site.

Steps 2–5 each change live state. They have not been executed. Do not approve the
rules rollout merely on the basis of passing emulator tests while the hardware
UID is unknown.

## Local verification

```sh
flutter analyze --no-pub
flutter test --no-pub
cd functions
npm test
cd ../security-tests
npm ci
npm test
```

Rule tests use only local emulators and the fake `demo-smart-planter` identifier;
this does not create a cloud project. They refuse to run without the expected
localhost emulator addresses. Fixtures and destructive cleanup apply only to that
isolated local test environment, not existing Firebase data. The suite checks
public denial, new/revoked users, approved operator commands, sensor spoofing,
self-approval, provider separation, replacement device UIDs, private ownership,
and quota protection.

Verification passed: clean Flutter analyzer, 23 Flutter tests, 11 backend tests,
10 local security-rule tests, and the Flutter web release build. Live ESP32
authentication and a paid Gemini response remain untested for the reasons above.

Sources: [Realtime Database rule conditions](https://firebase.google.com/docs/database/security/rules-conditions),
[local rule testing](https://firebase.google.com/docs/rules/emulator-suite),
[Cloud Functions runtime support](https://docs.cloud.google.com/functions/docs/runtime-support),
[Gemini model deprecations](https://ai.google.dev/gemini-api/docs/deprecations),
[Firebase function secrets](https://firebase.google.com/docs/functions/config-env).

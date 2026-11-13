"use strict";
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { before, after, test } = require("node:test");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { ref, get, set, update, remove } = require("firebase/database");
const { doc, getDoc, setDoc, updateDoc } = require("firebase/firestore");

// Never connect these tests to a real Firebase project or database.
if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8085" ||
    process.env.FIREBASE_DATABASE_EMULATOR_HOST !== "127.0.0.1:9005") {
  throw new Error("Run npm test to use the isolated demo-project emulators.");
}
let env;
const context = (uid, provider = "password") => env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } });
const db = (uid, provider) => context(uid, provider).database();
const firestore = (uid, provider) => context(uid, provider).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-smart-planter",
    database: { host: "127.0.0.1", port: 9005, rules: readFileSync(path.join(__dirname, "../database.rules.json"), "utf8") },
    firestore: { host: "127.0.0.1", port: 8085, rules: readFileSync(path.join(__dirname, "../firestore.rules"), "utf8") },
  });
  await env.withSecurityRulesDisabled(async (admin) => {
    await set(ref(admin.database()), {
      deviceAccess: { plant1: {
        operators: { owner: true, professor: true, "revoked-user": false, "rogue-anonymous": true },
        devices: { esp32: true, "password-device": true },
      } },
      liveData: { plant1: { soilMoisture: 82, light: 1200, waterLevel: 1, waterNow: false } },
      history: { plant1: { reading1: { soilMoisture: 82 } } },
    });
    await setDoc(doc(admin.firestore(), "users/owner"), { name: "Owner" });
    await setDoc(doc(admin.firestore(), "users/owner/plants/actual-id"), { name: "Lily", profile: "Tropical" });
    await setDoc(doc(admin.firestore(), "_aiRateLimits/owner"), { count: 1 });
  });
});
after(async () => { if (env) await env.cleanup(); });

test("unauthenticated visitors cannot read or write private plant/device data", async () => {
  const visitor = env.unauthenticatedContext();
  await assertFails(get(ref(visitor.database(), "liveData/plant1")));
  await assertFails(set(ref(visitor.database(), "liveData/plant1/waterNow"), true));
  await assertFails(getDoc(doc(visitor.firestore(), "users/owner/plants/actual-id")));
});
test("new or revoked app accounts cannot access the shared planter", async () => {
  for (const uid of ["new-account", "revoked-user"]) {
    await assertFails(get(ref(db(uid), "liveData/plant1")));
    await assertFails(set(ref(db(uid), "liveData/plant1/waterNow"), true));
  }
});
test("approved owner and professor can read sensors and send the exact existing pump command", async () => {
  for (const uid of ["owner", "professor"]) {
    await assertSucceeds(get(ref(db(uid), "liveData/plant1")));
    await assertSucceeds(update(ref(db(uid), "liveData/plant1"), { waterNow: false }));
    await assertSucceeds(update(ref(db(uid), "liveData/plant1"), { waterNow: true }));
    await assertSucceeds(get(ref(db(uid), "history/plant1")));
  }
});
test("operators cannot spoof sensors, replace the device, or send malformed commands", async () => {
  const operator = db("professor");
  await assertFails(set(ref(operator, "liveData/plant1/soilMoisture"), 0));
  await assertFails(set(ref(operator, "liveData/plant1"), { waterNow: true }));
  await assertFails(update(ref(operator, "liveData/plant1"), { waterNow: true, light: 0 }));
  await assertFails(set(ref(operator, "liveData/plant1/waterNow"), "true"));
  await assertFails(remove(ref(operator, "liveData/plant1/waterNow")));
  await assertFails(set(ref(operator, "history/plant1/fake"), { soilMoisture: 0 }));
});
test("nobody can self-approve, approve others, or list device approvals as a client", async () => {
  for (const uid of ["new-account", "owner", "professor"]) {
    await assertFails(set(ref(db(uid), `deviceAccess/plant1/operators/${uid}`), true));
    await assertFails(set(ref(db(uid), "deviceAccess/plant1/operators/someone-else"), true));
    await assertFails(set(ref(db(uid), `deviceAccess/plant1/devices/${uid}`), true));
    await assertFails(get(ref(db(uid), "deviceAccess")));
    await assertFails(get(ref(db(uid), "deviceAccess/plant1/operators/other-user")));
  }
  await assertSucceeds(get(ref(db("professor"), "deviceAccess/plant1/operators/professor")));
});
test("only the allowlisted anonymous device can use the firmware paths", async () => {
  const hardware = db("esp32", "anonymous");
  await assertSucceeds(get(ref(hardware, "liveData/plant1")));
  await assertSucceeds(update(ref(hardware, "liveData/plant1"), { soilMoisture: 70, light: 1500, waterLevel: 1 }));
  await assertSucceeds(set(ref(hardware, "liveData/plant1"), { soilMoisture: 70, light: 1500, waterLevel: 1, waterNow: false }));
  await assertSucceeds(set(ref(hardware, "liveData/plant1/waterNow"), false));
  await assertFails(set(ref(hardware, "liveData/plant1/waterNow"), true));
  await assertSucceeds(set(ref(db("owner"), "liveData/plant1/waterNow"), true));
  await assertSucceeds(update(ref(hardware, "liveData/plant1"), { light: 1400, waterNow: true }));
  await assertSucceeds(set(ref(hardware, "liveData/plant1/waterNow"), false));
  await assertSucceeds(set(ref(hardware, "history/plant1/reading2"), { soilMoisture: 70 }));
  await assertFails(set(ref(hardware, "deviceAccess/plant1/operators/esp32"), true));
  await assertFails(get(ref(db("password-device"), "liveData/plant1")));
});
test("unapproved anonymous identities and a new UID after reboot remain blocked", async () => {
  for (const uid of ["random-anonymous", "esp32-after-reboot", "rogue-anonymous"]) {
    await assertFails(get(ref(db(uid, "anonymous"), "liveData/plant1")));
    await assertFails(set(ref(db(uid, "anonymous"), "liveData/plant1/waterNow"), true));
  }
});
test("registration can save its own account without granting device privileges", async () => {
  await assertSucceeds(setDoc(doc(firestore("new-account"), "users/new-account"), { name: "New account", email: "test@example.invalid", approved: true }));
  await assertFails(get(ref(db("new-account"), "liveData/plant1")));
});
test("users can change their own plant settings and history, but not another user's", async () => {
  await assertSucceeds(updateDoc(doc(firestore("owner"), "users/owner/plants/actual-id"), { profile: "Flowering" }));
  await assertSucceeds(setDoc(doc(firestore("professor"), "users/professor/plants/my-plant"), { name: "Lily", profile: "Tropical" }));
  await assertSucceeds(setDoc(doc(firestore("professor"), "users/professor/plants/my-plant/history/reading"), { soilMoisture: 82 }));
  await assertFails(getDoc(doc(firestore("professor"), "users/owner/plants/actual-id")));
  await assertFails(updateDoc(doc(firestore("professor"), "users/owner/plants/actual-id"), { name: "Hijacked" }));
});
test("hardware identities cannot read Firestore accounts or tamper with AI quotas", async () => {
  await assertFails(setDoc(doc(firestore("esp32", "anonymous"), "users/esp32"), { name: "Hardware" }));
  await assertFails(getDoc(doc(firestore("owner"), "_aiRateLimits/owner")));
  await assertFails(setDoc(doc(firestore("owner"), "_aiRateLimits/owner"), { count: 0 }));
});

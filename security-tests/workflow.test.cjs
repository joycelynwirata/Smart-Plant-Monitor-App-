"use strict";
const { before, after, test } = require("node:test");
const assert = require("node:assert/strict");
const { initializeTestEnvironment, assertFails } = require("@firebase/rules-unit-testing");
const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signInAnonymously, signOut } = require("firebase/auth");
const { getDatabase, connectDatabaseEmulator, ref, set, get, update, onValue, goOffline } = require("firebase/database");
const { getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, updateDoc, collection, addDoc, getDocs, serverTimestamp, terminate } = require("firebase/firestore");
const requireFunctions = require("node:module").createRequire(require.resolve("../functions/package.json"));
const adminApp = requireFunctions("firebase-admin/app");
const adminDb = requireFunctions("firebase-admin/database");
const { consumeAiQuota } = require("../functions/ai-quota");
const { createDeviceAuthorization } = require("../functions/device-authorization");

if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8085" ||
    process.env.FIREBASE_DATABASE_EMULATOR_HOST !== "127.0.0.1:9005" ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== "127.0.0.1:9095") {
  throw new Error("Run npm run test:workflow to use isolated demo emulators only.");
}
const projectId = "demo-smart-planter";
let env, professor, hardware, admin;
const clients = [];
function client(name) {
  const app = initializeApp({ projectId, apiKey: "emulator-only-api-key", databaseURL: `https://${projectId}.firebaseio.com` }, name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9095", { disableWarnings: true });
  const database = getDatabase(app);
  connectDatabaseEmulator(database, "127.0.0.1", 9005);
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, "127.0.0.1", 8085);
  const result = { app, auth, database, firestore };
  clients.push(result);
  return result;
}
before(async () => {
  // Reproduce the audited LIVE permissions only inside this fake local project.
  env = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8085, rules: "rules_version = '2'; service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read, write: if true; } } }" },
    database: { host: "127.0.0.1", port: 9005, rules: JSON.stringify({ rules: {
      liveData: { plant1: { ".read": true, ".write": true } },
      history: { plant1: { ".read": true, ".write": true } },
    } }) },
  });
  professor = client("professor-workflow");
  hardware = client("simulated-esp32");
  admin = adminApp.initializeApp({ projectId, databaseURL: `https://${projectId}.firebaseio.com` }, "quota-tests");
});
after(async () => {
  for (const client of clients) {
    await signOut(client.auth);
    goOffline(client.database);
    await terminate(client.firestore);
    await deleteApp(client.app);
  }
  if (admin) await adminApp.deleteApp(admin);
  if (env) await env.cleanup();
}, { timeout: 15000 });

test("professor can register, save a profile, sign out, and sign in again", async () => {
  const registered = await createUserWithEmailAndPassword(professor.auth, "professor@example.invalid", "EmulatorOnlyPassword123!");
  const uid = registered.user.uid;
  await setDoc(doc(professor.firestore, `users/${uid}`), { name: "Professor Alonso", email: registered.user.email });
  await signOut(professor.auth);
  const signedIn = await signInWithEmailAndPassword(professor.auth, "professor@example.invalid", "EmulatorOnlyPassword123!");
  assert.equal(signedIn.user.uid, uid);
  assert.equal((await getDoc(doc(professor.firestore, `users/${uid}`))).data().name, "Professor Alonso");
});
test("existing anonymous firmware path sends sensor data that the professor can read", async () => {
  const signedIn = await signInAnonymously(hardware.auth);
  assert.equal(signedIn.user.isAnonymous, true);
  await set(ref(hardware.database, "liveData/plant1"), { soilMoisture: 82, light: 1250, waterLevel: 1, waterNow: false });
  const data = (await get(ref(professor.database, "liveData/plant1"))).val();
  assert.equal(data.soilMoisture, 82);
  assert.equal(data.light, 1250);
});
test("the exact app watering command is observed and acknowledged by a simulated ESP32", async () => {
  let stop;
  const observed = new Promise((resolve) => {
    stop = onValue(ref(hardware.database, "liveData/plant1/waterNow"), (snapshot) => {
      if (snapshot.val() === true) resolve();
    });
  });
  let timeout;
  try {
    await update(ref(professor.database, "liveData/plant1"), { waterNow: false });
    await new Promise((resolve) => setTimeout(resolve, 200));
    await update(ref(professor.database, "liveData/plant1"), { waterNow: true });
    await Promise.race([observed, new Promise((_, reject) => {
      timeout = setTimeout(() => reject(new Error("Simulated device did not receive command")), 3000);
    })]);
  } finally { stop(); clearTimeout(timeout); }
  await set(ref(hardware.database, "liveData/plant1/waterNow"), false);
  assert.equal((await get(ref(professor.database, "liveData/plant1/waterNow"))).val(), false);
});
test("plant settings and sensor history save under the professor's actual plant ID", async () => {
  const uid = professor.auth.currentUser.uid;
  const plant = await addDoc(collection(professor.firestore, `users/${uid}/plants`), { name: "Lily", species: "Lily", profile: "Tropical", location: "Indoor", createdAt: serverTimestamp() });
  await updateDoc(plant, { name: "Professor's Lily", profile: "Flowering", location: "Outdoor", updatedAt: serverTimestamp() });
  assert.equal((await getDoc(plant)).data().profile, "Flowering");
  await addDoc(collection(plant, "history"), { soilMoisture: 82, timestamp: serverTimestamp() });
  assert.equal((await getDocs(collection(plant, "history"))).size, 1);
  // These are Firestore settings; no request to a LAN HTTP API is simulated.
});
test("new registered accounts pass initial AI authorization; anonymous hardware does not", async () => {
  const authorize = createDeviceAuthorization(async () => { throw new Error("No enrollment should be needed"); }, () => false);
  assert.equal(await authorize({ uid: professor.auth.currentUser.uid, firebase: { sign_in_provider: "password" } }), true);
  assert.equal(await authorize({ uid: hardware.auth.currentUser.uid, firebase: { sign_in_provider: "anonymous" } }), false);
});
test("the current RTDB rules protect AI counters from clients, including anonymous hardware", async () => {
  const path = `_aiRateLimits/${professor.auth.currentUser.uid}`;
  for (const actor of [professor, hardware]) {
    await assertFails(get(ref(actor.database, path)));
    await assertFails(set(ref(actor.database, path), { start: 0, count: 0 }));
  }
});
test("AI quota enforces ten requests atomically and resets in the next window", async () => {
  const database = adminDb.getDatabase(admin);
  const uid = professor.auth.currentUser.uid;
  const now = Date.now();
  const results = await Promise.all(Array.from({ length: 12 }, () => consumeAiQuota(database, uid, now)));
  assert.equal(results.filter(Boolean).length, 10);
  assert.equal((await database.ref(`_aiRateLimits/${uid}`).get()).val().count, 10);
  assert.equal(await consumeAiQuota(database, uid, now + 60001), true);
});

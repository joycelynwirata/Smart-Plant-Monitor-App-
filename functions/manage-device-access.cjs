"use strict";
// Admin-only utility. Defaults to preview; never bundled into Flutter Hosting.
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getDatabase } = require("firebase-admin/database");

async function main() {
  const args = process.argv.slice(2);
  const value = (key) => args[args.indexOf(key) + 1];
  if (!args.includes("--uid") || !args.includes("--role")) {
    console.log("Usage: npm run device-access -- --uid UID --role operator|device [--revoke] [--apply]");
    return;
  }
  const uid = value("--uid");
  const role = value("--role");
  if (!uid || /[.#$\[\]/\s]/.test(uid) || !["operator", "device"].includes(role)) {
    throw new Error("A valid UID and operator/device role are required.");
  }
  initializeApp({
    projectId: "smart-plant-595ab",
    databaseURL: "https://smart-plant-595ab-default-rtdb.firebaseio.com",
    credential: applicationDefault(),
  });
  const user = await getAuth().getUser(uid);
  const revoke = args.includes("--revoke");
  if (!revoke) {
    if (user.disabled) throw new Error("Cannot approve a disabled account.");
    const registered = Boolean(user.email || user.phoneNumber || user.providerData.length);
    if (role === "operator" && !registered) throw new Error("Anonymous identities cannot be app operators.");
    if (role === "device" && registered) throw new Error("Device role is reserved for the ESP32 anonymous identity.");
  }
  const path = `deviceAccess/plant1/${role === "operator" ? "operators" : "devices"}/${uid}`;
  const approved = !revoke;
  console.log(JSON.stringify({ project: "smart-plant-595ab", path, approved, apply: args.includes("--apply") }));
  if (!args.includes("--apply")) {
    console.log("Preview only. No cloud data changed. --apply requires the owner's approval.");
    return;
  }
  // Updates only this new authorization leaf; sensor/profile/history data is untouched.
  await getDatabase().ref(path).set(approved);
  console.log("Device access updated.");
}

main().catch(() => {
  console.error("Device access could not be prepared. Check the UID, role, and trusted Admin credentials (ADC). No credentials are printed.");
  process.exitCode = 1;
});

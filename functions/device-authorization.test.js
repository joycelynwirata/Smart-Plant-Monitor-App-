"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createDeviceAuthorization } = require("./device-authorization");

test("only approved registered accounts may use paid AI", async () => {
  const authorize = createDeviceAuthorization(async (uid) => uid === "professor");
  assert.equal(await authorize({ uid: "professor", firebase: { sign_in_provider: "password" } }), true);
  assert.equal(await authorize({ uid: "unapproved", firebase: { sign_in_provider: "password" } }), false);
  assert.equal(await authorize({ uid: "professor", firebase: { sign_in_provider: "anonymous" } }), false);
  assert.equal(await authorize({ uid: "professor" }), false);
});
test("approval must be the Boolean true, not a truthy value", async () => {
  const authorize = createDeviceAuthorization(async () => "true");
  assert.equal(await authorize({ uid: "professor", firebase: { sign_in_provider: "password" } }), false);
});
test("initial deployment allows registered accounts without enrollment, never anonymous accounts", async () => {
  const authorize = createDeviceAuthorization(
    async () => { throw new Error("Approval registry must not be required in initial mode"); },
    () => false,
  );
  assert.equal(await authorize({ uid: "new-professor", firebase: { sign_in_provider: "password" } }), true);
  assert.equal(await authorize({ uid: "esp32", firebase: { sign_in_provider: "anonymous" } }), false);
  assert.equal(await authorize({ uid: "unknown" }), false);
});

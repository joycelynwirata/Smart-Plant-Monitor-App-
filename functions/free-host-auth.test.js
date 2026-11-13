"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createFreeHostVerifier, createLocalQuota } = require("./free-host-auth");

test("free host verifies signatures and checks the current account without admin credentials", async () => {
  const verify = createFreeHostVerifier({
    verifyToken: async (token) => { assert.equal(token, "test-token"); return { uid: "professor", auth_time: 100 }; },
    apiKey: "public-web-key",
    fetch: async (url, options) => {
      assert.ok(url.includes("accounts:lookup"));
      assert.equal(JSON.parse(options.body).idToken, "test-token");
      return { ok: true, json: async () => ({ users: [{ localId: "professor", validSince: "100" }] }) };
    },
  });
  assert.equal((await verify("test-token")).uid, "professor");
});
test("free host rejects invalid signatures, disabled/deleted users, and revoked sessions", async () => {
  for (const user of [undefined, { localId: "other" }, { localId: "professor", disabled: true }, { localId: "professor", validSince: "101" }]) {
    const verify = createFreeHostVerifier({ verifyToken: async () => ({ uid: "professor", auth_time: 100 }), apiKey: "public", fetch: async () => ({ ok: true, json: async () => ({ users: user ? [user] : [] }) }) });
    await assert.rejects(verify("token"));
  }
  const verify = createFreeHostVerifier({ verifyToken: async () => { throw new Error("invalid signature"); }, fetch: () => assert.fail("No lookup for an invalid token") });
  await assert.rejects(verify("invalid"));
});
test("free-host instance quota limits requests and resets after one minute", async () => {
  let now = 100;
  const quota = createLocalQuota({ now: () => now });
  for (let i = 0; i < 10; i++) assert.equal(await quota("professor"), true);
  assert.equal(await quota("professor"), false);
  assert.equal(await quota("another-user"), true);
  now += 60000;
  assert.equal(await quota("professor"), true);
});

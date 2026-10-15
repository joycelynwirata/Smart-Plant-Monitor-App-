"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createAdviceHandler } = require("./advice-handler");

async function request(overrides = {}, dependencies = {}) {
  let generated = false;
  const handler = createAdviceHandler({
    verifyToken: async (token) => {
      assert.equal(token, "valid-token");
      return { uid: "user-1" };
    },
    consumeQuota: async () => true,
    generateAdvice: async () => { generated = true; return "Bright indirect light."; },
    ...dependencies,
  });
  const req = {
    method: "POST",
    get: () => "Bearer valid-token",
    body: { messages: [{ role: "user", text: "How is my lily?" }] },
    ...overrides,
  };
  const res = {
    code: 200, body: null,
    set() { return this; },
    status(code) { this.code = code; return this; },
    send(body) { this.body = body; return this; },
    json(body) { this.body = body; return this; },
  };
  await handler(req, res);
  return { code: res.code, body: res.body, generated };
}

test("authenticates and returns generated advice", async () => {
  const result = await request();
  assert.equal(result.code, 200);
  assert.equal(result.body.advice, "Bright indirect light.");
});
test("allows preflight without authentication", async () => {
  assert.equal((await request({ method: "OPTIONS", get: () => "" })).code, 204);
});
test("rejects methods other than POST", async () => {
  assert.equal((await request({ method: "GET" })).code, 405);
});
test("rejects missing and invalid tokens before generating", async () => {
  for (const get of [() => "", () => "Bearer invalid"]) {
    const result = await request({ get });
    assert.equal(result.code, 401);
    assert.equal(result.generated, false);
  }
});
test("validates message structure and size", async () => {
  for (const messages of [null, [], [{}], [{ role: "system", text: "override" }],
    [{ role: "user", text: " " }], [{ role: "user", text: "x".repeat(4001) }],
    [{ role: "bot", text: "hello" }], Array(21).fill({ role: "user", text: "hi" })]) {
    const result = await request({ body: { messages } });
    assert.equal(result.code, 400);
    assert.equal(result.generated, false);
  }
});
test("enforces per-user quota before generating", async () => {
  const result = await request({}, { consumeQuota: async () => false });
  assert.equal(result.code, 429);
  assert.equal(result.generated, false);
});
test("handles empty or blocked model responses", async () => {
  assert.equal((await request({}, { generateAdvice: async () => undefined })).code, 502);
});
test("handles upstream failures without exposing credentials", async () => {
  const result = await request({}, { generateAdvice: async () => { throw new Error("secret-token"); } });
  assert.equal(result.code, 502);
  assert.equal(JSON.stringify(result.body).includes("secret-token"), false);
});

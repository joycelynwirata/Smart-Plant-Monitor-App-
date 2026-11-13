"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createGeminiAdvice } = require("./gemini-advice");

test("shared Gemini integration keeps credentials server-side and preserves conversation", async () => {
  const generate = createGeminiAdvice({
    getKey: () => "test-only-key", getModel: () => "gemini-2.5-flash",
    fetch: async (url, options) => {
      assert.ok(url.endsWith("/gemini-2.5-flash:generateContent"));
      assert.equal(url.includes("test-only-key"), false);
      assert.equal(options.headers["x-goog-api-key"], "test-only-key");
      const body = JSON.parse(options.body);
      assert.deepEqual(body.contents.map((message) => message.role), ["user", "model", "user"]);
      assert.ok(body.systemInstruction.parts[0].text.includes("soil tension"));
      assert.equal(body.generationConfig.maxOutputTokens, 1024);
      return { ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: "Plant " }, { text: "advice" }] } }] }) };
    },
  });
  assert.equal(await generate([{ role: "user", text: "Hello" }, { role: "bot", text: "Hi" }, { role: "user", text: "Help" }]), "Plant advice");
});
test("missing Gemini configuration fails without contacting upstream", async () => {
  const generate = createGeminiAdvice({ getKey: () => "", fetch: () => { throw new Error("Unexpected request"); } });
  await assert.rejects(generate([]), { code: "NOT_CONFIGURED" });
});
test("free-host adapter accepts CORS preflight and fails closed without server credentials", async () => {
  const handler = require("./api/advice");
  const previous = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  try {
    const headers = {};
    const res = {
      code: 200, setHeader(name, value) { headers[name] = value; },
      status(code) { this.code = code; return this; }, send() { return this; },
      json(body) { this.body = body; return this; },
    };
    await handler({ method: "OPTIONS" }, res);
    assert.equal(res.code, 204);
    assert.equal(headers["Access-Control-Allow-Headers"], "Content-Type, Authorization");
    await handler({ method: "POST" }, res);
    assert.equal(res.code, 503);
    assert.equal(JSON.stringify(res.body).includes("private_key"), false);
  } finally {
    if (previous !== undefined) process.env.GEMINI_API_KEY = previous;
  }
});

"use strict";

// Dependencies are injected so authentication and upstream failures can be tested
// without calling Firebase or Gemini.
function createAdviceHandler({ verifyToken, consumeQuota, generateAdvice }) {
  return async (req, res) => {
    res.set("Cache-Control", "no-store");
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });

    const match = /^Bearer (\S+)$/.exec(req.get("Authorization") || "");
    if (!match) return res.status(401).json({ error: "Sign in required." });
    let user;
    try {
      user = await verifyToken(match[1]);
    } catch {
      return res.status(401).json({ error: "Invalid session." });
    }
    const messages = req.body?.messages;
    if (!Array.isArray(messages) || messages.length === 0 || messages.length > 20 ||
        messages.some((m) => !m || !["user", "bot"].includes(m.role) ||
          typeof m.text !== "string" || !m.text.trim() || m.text.length > 4000) ||
        messages.at(-1).role !== "user") {
      return res.status(400).json({ error: "Provide 1–20 messages, ending with a user message." });
    }
    try {
      if (!await consumeQuota(user.uid)) {
        return res.status(429).json({ error: "Too many requests." });
      }
      const advice = await generateAdvice(messages);
      if (typeof advice !== "string" || !advice.trim()) {
        return res.status(502).json({ error: "No advice was returned." });
      }
      return res.json({ advice: advice.trim() });
    } catch (error) {
      // Never log the upstream request URL or credentials.
      console.error("Plant advice failed:", error.name);
      return res.status(error.code === "NOT_CONFIGURED" ? 503 : 502)
        .json({ error: "Plant advice is temporarily unavailable." });
    }
  };
}

module.exports = { createAdviceHandler };

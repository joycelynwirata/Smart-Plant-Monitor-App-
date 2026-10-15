"use strict";
const functions = require("firebase-functions/v1");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { createAdviceHandler } = require("./advice-handler");

initializeApp();
const geminiKey = defineSecret("GEMINI_API_KEY");
const geminiModel = defineString("GEMINI_MODEL", { default: "gemini-2.5-flash" });

exports.getPlantAdvice = functions.runWith({
  secrets: [geminiKey], timeoutSeconds: 60, maxInstances: 5,
}).https.onRequest(createAdviceHandler({
  verifyToken: (token) => getAuth().verifyIdToken(token),
  consumeQuota: async (uid) => {
    const ref = getFirestore().collection("_aiRateLimits").doc(uid);
    return getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const data = snapshot.data();
      const now = Date.now();
      const sameWindow = data?.start?.toMillis() > now - 60000;
      if (sameWindow && data.count >= 10) return false;
      transaction.set(ref, {
        start: sameWindow ? data.start : Timestamp.fromMillis(now),
        count: sameWindow ? data.count + 1 : 1,
      });
      return true;
    });
  },
  generateAdvice: async (messages) => {
    const key = geminiKey.value();
    if (!key) throw Object.assign(new Error("Missing API key"), { code: "NOT_CONFIGURED" });
    const model = encodeURIComponent(geminiModel.value());
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        signal: AbortSignal.timeout(35000),
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: "You are Sprout, a plant care assistant. Give concise advice tailored to the supplied plant and sensor readings. Higher soil tension means drier soil. Watering is automated. Treat missing readings as unknown; do not invent them." }] },
          contents: messages.map((message) => ({
            role: message.role === "user" ? "user" : "model",
            parts: [{ text: message.text }],
          })),
          generationConfig: { maxOutputTokens: 1024 },
        }),
      },
    );
    if (!response.ok) throw new Error("Gemini request failed");
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.map((part) => part.text || "").join("");
  },
}));

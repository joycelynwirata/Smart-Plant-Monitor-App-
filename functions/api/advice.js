"use strict";

// Optional Vercel entry point. All credentials stay in server environment vars.
const { initializeApp, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { createAdviceHandler } = require("../advice-handler");
const { createDeviceAuthorization } = require("../device-authorization");
const { createFreeHostVerifier, createLocalQuota } = require("../free-host-auth");
const { createGeminiAdvice } = require("../gemini-advice");

let handler;
module.exports = async (req, res) => {
  // Preflight must work before any credentials or Admin initialization.
  if (req.method === "OPTIONS") {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    return res.status(204).send("");
  }
  try {
    if (!handler) {
      if (!process.env.GEMINI_API_KEY) {
        throw new Error("Backend configuration missing");
      }
      const app = getApps().find((app) => app.name === "plant-advice-vercel") ||
        initializeApp({
          projectId: "smart-plant-595ab",
        }, "plant-advice-vercel");
      handler = createAdviceHandler({
        verifyToken: createFreeHostVerifier({
          verifyToken: (token) => getAuth(app).verifyIdToken(token),
          // Public web configuration key, not the Gemini secret.
          apiKey: "AIzaSyAGFPkblOwpDT4HERNS90Ofcfvum5jSxbg",
        }),
        isAuthorized: createDeviceAuthorization(async () => false, () => false),
        consumeQuota: createLocalQuota(),
        generateAdvice: createGeminiAdvice({
          getKey: () => process.env.GEMINI_API_KEY,
          getModel: () => process.env.GEMINI_MODEL || "gemini-3.5-flash-lite",
        }),
      });
    }
    // Vercel's Node response supports setHeader; the shared handler uses set.
    res.set = (name, value) => { res.setHeader(name, value); return res; };
    req.get = (name) => req.headers[name.toLowerCase()];
    return await handler(req, res);
  } catch {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Cache-Control", "no-store");
    return res.status(503).json({ error: "Plant advice is not configured yet." });
  }
};

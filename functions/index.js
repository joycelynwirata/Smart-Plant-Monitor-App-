"use strict";
const functions = require("firebase-functions/v1");
const { defineSecret, defineString, defineBoolean } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getDatabase } = require("firebase-admin/database");
const { createAdviceHandler } = require("./advice-handler");
const { createDeviceAuthorization } = require("./device-authorization");
const { createGeminiAdvice } = require("./gemini-advice");
const { consumeAiQuota } = require("./ai-quota");

initializeApp({ databaseURL: "https://smart-plant-595ab-default-rtdb.firebaseio.com" });
const geminiKey = defineSecret("GEMINI_API_KEY");
const geminiModel = defineString("GEMINI_MODEL", { default: "gemini-3.5-flash-lite" });
const requireDeviceApproval = defineBoolean("REQUIRE_DEVICE_APPROVAL", { default: false });

exports.getPlantAdvice = functions.runWith({
  secrets: [geminiKey], timeoutSeconds: 60, maxInstances: 5,
}).https.onRequest(createAdviceHandler({
  verifyToken: (token) => getAuth().verifyIdToken(token, true),
  isAuthorized: createDeviceAuthorization(async (uid) =>
    (await getDatabase().ref(`deviceAccess/plant1/operators/${uid}`).get()).val(),
    () => requireDeviceApproval.value()),
  // Existing RTDB rules already deny client access outside liveData/history.
  // Do not put counters in the currently public Firestore database.
  consumeQuota: (uid) => consumeAiQuota(getDatabase(), uid),
  generateAdvice: createGeminiAdvice({ getKey: () => geminiKey.value(), getModel: () => geminiModel.value() }),
}));

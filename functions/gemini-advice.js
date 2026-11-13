"use strict";

// Shared by Firebase Functions and the optional free Node.js host.
function createGeminiAdvice({ getKey, getModel, fetch: fetchApi = globalThis.fetch }) {
  return async (messages) => {
    const key = getKey();
    if (!key) throw Object.assign(new Error("Missing API key"), { code: "NOT_CONFIGURED" });
    const model = encodeURIComponent(getModel());
    const response = await fetchApi(
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
  };
}
module.exports = { createGeminiAdvice };

"use strict";

// Uses the signed-in user's ID token, not privileged Firebase credentials.
function createFreeHostVerifier({ verifyToken, apiKey, fetch: fetchApi = globalThis.fetch }) {
  return async (token) => {
    const claims = await verifyToken(token);
    const response = await fetchApi(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`,
      { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken: token }), signal: AbortSignal.timeout(8000) },
    );
    if (!response.ok) throw new Error("Invalid Firebase session");
    const user = (await response.json()).users?.[0];
    if (!user || user.localId !== claims.uid || user.disabled ||
        (Number(user.validSince) > claims.auth_time)) throw new Error("Invalid Firebase session");
    return claims;
  };
}

// Best effort per warm instance; Gemini's free project quota is the global limit.
function createLocalQuota({ now = Date.now } = {}) {
  const windows = new Map();
  return async (uid) => {
    const time = now();
    if (windows.size >= 10000) {
      for (const [key, value] of windows) if (value.start <= time - 60000) windows.delete(key);
    }
    let window = windows.get(uid);
    if (!window || window.start <= time - 60000) {
      if (!window && windows.size >= 10000) return false;
      window = { start: time, count: 0 };
      windows.set(uid, window);
    }
    if (window.count >= 10) return false;
    window.count++;
    return true;
  };
}
module.exports = { createFreeHostVerifier, createLocalQuota };

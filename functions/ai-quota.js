"use strict";

// Stored outside public sensor paths, so the current live rules already protect
// these counters without deploying any new Firestore or device rules.
async function consumeAiQuota(database, uid, now = Date.now()) {
  const result = await database.ref(`_aiRateLimits/${uid}`).transaction((data) => {
    const sameWindow = Number.isFinite(data?.start) && data.start > now - 60000;
    const count = sameWindow && Number.isInteger(data.count) ? data.count : 0;
    if (count >= 10) return undefined;
    return { start: sameWindow ? data.start : now, count: count + 1 };
  });
  return result.committed;
}

module.exports = { consumeAiQuota };

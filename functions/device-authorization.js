"use strict";

function createDeviceAuthorization(readApproval, requireApproval = () => true) {
  return async (user) => {
    const provider = user.firebase?.sign_in_provider;
    if (!provider || provider === "anonymous") return false;
    if (!requireApproval()) return true;
    return await readApproval(user.uid) === true;
  };
}

module.exports = { createDeviceAuthorization };

/**
 * Deleted Response Helper
 *
 * Sends 204 No Content response for successful deletions per response-format.mdc
 * Used for successful resource deletion
 *
 * @param {Object} res - Express response object
 * @returns {Object} Express response
 */
const { sendNoContent } = require('@lib/response/noContent');

const sendDeleted = (res) => {
  return sendNoContent(res);
};

module.exports = { sendDeleted };

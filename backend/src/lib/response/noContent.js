/**
 * No Content Response Helper
 *
 * Sends HTTP 204 No Content with an empty response body.
 * Per response-format.mdc: Successful DELETE operations returning 204 must not send JSON.
 *
 * @param {Object} res - Express response object
 * @returns {Object} Express response
 */
const sendNoContent = (res) => {
  return res.status(204).send();
};

module.exports = { sendNoContent };



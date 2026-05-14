/**
 * Created Response Helper
 *
 * Sends standardized 201 Created response per response-format.mdc
 * Used for successful resource creation
 *
 * @param {Object} res - Express response object
 * @param {any} data - Created resource data
 * @param {string} message - Descriptive success message or translation key
 * @param {string} locale - Optional locale for translation
 * @returns {Object} Express response
 */
const { sendSuccess } = require('@lib/response/success');

const sendCreated = (res, data, message, locale) => {
  return sendSuccess(res, 201, message, data);
};

module.exports = { sendCreated };

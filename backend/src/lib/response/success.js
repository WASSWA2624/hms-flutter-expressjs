/**
 * Success Response Helper
 *
 * Sends standardized success response per response-format.mdc
 * Used for single resource or generic success responses
 *
 * @param {Object} res - Express response object
 * @param {number} status - HTTP status code (default: 200)
 * @param {string} message - Descriptive success message or translation key
 * @param {any} data - Response data (object, array, string, number, etc.)
 * @returns {Object} Express response
 */
const { translate, isTranslationKey, applyLocaleHeader, getResponseMeta } = require('@lib/i18n');
const { sanitizeFriendlyIds } = require('@lib/identifiers/sanitize-friendly-ids');

const resolveMessage = (message, locale) => {
  if (isTranslationKey(message)) {
    return translate(message, locale);
  }
  return message;
};

const sendSuccess = (res, status = 200, message, data) => {
  // Per response-format.mdc: HTTP 204 No Content must have an empty response body.
  if (status === 204) {
    return res.status(204).send();
  }

  const meta = getResponseMeta(res);
  const sanitizedMeta = sanitizeFriendlyIds(meta);
  const resolvedMessage = resolveMessage(message, meta.locale);
  applyLocaleHeader(res, meta.locale);

  return res.status(status).json({
    status,
    message: resolvedMessage,
    data: sanitizeFriendlyIds(data),
    meta: sanitizedMeta
  });
};

module.exports = { sendSuccess };


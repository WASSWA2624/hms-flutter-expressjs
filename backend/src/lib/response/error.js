/**
 * Error Response Helper
 *
 * Sends standardized error response per response-format.mdc
 * Note: Most errors should be handled by error middleware (handleApiError)
 * This helper may be used in controllers for specific error cases
 *
 * @param {Object} res - Express response object
 * @param {number} status - HTTP status code (400-599)
 * @param {string} message - User-friendly error message or translation key
 * @param {Array} [errors=[]] - Array of detailed error information
 * @returns {Object} Express response
 */
const { translate, isTranslationKey, applyLocaleHeader, getResponseMeta } = require('@lib/i18n');
const { sanitizeFriendlyIds } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  applyProblemJsonContentType,
  createProblemDetails
} = require('@lib/response/problem-details');

const resolveMessage = (message, locale) => {
  if (isTranslationKey(message)) {
    return translate(message, locale);
  }
  return message;
};

const toProblemCode = (message, status) => {
  if (isTranslationKey(message)) {
    const key = String(message).split('.').pop() || 'unknown_error';
    return key.toUpperCase().replace(/-/g, '_');
  }

  if (status >= 500) return 'SERVER_ERROR';
  if (status === 404) return 'NOT_FOUND';
  if (status === 403) return 'FORBIDDEN';
  if (status === 401) return 'UNAUTHORIZED';
  if (status === 409) return 'CONFLICT';
  return 'UNKNOWN_ERROR';
};

const resolveErrors = (errors, locale) => {
  if (!Array.isArray(errors)) {
    return [];
  }
  const resolved = errors.map((error) => {
    if (!error || typeof error !== 'object') {
      return error;
    }
    const message = resolveMessage(error.message, locale);
    return { ...error, message };
  });
  return sanitizeFriendlyIds(resolved);
};

const sendError = (res, status, message, errors = []) => {
  const meta = getResponseMeta(res);
  const sanitizedMeta = sanitizeFriendlyIds(meta);
  const resolvedMessage = resolveMessage(message, meta.locale);
  const resolvedErrors = resolveErrors(errors, meta.locale);
  applyLocaleHeader(res, meta.locale);

  const problem = createProblemDetails({
    status,
    title: resolvedMessage,
    detail: resolvedMessage,
    code: toProblemCode(message, status),
    errors: resolvedErrors,
    meta: sanitizedMeta,
    req: res.req || null
  });

  applyProblemJsonContentType(res);

  return res.status(status).json(problem);
};

module.exports = { sendError };


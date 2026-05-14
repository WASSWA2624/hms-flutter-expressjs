/**
 * Paginated Response Helper
 *
 * Sends standardized paginated response per response-format.mdc
 * Used for all list endpoints that return paginated data
 *
 * @param {Object} res - Express response object
 * @param {string} message - Descriptive success message or translation key
 * @param {Array} data - Array of resources
 * @param {Object} pagination - Pagination metadata
 * @param {number} pagination.page - Current page number
 * @param {number} pagination.limit - Items per page
 * @param {number} pagination.total - Total number of items
 * @param {number} pagination.totalPages - Total number of pages
 * @param {boolean} pagination.hasNextPage - Whether there is a next page
 * @param {boolean} pagination.hasPreviousPage - Whether there is a previous page
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

const sendPaginated = (res, message, data, pagination) => {
  const meta = getResponseMeta(res);
  const sanitizedMeta = sanitizeFriendlyIds(meta);
  const resolvedMessage = resolveMessage(message, meta.locale);
  applyLocaleHeader(res, meta.locale);

  return res.status(200).json({
    status: 200,
    message: resolvedMessage,
    data: sanitizeFriendlyIds(data || []),
    meta: sanitizedMeta,
    pagination: {
      page: pagination.page,
      limit: pagination.limit,
      total: pagination.total,
      totalPages: pagination.totalPages,
      hasNextPage: pagination.hasNextPage,
      hasPreviousPage: pagination.hasPreviousPage
    }
  });
};

module.exports = { sendPaginated };


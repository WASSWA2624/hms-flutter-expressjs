/**
 * Response utilities barrel export
 * 
 * @description Centralized exports for response helpers. Allows importing `@lib/response`.
 * Per response-format.mdc: All endpoints must use these standardized response helpers.
 */

const { sendSuccess } = require('@lib/response/success');
const { sendPaginated } = require('@lib/response/pagination');
const { sendError } = require('@lib/response/error');
const { sendNoContent } = require('@lib/response/noContent');
const { sendCreated } = require('@lib/response/created');
const { sendDeleted } = require('@lib/response/deleted');

module.exports = {
  sendSuccess,
  sendPaginated,
  sendError,
  sendNoContent,
  sendCreated,
  sendDeleted
};


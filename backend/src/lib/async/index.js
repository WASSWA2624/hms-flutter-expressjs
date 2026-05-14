/**
 * Async utilities barrel export
 * 
 * @description Centralized exports for async helpers. Allows importing `@lib/async`.
 * Per module-creation.mdc: All controller functions must use asyncHandler.
 */

const { asyncHandler } = require('@lib/async/asyncHandler');

module.exports = {
  asyncHandler
};


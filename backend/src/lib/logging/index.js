/**
 * Logging utilities barrel export
 * 
 * @description Centralized exports for logging helpers. Allows importing `@lib/logging`.
 * Per error-logging.mdc: All logs must use sanitize and logger utilities.
 */

const { sanitize } = require('@lib/logging/sanitize');
const logger = require('@lib/logging/logger');

module.exports = {
  sanitize,
  logger
};


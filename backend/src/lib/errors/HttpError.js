/**
 * HTTP Error Class
 * 
 * Extends AppError for HTTP-specific errors
 * Used for errors that should return specific HTTP status codes
 * 
 * @class HttpError
 * @extends AppError
 */
const AppError = require('@lib/errors/AppError');

class HttpError extends AppError {
  /**
   * Create an HTTP error
   *
   * @param {string} message - Error message
   * @param {number} statusCode - HTTP status code (400-599)
   * @param {Array} [errors=[]] - Array of detailed error information
   * @param {Object} [options={}] - Additional options
   * @param {string} [options.problemCode] - Explicit machine-readable problem
   *   code. Overrides the code derived from the message key, for cases where
   *   the derived code would be ambiguous to clients (e.g. `errors.csrf.missing`
   *   deriving to a bare `MISSING`).
   */
  constructor(message, statusCode = 400, errors = [], options = {}) {
    super(message, statusCode, true);

    this.messageKey = message; // Store the i18n message key
    this.errors = errors;
    if (options?.problemCode) {
      this.problemCode = String(options.problemCode);
    }
  }
}

module.exports = HttpError;


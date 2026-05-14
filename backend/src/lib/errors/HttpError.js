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
   */
  constructor(message, statusCode = 400, errors = []) {
    super(message, statusCode, true);
    
    this.messageKey = message; // Store the i18n message key
    this.errors = errors;
  }
}

module.exports = HttpError;


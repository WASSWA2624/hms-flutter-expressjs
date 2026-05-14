/**
 * Base Application Error Class
 * 
 * All custom application errors should extend this class
 * Provides consistent error structure across the application
 * 
 * @class AppError
 * @extends Error
 */
class AppError extends Error {
  /**
   * Create an application error
   * 
   * @param {string} message - Error message
   * @param {number} [statusCode=500] - HTTP status code
   * @param {boolean} [isOperational=true] - Whether this is an operational error (expected) or programming error
   */
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.timestamp = new Date().toISOString();
    
    // Capture stack trace, excluding constructor call from it
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;


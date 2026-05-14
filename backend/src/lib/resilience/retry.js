/**
 * Retry Utility
 *
 * Provides retry logic with exponential backoff per error-logging.mdc.
 * Intended for external service calls only.
 */

const {
  RETRY_MAX_ATTEMPTS,
  RETRY_INITIAL_DELAY_MS,
  RETRY_BACKOFF_MULTIPLIER,
  RETRY_MAX_DELAY_MS
} = require('@config/constants');

/**
 * Sleep for a given duration.
 *
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>} Resolves after delay
 */
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Determine if an error is transient and should be retried.
 *
 * @param {Error} error - Error to inspect
 * @returns {boolean} True if transient
 */
const isTransientError = (error) => {
  if (!error) {
    return false;
  }

  const code = error.code || error.name || '';
  const status = error.statusCode || error.status || 0;

  const transientCodes = new Set([
    'ETIMEDOUT',
    'ECONNRESET',
    'ECONNREFUSED',
    'EAI_AGAIN',
    'ENETUNREACH',
    'EHOSTUNREACH'
  ]);

  if (transientCodes.has(code)) {
    return true;
  }

  return status >= 500 && status < 600;
};

/**
 * Retry a promise-returning function with exponential backoff.
 *
 * @param {Function} task - Function returning a promise
 * @param {Object} [options] - Retry options
 * @param {number} [options.maxAttempts] - Max attempts (default: 3)
 * @param {number} [options.initialDelayMs] - Initial delay (default: 100ms)
 * @param {number} [options.backoffMultiplier] - Backoff multiplier (default: 2)
 * @param {number} [options.maxDelayMs] - Max delay (default: 5000ms)
 * @param {Function} [options.shouldRetry] - Optional retry predicate
 * @returns {Promise<any>} Task result
 */
const withRetry = async (task, options = {}) => {
  const maxAttempts = options.maxAttempts || RETRY_MAX_ATTEMPTS;
  const initialDelayMs = options.initialDelayMs || RETRY_INITIAL_DELAY_MS;
  const backoffMultiplier = options.backoffMultiplier || RETRY_BACKOFF_MULTIPLIER;
  const maxDelayMs = options.maxDelayMs || RETRY_MAX_DELAY_MS;
  const shouldRetry = options.shouldRetry || isTransientError;

  let attempt = 0;
  let lastError;

  while (attempt < maxAttempts) {
    try {
      attempt += 1;
      return await task();
    } catch (error) {
      lastError = error;

      if (attempt >= maxAttempts || !shouldRetry(error)) {
        throw error;
      }

      const backoff = initialDelayMs * Math.pow(backoffMultiplier, attempt - 1);
      const delay = Math.min(backoff, maxDelayMs);
      await sleep(delay);
    }
  }

  throw lastError;
};

module.exports = {
  withRetry,
  isTransientError
};

/**
 * Timeout Utility
 *
 * Wraps async work with a timeout per error-logging.mdc.
 */

const { DEFAULT_REQUEST_TIMEOUT_MS } = require('@config/constants');

/**
 * Wrap a promise or async function with a timeout.
 *
 * @param {Promise|Function} task - Promise or function returning a promise
 * @param {number} [timeoutMs] - Timeout in milliseconds
 * @param {string} [message] - Error message for timeout
 * @returns {Promise<any>} Task result or timeout error
 */
const withTimeout = async (task, timeoutMs = DEFAULT_REQUEST_TIMEOUT_MS, message = 'errors.service.timeout') => {
  const work = typeof task === 'function' ? task() : task;

  if (!work || typeof work.then !== 'function') {
    throw new Error('withTimeout requires a promise or async function');
  }

  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(message)), timeoutMs);
  });

  try {
    return await Promise.race([work, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
};

module.exports = {
  withTimeout
};

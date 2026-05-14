/**
 * Current Timestamp Utility
 * 
 * Returns current timestamp in various formats
 * Useful for audit logs, timestamps, and date comparisons
 */

/**
 * Get current Unix timestamp in seconds
 * 
 * @returns {number} Current Unix timestamp (seconds since epoch)
 */
const getCurrentTimestamp = () => {
  return Math.floor(Date.now() / 1000);
};

/**
 * Get current Unix timestamp in milliseconds
 * 
 * @returns {number} Current Unix timestamp (milliseconds since epoch)
 */
const getCurrentTimestampMs = () => {
  return Date.now();
};

/**
 * Get current date as ISO 8601 string
 * 
 * @returns {string} Current date in ISO 8601 format
 */
const getCurrentISO = () => {
  return new Date().toISOString();
};

/**
 * Get current date as Date object
 * 
 * @returns {Date} Current date as Date object
 */
const getCurrentDate = () => {
  return new Date();
};

/**
 * Get current date in YYYY-MM-DD format
 * 
 * @returns {string} Current date in YYYY-MM-DD format
 */
const getCurrentDateString = () => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

module.exports = {
  getCurrentTimestamp,
  getCurrentTimestampMs,
  getCurrentISO,
  getCurrentDate,
  getCurrentDateString
};


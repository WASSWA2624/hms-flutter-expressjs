/**
 * Date utilities barrel export
 * 
 * @description Centralized exports for date helpers. Allows importing `@lib/dates`.
 */

const { formatDate } = require('@lib/dates/formatDate');
const { 
  getCurrentTimestamp, 
  getCurrentTimestampMs, 
  getCurrentISO, 
  getCurrentDate, 
  getCurrentDateString 
} = require('@lib/dates/getCurrentTimestamp');

module.exports = {
  formatDate,
  getCurrentTimestamp,
  getCurrentTimestampMs,
  getCurrentISO,
  getCurrentDate,
  getCurrentDateString
};


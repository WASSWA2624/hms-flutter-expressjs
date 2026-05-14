/**
 * Date Formatting Utility
 * 
 * Provides date formatting helpers for consistent date display across the application
 * 
 * @param {Date|string|number} date - Date to format (Date object, ISO string, or timestamp)
 * @param {string} [format='iso'] - Format type: 'iso', 'date', 'datetime', 'timestamp', 'custom'
 * @param {string} [customFormat] - Custom format string (when format='custom')
 * @returns {string} Formatted date string
 */

/**
 * Format date to ISO 8601 string
 * 
 * @param {Date} date - Date object
 * @returns {string} ISO 8601 formatted string
 */
const formatToISO = (date) => {
  return date.toISOString();
};

/**
 * Format date to YYYY-MM-DD
 * 
 * @param {Date} date - Date object
 * @returns {string} Date in YYYY-MM-DD format
 */
const formatToDate = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

/**
 * Format date to YYYY-MM-DD HH:MM:SS
 * 
 * @param {Date} date - Date object
 * @returns {string} Date in YYYY-MM-DD HH:MM:SS format
 */
const formatToDateTime = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
};

/**
 * Format date to Unix timestamp (seconds)
 * 
 * @param {Date} date - Date object
 * @returns {number} Unix timestamp in seconds
 */
const formatToTimestamp = (date) => {
  return Math.floor(date.getTime() / 1000);
};

/**
 * Parse input to Date object
 * 
 * @param {Date|string|number} input - Date input
 * @returns {Date} Date object
 */
const parseDate = (input) => {
  if (input instanceof Date) {
    return input;
  }
  
  if (typeof input === 'number') {
    // Assume timestamp in milliseconds if > year 2000, otherwise seconds
    if (input > 946684800000) { // Year 2000 in milliseconds
      return new Date(input);
    } else {
      return new Date(input * 1000); // Convert seconds to milliseconds
    }
  }
  
  if (typeof input === 'string') {
    const parsed = new Date(input);
    if (isNaN(parsed.getTime())) {
      throw new Error(`Invalid date string: ${input}`);
    }
    return parsed;
  }
  
  throw new Error(`Invalid date input type: ${typeof input}`);
};

/**
 * Format date according to specified format
 * 
 * @param {Date|string|number} date - Date to format
 * @param {string} [format='iso'] - Format type: 'iso', 'date', 'datetime', 'timestamp', 'custom'
 * @param {string} [customFormat] - Custom format string (when format='custom')
 * @returns {string|number} Formatted date
 */
const formatDate = (date, format = 'iso', customFormat = null) => {
  const dateObj = parseDate(date);
  
  switch (format) {
    case 'iso':
      return formatToISO(dateObj);
    
    case 'date':
      return formatToDate(dateObj);
    
    case 'datetime':
      return formatToDateTime(dateObj);
    
    case 'timestamp':
      return formatToTimestamp(dateObj);
    
    case 'custom':
      if (!customFormat) {
        throw new Error('Custom format string is required when format="custom"');
      }
      // Simple custom format implementation
      // Supports: YYYY, MM, DD, HH, mm, ss
      return customFormat
        .replace(/YYYY/g, String(dateObj.getFullYear()))
        .replace(/MM/g, String(dateObj.getMonth() + 1).padStart(2, '0'))
        .replace(/DD/g, String(dateObj.getDate()).padStart(2, '0'))
        .replace(/HH/g, String(dateObj.getHours()).padStart(2, '0'))
        .replace(/mm/g, String(dateObj.getMinutes()).padStart(2, '0'))
        .replace(/ss/g, String(dateObj.getSeconds()).padStart(2, '0'));
    
    default:
      throw new Error(`Unknown format type: ${format}. Supported: 'iso', 'date', 'datetime', 'timestamp', 'custom'`);
  }
};

module.exports = { formatDate };


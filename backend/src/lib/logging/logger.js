/**
 * Logger Utility
 * 
 * Writes logs to daily log files per error-logging.mdc
 * All logs are sanitized to prevent sensitive data leakage
 * Log levels: info, warn, error
 * 
 * Logs are written to: logs/YYYY-MM-DD.txt
 */

const fs = require('fs');
const path = require('path');
const { sanitize } = require('@lib/logging/sanitize');

// Ensure logs directory exists (per project-structure.mdc: logs/)
const LOGS_DIR = path.join(process.cwd(), 'logs');

let activeDate = null;
let activeStream = null;
let streamErrored = false;

/**
 * Ensure logs directory exists
 */
const ensureLogsDirectory = () => {
  if (!fs.existsSync(LOGS_DIR)) {
    fs.mkdirSync(LOGS_DIR, { recursive: true });
  }
};

const getToday = () => new Date().toISOString().split('T')[0];

const getLogFilePath = (dateStr) => path.join(LOGS_DIR, `${dateStr}.txt`);

/**
 * Lazily rotate stream when calendar date changes.
 * Using a write stream avoids synchronous disk writes on every log call.
 */
const getActiveStream = () => {
  const today = getToday();

  if (activeStream && activeDate === today && !streamErrored) {
    return activeStream;
  }

  if (activeStream) {
    activeStream.end();
    activeStream = null;
  }

  ensureLogsDirectory();
  activeDate = today;
  streamErrored = false;

  activeStream = fs.createWriteStream(getLogFilePath(today), {
    flags: 'a',
    encoding: 'utf8'
  });

  activeStream.on('error', (err) => {
    streamErrored = true;
    console.error('Logger stream error:', err.message);
  });

  return activeStream;
};

/**
 * Format log entry with timestamp and level
 * 
 * @param {string} level - Log level (info, warn, error)
 * @param {string} message - Log message
 * @param {any} [data] - Optional data to include
 * @returns {string} Formatted log entry
 */
const formatLogEntry = (level, message, data = null) => {
  const timestamp = new Date().toISOString();
  const levelUpper = level.toUpperCase().padEnd(5);
  
  let logLine = `[${timestamp}] [${levelUpper}] ${message}`;
  
  if (data !== null && data !== undefined) {
    // Sanitize data before logging
    const sanitizedData = sanitize(data);
    try {
      const dataStr = typeof sanitizedData === 'string' 
        ? sanitizedData 
        : JSON.stringify(sanitizedData, null, 2);
      logLine += `\n${dataStr}`;
    } catch (err) {
      // If JSON.stringify fails, just log as string
      logLine += `\n${String(sanitizedData)}`;
    }
  }
  
  return logLine + '\n';
};

/**
 * Write log entry to file
 * 
 * @param {string} level - Log level
 * @param {string} message - Log message
 * @param {any} [data] - Optional data
 */
const writeLog = (level, message, data = null) => {
  const logEntry = formatLogEntry(level, message, data);

  try {
    const stream = getActiveStream();
    stream.write(logEntry);
  } catch (err) {
    // If logging fails, write to console as fallback.
    // Logging must never take down the request path.
    console.error('Failed to write log:', err.message);
    console.error(`[${level.toUpperCase()}] ${message}`, data);
  }
};

/**
 * Log info message
 * 
 * @param {string} message - Log message
 * @param {any} [data] - Optional data
 */
const info = (message, data = null) => {
  writeLog('info', message, data);
};

/**
 * Log warning message
 * 
 * @param {string} message - Log message
 * @param {any} [data] - Optional data
 */
const warn = (message, data = null) => {
  writeLog('warn', message, data);
};

/**
 * Log error message
 * 
 * @param {string} message - Log message
 * @param {any} [data] - Optional data (error object, etc.)
 */
const error = (message, data = null) => {
  writeLog('error', message, data);
};

/**
 * Close logger stream gracefully.
 *
 * Primarily used by tests/process shutdown to prevent open handles.
 */
const close = () => {
  if (activeStream) {
    activeStream.end();
    activeStream = null;
    activeDate = null;
    streamErrored = false;
  }
};

module.exports = {
  info,
  warn,
  error,
  close
};


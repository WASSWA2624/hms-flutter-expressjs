/**
 * Health Check Utility
 * 
 * Returns application health status per health-checks.mdc
 * GET /health endpoint: Returns 200 if healthy, 503 if unhealthy
 * Response format: { status: "healthy" | "unhealthy", timestamp: ISO 8601, uptime: seconds }
 */

const { getCurrentISO } = require('@lib/dates');

// Track application start time for uptime calculation
const startTime = Date.now();

/**
 * Get application uptime in seconds
 * 
 * @returns {number} Uptime in seconds
 */
const getUptime = () => {
  return Math.floor((Date.now() - startTime) / 1000);
};

/**
 * Health check function
 * Returns health status, timestamp, and uptime
 * 
 * @returns {Object} Health check response
 */
const healthCheck = () => {
  const uptime = getUptime();
  const timestamp = getCurrentISO();
  
  // Application is considered healthy if it's running
  // Additional checks can be added here if needed
  const status = 'healthy';
  
  return {
    status,
    timestamp,
    uptime
  };
};

module.exports = { healthCheck };


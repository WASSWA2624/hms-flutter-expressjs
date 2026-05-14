/**
 * Performance Metrics Utility
 * 
 * Collects and logs performance metrics per performance.mdc
 * Tracks API endpoint response times and database query times
 * Identifies slow queries and endpoints exceeding thresholds
 * 
 * Per performance.mdc:
 * - Simple queries must return < 50ms
 * - Complex queries must return < 200ms
 * - Database average response time must be < 10ms
 * - Performance metrics must be logged or monitored
 * - Alert on API endpoints exceeding thresholds
 */

const { logger } = require('@lib/logging');

// Performance thresholds per performance.mdc
const SIMPLE_QUERY_THRESHOLD_MS = 50;
const COMPLEX_QUERY_THRESHOLD_MS = 200;
const DB_AVG_THRESHOLD_MS = 10;
const ENDPOINT_SLOW_THRESHOLD_MS = 1000; // 1 second for API endpoints

// Track database query metrics
const dbQueryMetrics = {
  totalQueries: 0,
  totalTime: 0,
  slowQueries: []
};

/**
 * Log database query performance
 * 
 * @param {string} operation - Query operation (findMany, findUnique, create, etc.)
 * @param {string} model - Prisma model name
 * @param {number} durationMs - Query duration in milliseconds
 * @param {boolean} isComplex - Whether query is complex (has joins, includes, etc.)
 */
const logQueryPerformance = (operation, model, durationMs, isComplex = false) => {
  const threshold = isComplex ? COMPLEX_QUERY_THRESHOLD_MS : SIMPLE_QUERY_THRESHOLD_MS;
  
  // Update aggregate metrics
  dbQueryMetrics.totalQueries++;
  dbQueryMetrics.totalTime += durationMs;
  
  // Log slow queries
  if (durationMs > threshold) {
    const queryType = isComplex ? 'complex' : 'simple';
    const message = `Slow ${queryType} query detected: ${operation} on ${model}`;
    
    logger.warn(message, {
      operation,
      model,
      durationMs: Math.round(durationMs * 100) / 100,
      threshold,
      queryType,
      exceededBy: Math.round((durationMs - threshold) * 100) / 100
    });
    
    // Track slow queries (keep last 100)
    dbQueryMetrics.slowQueries.push({
      operation,
      model,
      durationMs,
      queryType,
      timestamp: new Date().toISOString()
    });
    
    if (dbQueryMetrics.slowQueries.length > 100) {
      dbQueryMetrics.slowQueries.shift();
    }
  } else {
    // Log normal queries at info level (less verbose)
    logger.info('Database query executed', {
      operation,
      model,
      durationMs: Math.round(durationMs * 100) / 100,
      queryType: isComplex ? 'complex' : 'simple'
    });
  }
};

/**
 * Log API endpoint performance
 * 
 * @param {string} method - HTTP method
 * @param {string} path - Request path
 * @param {number} durationMs - Response duration in milliseconds
 * @param {number} statusCode - HTTP status code
 */
const logEndpointPerformance = (method, path, durationMs, statusCode) => {
  // Log all endpoint calls
  logger.info('API endpoint executed', {
    method,
    path,
    durationMs: Math.round(durationMs * 100) / 100,
    statusCode
  });
  
  // Alert on slow endpoints
  if (durationMs > ENDPOINT_SLOW_THRESHOLD_MS) {
    logger.warn('Slow API endpoint detected', {
      method,
      path,
      durationMs: Math.round(durationMs * 100) / 100,
      statusCode,
      threshold: ENDPOINT_SLOW_THRESHOLD_MS,
      exceededBy: Math.round((durationMs - ENDPOINT_SLOW_THRESHOLD_MS) * 100) / 100
    });
  }
};

/**
 * Get database performance statistics
 * 
 * @returns {Object} Database performance stats
 */
const getDbStats = () => {
  const avgTime = dbQueryMetrics.totalQueries > 0
    ? dbQueryMetrics.totalTime / dbQueryMetrics.totalQueries
    : 0;
  
  return {
    totalQueries: dbQueryMetrics.totalQueries,
    averageTimeMs: Math.round(avgTime * 100) / 100,
    slowQueryCount: dbQueryMetrics.slowQueries.length,
    slowQueries: dbQueryMetrics.slowQueries.slice(-10), // Last 10 slow queries
    thresholdExceeded: avgTime > DB_AVG_THRESHOLD_MS
  };
};

/**
 * Reset performance metrics (useful for testing)
 */
const resetMetrics = () => {
  dbQueryMetrics.totalQueries = 0;
  dbQueryMetrics.totalTime = 0;
  dbQueryMetrics.slowQueries = [];
};

module.exports = {
  logQueryPerformance,
  logEndpointPerformance,
  getDbStats,
  resetMetrics,
  SIMPLE_QUERY_THRESHOLD_MS,
  COMPLEX_QUERY_THRESHOLD_MS,
  DB_AVG_THRESHOLD_MS,
  ENDPOINT_SLOW_THRESHOLD_MS
};


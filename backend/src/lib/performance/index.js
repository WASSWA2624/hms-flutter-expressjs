/**
 * Performance utilities barrel export
 * 
 * @description Centralized exports for performance metrics
 * Per performance.mdc: Performance metrics must be logged or monitored
 */

const {
  logQueryPerformance,
  logEndpointPerformance,
  getDbStats,
  resetMetrics,
  SIMPLE_QUERY_THRESHOLD_MS,
  COMPLEX_QUERY_THRESHOLD_MS,
  DB_AVG_THRESHOLD_MS,
  ENDPOINT_SLOW_THRESHOLD_MS
} = require('@lib/performance/metrics');

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


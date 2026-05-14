/**
 * Health check utilities barrel export
 * 
 * @description Centralized exports for health check helpers. Allows importing `@lib/health`.
 * Per health-checks.mdc: Health endpoints must use these utilities.
 */

const { healthCheck } = require('@lib/health/healthCheck');
const { readinessCheck } = require('@lib/health/readinessCheck');
const { livenessCheck } = require('@lib/health/livenessCheck');

module.exports = {
  healthCheck,
  readinessCheck,
  livenessCheck
};


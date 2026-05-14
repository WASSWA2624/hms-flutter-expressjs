/**
 * Liveness Check Utility
 * 
 * Minimal liveness check per health-checks.mdc
 * GET /live endpoint: Returns 200 if application process is alive
 * Used for container restart policies
 * Response format: { status: "alive" }
 */

/**
 * Liveness check function
 * Returns minimal response indicating process is alive
 * 
 * @returns {Object} Liveness check response
 */
const livenessCheck = () => {
  return {
    status: 'alive'
  };
};

module.exports = { livenessCheck };


/**
 * Config Barrel Export
 * 
 * Centralized export for all configuration modules
 * Allows importing config via @config/index
 * Per constants-env.mdc: All config modules accessible via @config/* aliases
 */

const env = require('@config/env');
const constants = require('@config/constants');
const jwt = require('@config/jwt');
const security = require('@config/security');
const cors = require('@config/cors');
const rateLimit = require('@config/rateLimit');
const roles = require('@config/roles');
const permissions = require('@config/permissions');
const featureFlags = require('@config/feature-flags');

module.exports = {
  env,
  constants,
  jwt,
  security,
  cors,
  rateLimit,
  roles,
  permissions,
  featureFlags
};


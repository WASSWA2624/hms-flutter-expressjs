/**
 * JWT Configuration
 * 
 * JWT configuration per auth-security.mdc
 * Reads JWT_SECRET from @config/env (validated to be ≥ 32 characters)
 */

const {
  JWT_SECRET,
  JWT_ACCESS_TOKEN_EXPIRATION,
  JWT_REFRESH_TOKEN_EXPIRATION,
} = require('@config/env');

// Validate JWT_SECRET length (should already be validated in env.js, but double-check)
if (!JWT_SECRET || JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be at least 32 characters long');
}

module.exports = {
  accessTokenExpiration: JWT_ACCESS_TOKEN_EXPIRATION,
  refreshTokenExpiration: JWT_REFRESH_TOKEN_EXPIRATION,
  algorithm: 'HS256',
  secret: JWT_SECRET
};


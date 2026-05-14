/**
 * Generate JWT Refresh Token
 * 
 * Generates a JWT refresh token for token renewal
 * Uses JWT configuration from @config/jwt
 * Refresh tokens typically have longer expiration than access tokens
 * 
 * @param {Object} payload - Token payload (typically user ID, email, role, etc.)
 * @param {string} [expiresIn] - Optional expiration override (defaults to config)
 * @returns {string} JWT refresh token
 */
const jwt = require('jsonwebtoken');
const jwtConfig = require('@config/jwt');
const { JWT_SECRET } = require('@config/env');
const crypto = require('crypto');

/**
 * Generate refresh token
 * 
 * @param {Object} payload - Token payload
 * @param {string} [expiresIn] - Optional expiration override
 * @returns {string} JWT refresh token
 */
const generateRefreshToken = (payload, expiresIn = null) => {
  // Use provided expiration or fall back to config
  const expiration = expiresIn || jwtConfig.refreshTokenExpiration || '7d';
  const algorithm = jwtConfig.algorithm || 'HS256';
  
  // Ensure JWT_SECRET is available
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is not configured. Please set JWT_SECRET in environment variables.');
  }
  
  const options = {
    expiresIn: expiration,
    algorithm: algorithm
  };

  const normalizedPayload =
    payload && typeof payload === 'object' && !Array.isArray(payload)
      ? { ...payload }
      : {};

  // Ensure refresh tokens are unique even when payload is omitted.
  if (!normalizedPayload.jti) {
    normalizedPayload.jti = crypto.randomBytes(16).toString('hex');
  }
  if (!normalizedPayload.type) {
    normalizedPayload.type = 'refresh';
  }

  return jwt.sign(normalizedPayload, JWT_SECRET, options);
};

module.exports = { generateRefreshToken };


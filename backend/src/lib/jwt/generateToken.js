/**
 * Generate JWT Access Token
 * 
 * Generates a JWT access token for authenticated users
 * Uses JWT configuration from @config/jwt
 * 
 * @param {Object} payload - Token payload (typically user ID, email, role, etc.)
 * @param {string} [expiresIn] - Optional expiration override (defaults to config)
 * @returns {string} JWT access token
 */
const jwt = require('jsonwebtoken');
const jwtConfig = require('@config/jwt');
const { JWT_SECRET } = require('@config/env');

/**
 * Generate access token
 * 
 * @param {Object} payload - Token payload
 * @param {string} [expiresIn] - Optional expiration override
 * @returns {string} JWT token
 */
const generateToken = (payload, expiresIn = null) => {
  // Use provided expiration or fall back to config
  const expiration = expiresIn || jwtConfig.accessTokenExpiration || '15m';
  const algorithm = jwtConfig.algorithm || 'HS256';
  
  // Ensure JWT_SECRET is available
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is not configured. Please set JWT_SECRET in environment variables.');
  }
  
  const options = {
    expiresIn: expiration,
    algorithm: algorithm
  };
  
  return jwt.sign(payload, JWT_SECRET, options);
};

module.exports = { generateToken };


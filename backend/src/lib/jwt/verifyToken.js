/**
 * Verify JWT Token
 * 
 * Verifies and decodes a JWT token
 * Uses JWT configuration from @config/jwt
 * 
 * @param {string} token - JWT token to verify
 * @returns {Object} Decoded token payload
 * @throws {Error} If token is invalid, expired, or malformed
 */
const jwt = require('jsonwebtoken');
const jwtConfig = require('@config/jwt');
const { JWT_SECRET } = require('@config/env');

/**
 * Verify and decode JWT token
 * 
 * @param {string} token - JWT token to verify
 * @returns {Object} Decoded token payload
 * @throws {Error} If token verification fails
 */
const verifyToken = (token) => {
  // Ensure JWT_SECRET is available
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is not configured. Please set JWT_SECRET in environment variables.');
  }
  
  const algorithm = jwtConfig.algorithm || 'HS256';
  
  const options = {
    algorithms: [algorithm]
  };
  
  try {
    // Verify and decode the token
    const decoded = jwt.verify(token, JWT_SECRET, options);
    return decoded;
  } catch (err) {
    // Map JWT errors to user-friendly messages
    if (err.name === 'TokenExpiredError') {
      throw new Error('Token has expired');
    } else if (err.name === 'JsonWebTokenError') {
      throw new Error('Invalid token');
    } else if (err.name === 'NotBeforeError') {
      throw new Error('Token not active yet');
    } else {
      throw new Error('Token verification failed');
    }
  }
};

module.exports = { verifyToken };


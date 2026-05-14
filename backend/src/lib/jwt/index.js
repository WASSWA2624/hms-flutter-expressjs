/**
 * JWT utilities barrel export
 *
 * @description Centralized exports for JWT helpers. Allows importing `@lib/jwt`.
 */

const { generateToken } = require('@lib/jwt/generateToken');
const { generateRefreshToken } = require('@lib/jwt/generateRefreshToken');
const { verifyToken } = require('@lib/jwt/verifyToken');

module.exports = {
  generateToken,
  generateRefreshToken,
  verifyToken
};



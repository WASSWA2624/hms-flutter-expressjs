/**
 * Password Hashing Utility
 * 
 * Hashes passwords using bcryptjs per auth-security.mdc
 * Passwords must never be stored in plaintext
 * 
 * @param {string} password - Plain text password to hash
 * @param {number} [saltRounds=10] - Number of salt rounds (default: 10)
 * @returns {Promise<string>} Hashed password
 */
const bcrypt = require('bcryptjs');

/**
 * Hash a password using bcryptjs
 * 
 * @param {string} password - Plain text password
 * @param {number} [saltRounds=10] - Number of salt rounds (higher = more secure but slower)
 * @returns {Promise<string>} Hashed password
 */
const hashPassword = async (password, saltRounds = 10) => {
  if (!password || typeof password !== 'string') {
    throw new Error('Password must be a non-empty string');
  }
  
  if (password.length < 8) {
    throw new Error('Password must be at least 8 characters long');
  }
  
  try {
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    return hashedPassword;
  } catch (err) {
    throw new Error(`Failed to hash password: ${err.message}`);
  }
};

module.exports = { hashPassword };


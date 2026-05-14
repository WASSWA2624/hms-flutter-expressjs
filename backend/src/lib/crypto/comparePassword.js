/**
 * Password Comparison Utility
 * 
 * Compares a plain text password with a hashed password using bcryptjs
 * Used for authentication verification
 * 
 * @param {string} plainPassword - Plain text password to compare
 * @param {string} hashedPassword - Hashed password from database
 * @returns {Promise<boolean>} True if passwords match, false otherwise
 */
const bcrypt = require('bcryptjs');

/**
 * Compare a plain text password with a hashed password
 * 
 * @param {string} plainPassword - Plain text password
 * @param {string} hashedPassword - Hashed password
 * @returns {Promise<boolean>} True if passwords match
 */
const comparePassword = async (plainPassword, hashedPassword) => {
  if (!plainPassword || typeof plainPassword !== 'string') {
    throw new Error('Plain password must be a non-empty string');
  }
  
  if (!hashedPassword || typeof hashedPassword !== 'string') {
    throw new Error('Hashed password must be a non-empty string');
  }
  
  try {
    const isMatch = await bcrypt.compare(plainPassword, hashedPassword);
    return isMatch;
  } catch (err) {
    throw new Error(`Failed to compare passwords: ${err.message}`);
  }
};

module.exports = { comparePassword };


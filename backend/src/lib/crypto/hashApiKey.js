/**
 * API Key Hashing Utility
 * 
 * Hashes API keys using Argon2id per auth-security.mdc
 * API keys must be hashed with Argon2id
 * Plaintext storage of API keys is forbidden
 * 
 * @param {string} apiKey - Plain text API key to hash
 * @returns {Promise<string>} Hashed API key
 */
const getArgon2 = () => {
  try {
    // Lazy-load to avoid crashing app/test startup if native module is unavailable
    // (e.g., missing build for current platform/Node version).
    // Only API key hashing/verification should require argon2 at runtime.
    return require('argon2');
  } catch (err) {
    throw new Error(
      'Argon2 dependency is not available in this runtime. ' +
      'API key hashing/verification requires a working argon2 native build.'
    );
  }
};

/**
 * Hash an API key using Argon2id
 * 
 * @param {string} apiKey - Plain text API key
 * @returns {Promise<string>} Hashed API key
 */
const hashApiKey = async (apiKey) => {
  if (!apiKey || typeof apiKey !== 'string') {
    throw new Error('API key must be a non-empty string');
  }
  
  try {
    const argon2 = getArgon2();
    // Argon2id with recommended parameters
    // memoryCost: 65536 (64 MB), timeCost: 3, parallelism: 4
    const hashedApiKey = await argon2.hash(apiKey, {
      type: argon2.argon2id,
      memoryCost: 65536, // 64 MB
      timeCost: 3,
      parallelism: 4
    });
    
    return hashedApiKey;
  } catch (err) {
    throw new Error(`Failed to hash API key: ${err.message}`);
  }
};

/**
 * Verify an API key against a hashed API key
 * 
 * @param {string} hashedApiKey - Hashed API key from database
 * @param {string} plainApiKey - Plain text API key to verify
 * @returns {Promise<boolean>} True if API keys match, false otherwise
 */
const verifyApiKey = async (hashedApiKey, plainApiKey) => {
  if (!hashedApiKey || typeof hashedApiKey !== 'string') {
    throw new Error('Hashed API key must be a non-empty string');
  }
  
  if (!plainApiKey || typeof plainApiKey !== 'string') {
    throw new Error('Plain API key must be a non-empty string');
  }
  
  try {
    const argon2 = getArgon2();
    const isMatch = await argon2.verify(hashedApiKey, plainApiKey);
    return isMatch;
  } catch (err) {
    // Argon2 throws on verification failure, return false instead
    if (err.message.includes('verification failed')) {
      return false;
    }
    throw new Error(`Failed to verify API key: ${err.message}`);
  }
};

module.exports = { hashApiKey, verifyApiKey };


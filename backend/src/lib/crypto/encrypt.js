/**
 * AES-256 Encryption Helper
 * 
 * Encrypts sensitive data using AES-256-GCM (authenticated encryption)
 * Per compliance.mdc: AES-256 for data at rest and in transit
 * 
 * @param {string} plaintext - Data to encrypt
 * @param {string} [key] - Optional encryption key (defaults to derived from JWT_SECRET)
 * @returns {string} Encrypted data in format: iv:authTag:encryptedData (base64)
 */
const crypto = require('crypto');
const { JWT_SECRET } = require('@config/env');

/**
 * Derive a 32-byte key from a secret using SHA-256
 * 
 * @param {string} secret - Secret to derive key from
 * @returns {Buffer} 32-byte key
 */
const deriveKey = (secret) => {
  return crypto.createHash('sha256').update(secret).digest();
};

/**
 * Encrypt data using AES-256-GCM
 * 
 * @param {string} plaintext - Data to encrypt
 * @param {string} [key] - Optional encryption key
 * @returns {string} Encrypted data (iv:authTag:encryptedData in base64)
 */
const encrypt = (plaintext, key = null) => {
  if (!plaintext || typeof plaintext !== 'string') {
    throw new Error('Plaintext must be a non-empty string');
  }
  
  // Derive encryption key from JWT_SECRET or use provided key
  const encryptionKey = key 
    ? Buffer.from(key, 'utf8').slice(0, 32) 
    : deriveKey(JWT_SECRET);
  
  // Ensure key is exactly 32 bytes for AES-256
  if (encryptionKey.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (256 bits) for AES-256');
  }
  
  // Generate random 12-byte IV for GCM
  const iv = crypto.randomBytes(12);
  
  // Create cipher
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
  
  // Encrypt the data
  let encrypted = cipher.update(plaintext, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  
  // Get authentication tag
  const authTag = cipher.getAuthTag();
  
  // Return format: iv:authTag:encryptedData (all base64)
  return `${iv.toString('base64')}:${authTag.toString('base64')}:${encrypted}`;
};

module.exports = { encrypt };


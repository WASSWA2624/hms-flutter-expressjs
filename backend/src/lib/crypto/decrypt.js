/**
 * AES-256 Decryption Helper
 * 
 * Decrypts data encrypted with AES-256-GCM
 * Per compliance.mdc: AES-256 for data at rest and in transit
 * 
 * @param {string} encryptedData - Encrypted data in format: iv:authTag:encryptedData (base64)
 * @param {string} [key] - Optional decryption key (defaults to derived from JWT_SECRET)
 * @returns {string} Decrypted plaintext
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
 * Decrypt data using AES-256-GCM
 * 
 * @param {string} encryptedData - Encrypted data (iv:authTag:encryptedData in base64)
 * @param {string} [key] - Optional decryption key
 * @returns {string} Decrypted plaintext
 */
const decrypt = (encryptedData, key = null) => {
  if (!encryptedData || typeof encryptedData !== 'string') {
    throw new Error('Encrypted data must be a non-empty string');
  }
  
  // Parse the encrypted data format: iv:authTag:encryptedData
  const parts = encryptedData.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted data format. Expected: iv:authTag:encryptedData');
  }
  
  const [ivBase64, authTagBase64, encryptedBase64] = parts;
  
  // Decode base64 components
  const iv = Buffer.from(ivBase64, 'base64');
  const authTag = Buffer.from(authTagBase64, 'base64');
  const encrypted = encryptedBase64;
  
  // Derive decryption key from JWT_SECRET or use provided key
  const decryptionKey = key 
    ? Buffer.from(key, 'utf8').slice(0, 32) 
    : deriveKey(JWT_SECRET);
  
  // Ensure key is exactly 32 bytes for AES-256
  if (decryptionKey.length !== 32) {
    throw new Error('Decryption key must be 32 bytes (256 bits) for AES-256');
  }
  
  // Create decipher
  const decipher = crypto.createDecipheriv('aes-256-gcm', decryptionKey, iv);
  decipher.setAuthTag(authTag);
  
  // Decrypt the data
  let decrypted = decipher.update(encrypted, 'base64', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
};

module.exports = { decrypt };


/**
 * AES-256-GCM Buffer Decryption Helper
 *
 * @description Decrypts binary data encrypted with encryptBuffer() format.
 *
 * Format: MAGIC(4 bytes) + IV(12 bytes) + AUTH_TAG(16 bytes) + CIPHERTEXT(N bytes)
 *
 * @param {Buffer} buffer - Encrypted buffer
 * @returns {Buffer} Decrypted buffer
 * @throws {Error} If buffer is invalid or authentication fails
 */
const crypto = require('crypto');
const { JWT_SECRET, ENCRYPTION_KEY } = require('@config/env');
const { STORAGE_ENCRYPTION_MAGIC } = require('@config/constants');

const deriveKey = (secret) => crypto.createHash('sha256').update(secret).digest();

const getKey = () => {
  if (ENCRYPTION_KEY) {
    return Buffer.from(String(ENCRYPTION_KEY).trim(), 'hex');
  }
  return deriveKey(JWT_SECRET);
};

const decryptBuffer = (buffer) => {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4 + 12 + 16 + 1) {
    throw new Error('Encrypted buffer is invalid');
  }

  const magic = buffer.subarray(0, 4).toString('utf8');
  if (magic !== String(STORAGE_ENCRYPTION_MAGIC)) {
    throw new Error('Encrypted buffer has invalid magic header');
  }

  const iv = buffer.subarray(4, 16);
  const authTag = buffer.subarray(16, 32);
  const ciphertext = buffer.subarray(32);

  const key = getKey();
  if (key.length !== 32) {
    throw new Error('Decryption key must be 32 bytes (256 bits) for AES-256');
  }

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);

  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
};

module.exports = { decryptBuffer };



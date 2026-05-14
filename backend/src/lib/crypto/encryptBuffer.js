/**
 * AES-256-GCM Buffer Encryption Helper
 *
 * @description Encrypts binary data using AES-256-GCM (authenticated encryption).
 * Per compliance.mdc: AES-256 for data at rest.
 *
 * Format: MAGIC(4 bytes) + IV(12 bytes) + AUTH_TAG(16 bytes) + CIPHERTEXT(N bytes)
 *
 * @param {Buffer} buffer - Data to encrypt
 * @returns {Buffer} Encrypted buffer
 * @throws {Error} If buffer is invalid
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

const encryptBuffer = (buffer) => {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new Error('Buffer must be a non-empty Buffer');
  }

  const key = getKey();
  if (key.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (256 bits) for AES-256');
  }

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  const ciphertext = Buffer.concat([cipher.update(buffer), cipher.final()]);
  const authTag = cipher.getAuthTag();

  const magic = Buffer.from(String(STORAGE_ENCRYPTION_MAGIC), 'utf8');
  if (magic.length !== 4) {
    throw new Error('STORAGE_ENCRYPTION_MAGIC must be 4 bytes');
  }

  return Buffer.concat([magic, iv, authTag, ciphertext]);
};

module.exports = { encryptBuffer };



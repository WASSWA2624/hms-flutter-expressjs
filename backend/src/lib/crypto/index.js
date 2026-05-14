/**
 * Crypto utilities barrel export
 *
 * @description Centralized exports for crypto helpers. Allows importing `@lib/crypto`.
 */

const { hashPassword } = require('@lib/crypto/hashPassword');
const { comparePassword } = require('@lib/crypto/comparePassword');
const { hashApiKey, verifyApiKey } = require('@lib/crypto/hashApiKey');
const { encrypt } = require('@lib/crypto/encrypt');
const { decrypt } = require('@lib/crypto/decrypt');
const { encryptBuffer } = require('@lib/crypto/encryptBuffer');
const { decryptBuffer } = require('@lib/crypto/decryptBuffer');

module.exports = {
  hashPassword,
  comparePassword,
  hashApiKey,
  verifyApiKey,
  encrypt,
  decrypt,
  encryptBuffer,
  decryptBuffer
};



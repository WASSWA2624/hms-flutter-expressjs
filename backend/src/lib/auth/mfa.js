const crypto = require('crypto');
const { decrypt } = require('@lib/crypto');
const { ROLES, normalizeRoleName } = require('@config/roles');

const PRIVILEGED_MFA_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const TOTP_WINDOW = 1;
const TOTP_STEP_SECONDS = 30;
const TOTP_DIGITS = 6;
const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

const normalizeCode = (value) => String(value || '').replace(/\s+/g, '');

const isPrivilegedRole = (roles = []) =>
  (Array.isArray(roles) ? roles : [roles])
    .map((role) => normalizeRoleName(role) || String(role || '').trim().toUpperCase())
    .filter(Boolean)
    .some((role) => PRIVILEGED_MFA_ROLES.has(role));

const decodeBase32 = (value) => {
  const normalized = String(value || '')
    .replace(/[\s-]+/g, '')
    .replace(/=+$/g, '')
    .toUpperCase();

  if (!normalized) {
    throw new Error('MFA secret is empty');
  }

  let bits = '';
  for (const character of normalized) {
    const index = BASE32_ALPHABET.indexOf(character);
    if (index === -1) {
      throw new Error('MFA secret is not valid base32');
    }
    bits += index.toString(2).padStart(5, '0');
  }

  const bytes = [];
  for (let cursor = 0; cursor + 8 <= bits.length; cursor += 8) {
    bytes.push(Number.parseInt(bits.slice(cursor, cursor + 8), 2));
  }

  return Buffer.from(bytes);
};

const resolveSecretBuffer = (secret) => {
  const normalized = String(secret || '').trim();
  if (!normalized) {
    throw new Error('MFA secret is empty');
  }

  const compact = normalized.replace(/[\s-]+/g, '');
  if (/^[A-Z2-7]+=*$/i.test(compact)) {
    return decodeBase32(compact);
  }

  if (/^[a-f0-9]+$/i.test(compact) && compact.length % 2 === 0) {
    return Buffer.from(compact, 'hex');
  }

  return Buffer.from(normalized, 'utf8');
};

const generateHotpCode = (secretBuffer, counter, digits = TOTP_DIGITS) => {
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter));

  const hmac = crypto
    .createHmac('sha1', secretBuffer)
    .update(counterBuffer)
    .digest();

  const offset = hmac[hmac.length - 1] & 0x0f;
  const binaryCode =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);

  const otp = binaryCode % (10 ** digits);
  return String(otp).padStart(digits, '0');
};

const verifyTotpCode = ({
  secret,
  code,
  digits = TOTP_DIGITS,
  stepSeconds = TOTP_STEP_SECONDS,
  window = TOTP_WINDOW,
  now = Date.now(),
}) => {
  const normalizedCode = normalizeCode(code);
  if (!/^\d+$/.test(normalizedCode)) {
    return false;
  }

  const secretBuffer = resolveSecretBuffer(secret);
  const currentCounter = Math.floor(now / 1000 / stepSeconds);

  for (let offset = -window; offset <= window; offset += 1) {
    const candidate = generateHotpCode(secretBuffer, currentCounter + offset, digits);
    if (candidate === normalizedCode) {
      return true;
    }
  }

  return false;
};

const resolveUserMfaSecret = (userMfa = {}) => {
  const encrypted = String(userMfa.secret_encrypted || '').trim();
  if (!encrypted) {
    throw new Error('MFA secret is empty');
  }

  if (encrypted.includes(':')) {
    return decrypt(encrypted);
  }

  return encrypted;
};

const verifyUserMfaCode = (userMfa = {}, code, options = {}) => {
  try {
    return verifyTotpCode({
      secret: resolveUserMfaSecret(userMfa),
      code,
      now: options.now,
    });
  } catch {
    return false;
  }
};

module.exports = {
  PRIVILEGED_MFA_ROLES,
  isPrivilegedRole,
  normalizeCode,
  verifyTotpCode,
  verifyUserMfaCode,
};

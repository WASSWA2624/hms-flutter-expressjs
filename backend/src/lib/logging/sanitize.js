/**
 * Log Sanitization Utility
 * 
 * Sanitizes PII/sensitive data from logs per error-logging.mdc
 * Prevents sensitive information (passwords, tokens, API keys) from being logged
 * 
 * @param {any} data - Data to sanitize (object, string, array, etc.)
 * @returns {any} Sanitized data with sensitive fields masked
 */

// Fields that should be completely masked
const SENSITIVE_FIELDS = [
  'password',
  'passwd',
  'pwd',
  'secret',
  'token',
  'access_token',
  'refresh_token',
  'api_key',
  'apikey',
  'apiKey',
  'auth_token',
  'authorization',
  'jwt',
  'session_id',
  'sessionId',
  'private_key',
  'privateKey',
  'secret_key',
  'secretKey',
  'aws_access_key_id',
  'aws_secret_access_key',
  'database_url',
  'connection_string',
  'credit_card',
  'creditCard',
  'card_number',
  'cardNumber',
  'cvv',
  'cvc',
  'ssn',
  'social_security_number',
  'phi',
  'protected_health_information'
];

// Fields that should be partially masked (show first/last few characters)
const PARTIALLY_MASKED_FIELDS = [
  'email', // May want to partially mask in some contexts
  'phone',
  'phone_number',
  'phoneNumber',
  'account_number',
  'accountNumber'
];

// Mask string completely
const maskString = (str, visibleChars = 0) => {
  if (!str || typeof str !== 'string') return str;
  if (str.length <= visibleChars * 2) return '***';
  return str.substring(0, visibleChars) + '***' + str.substring(str.length - visibleChars);
};

// Check if a field name matches sensitive patterns (case-insensitive)
const isSensitiveField = (fieldName) => {
  const lowerField = fieldName.toLowerCase();
  return SENSITIVE_FIELDS.some((sensitive) => lowerField.includes(sensitive.toLowerCase()));
};

// Check if a field name should be partially masked
const isPartiallyMaskedField = (fieldName) => {
  const lowerField = fieldName.toLowerCase();
  return PARTIALLY_MASKED_FIELDS.some((field) => lowerField.includes(field.toLowerCase()));
};

/**
 * Sanitize an object recursively
 * 
 * @param {Object} obj - Object to sanitize
 * @param {number} depth - Current recursion depth (prevents infinite loops)
 * @returns {Object} Sanitized object
 */
const sanitizeObject = (obj, depth = 0) => {
  // Prevent infinite recursion
  if (depth > 10) return '[Max depth reached]';
  
  if (obj === null || obj === undefined) return obj;
  
  // Handle arrays
  if (Array.isArray(obj)) {
    return obj.map((item) => sanitizeObject(item, depth + 1));
  }
  
  // Handle objects
  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      if (isSensitiveField(key)) {
        // Completely mask sensitive fields
        sanitized[key] = '***REDACTED***';
      } else if (isPartiallyMaskedField(key) && typeof value === 'string') {
        // Partially mask certain fields
        sanitized[key] = maskString(value, 2);
      } else if (typeof value === 'string' && value.length > 0) {
        // Check if the value itself looks like a sensitive token
        if (value.length > 20 && /^[A-Za-z0-9_-]+$/.test(value)) {
          // Looks like a token/JWT - mask it
          sanitized[key] = maskString(value, 4);
        } else {
          sanitized[key] = sanitizeObject(value, depth + 1);
        }
      } else {
        sanitized[key] = sanitizeObject(value, depth + 1);
      }
    }
    return sanitized;
  }
  
  // Handle strings - check if they look like tokens/secrets
  if (typeof obj === 'string') {
    // If it's a long alphanumeric string, it might be a token
    if (obj.length > 20 && /^[A-Za-z0-9_-]+$/.test(obj)) {
      return maskString(obj, 4);
    }
    return obj;
  }
  
  return obj;
};

/**
 * Sanitize data for logging
 * 
 * @param {any} data - Data to sanitize
 * @returns {any} Sanitized data
 */
const sanitize = (data) => {
  if (data === null || data === undefined) return data;
  
  // Handle primitives
  if (typeof data !== 'object') {
    if (typeof data === 'string') {
      // Check if string looks like a token/secret
      if (data.length > 20 && /^[A-Za-z0-9_-]+$/.test(data)) {
        return maskString(data, 4);
      }
    }
    return data;
  }
  
  return sanitizeObject(data);
};

module.exports = { sanitize };


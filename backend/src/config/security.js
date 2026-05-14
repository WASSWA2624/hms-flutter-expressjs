/**
 * Security Configuration
 * 
 * Security configuration per auth-security.mdc and compliance.mdc
 * Includes password requirements, API key requirements, encryption settings, CSRF protection
 */

const SecurityConfig = {
  // Password Requirements
  password: {
    minLength: 8,
    requireUppercase: true,
    requireLowercase: true,
    requireNumber: true,
    requireSymbol: true
  },
  
  // API Key Requirements
  apiKey: {
    minLength: 32,
    requireRandom: true
  },
  
  // Encryption Settings
  encryption: {
    algorithm: 'aes-256-gcm',
    keyLength: 32 // 256 bits
  },
  
  // CSRF Protection
  csrf: {
    enabled: true,
    tokenLength: 32
  },

  // Security headers
  headers: {
    contentSecurityPolicy: "default-src 'self'"
  }
};

module.exports = SecurityConfig;


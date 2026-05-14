/**
 * Rate Limiting Configuration
 * 
 * Rate limit configuration per rate-limiting.mdc
 * Environment-aware (different limits for dev/staging/production)
 */

const { NODE_ENV } = require('@config/env');

const RateLimitConfig = {
  // Global limits
  global: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: NODE_ENV === 'development' ? 1000 : 100 // Higher limit in development
  },
  
  // Authenticated user limits (higher than IP-based)
  authenticated: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: NODE_ENV === 'development' ? 5000 : 1000
  },
  
  // Endpoint-specific limits
  endpoints: {
    // Authentication endpoints (stricter limits)
    auth: {
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 5
    },
    
    // Registration endpoint
    register: {
      windowMs: 60 * 60 * 1000, // 1 hour
      max: 3
    },
    
    // Password reset endpoint
    passwordReset: {
      windowMs: 60 * 60 * 1000, // 1 hour
      max: 3
    },
    
    // File upload endpoints
    upload: {
      windowMs: 60 * 60 * 1000, // 1 hour
      max: 10
    },
    
    // Search endpoints (higher limit for better UX)
    search: {
      windowMs: 60 * 1000, // 1 minute
      max: 60
    }
  },
  
  // Default window and max (used by defaultRateLimit middleware)
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: NODE_ENV === 'development' ? 1000 : 100
};

module.exports = RateLimitConfig;


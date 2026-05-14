/**
 * Express App Initialization
 * 
 * Express app setup with all required middlewares per architecture.mdc
 * Middleware order:
 * 1. Security headers
 * 2. CORS (handles preflight requests)
 * 3. Cookie parser
 * 4. Session middleware
 * 5. JSON parser
 * 6. i18n locale detection
 * 7. Rate limit
 * 8. API versioning/deprecation headers
 * 9. CSRF protection
 * 10. Performance monitoring
 * 11. Routes (mounted from router)
 * 12. Error middleware (must be last)
 * 
 * Per architecture.mdc: Express.js is the only HTTP framework allowed
 */

const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const { corsOptions } = require('@config/cors');
const { TRUST_PROXY } = require('@config/env');
const securityHeaders = require('@middlewares/security.middleware');
const sessionMiddleware = require('@middlewares/session.middleware');
const csrfMiddleware = require('@middlewares/csrf.middleware');
const i18nMiddleware = require('@middlewares/i18n.middleware');
const { initializeRequestContext } = require('@middlewares/request-context.middleware');
const { defaultRateLimit } = require('@middlewares/rateLimit.middleware');
const versioningMiddleware = require('@middlewares/versioning.middleware');
const { offlineSupportMiddleware } = require('@middlewares/offline.middleware');
const performanceMiddleware = require('@middlewares/performance.middleware');
const errorMiddleware = require('@middlewares/error.middleware');

// Import root router (created in Step 1.31)
const router = require('@app/router');

/**
 * Create and configure Express application
 * 
 * @returns {Object} Configured Express app
 */
const createApp = () => {
  const app = express();
  
  try {
    // Reverse-proxy awareness keeps client IP/protocol correct behind Nginx.
    app.set('trust proxy', TRUST_PROXY);

    // 1. Security headers middleware
    app.use(securityHeaders());

    // 1.5. Allow Private Network Access preflight for LAN/mobile development.
    // Chrome sends Access-Control-Request-Private-Network for some LAN requests.
    app.use((req, res, next) => {
      if (req.headers['access-control-request-private-network'] === 'true') {
        res.header('Access-Control-Allow-Private-Network', 'true');
      }
      next();
    });

    // 2. CORS middleware (handles preflight requests)
    app.use(cors(corsOptions));
    
    // 3. Cookie parser middleware
    app.use(cookieParser());
    
    // 4. Session middleware (for CSRF token storage)
    app.use(sessionMiddleware());
    
    // 5. JSON parser middleware
    app.use(express.json());
    app.use(express.urlencoded({ extended: true }));
    
    // 6. i18n locale detection middleware
    app.use(i18nMiddleware());

    // 7. Request context middleware
    app.use(initializeRequestContext());

    // 8. Rate limit middleware (before routes)
    app.use(defaultRateLimit());

    // 9. API versioning/deprecation headers
    app.use(versioningMiddleware());

    // 9.5. Offline support contract (conditional GET, idempotency, sync metadata)
    app.use(offlineSupportMiddleware());
    
    // 10. CSRF middleware for state-changing routes
    app.use(csrfMiddleware());

    // 11. Performance monitoring middleware (before routes)
    app.use(performanceMiddleware());
    
    // 12. Routes (mounted from router)
    // Router will mount all module routes under /api/v1/ in Step 1.31
    app.use(router);
    
    // 13. Error middleware (must be last - catches all errors)
    app.use(errorMiddleware);
  } catch (err) {
    throw err;
  }
  
  return app;
};

module.exports = createApp;


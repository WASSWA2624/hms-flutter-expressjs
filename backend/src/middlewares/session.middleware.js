/**
 * Session Middleware
 *
 * Provides session storage for CSRF tokens and other session data.
 * Uses simple in-memory session store for development.
 * Per auth-security.mdc: CSRF protection requires session storage.
 */

const sessions = new Map();
const env = require('@config/env');

/**
 * Simple in-memory session store
 * In production, use Redis or similar.
 */
const store = {
  /**
   * Get session by ID.
   *
   * @param {string} sessionId - Session ID
   * @returns {Object|null} Session data or null
   */
  get: (sessionId) => {
    return sessions.get(sessionId) || null;
  },

  /**
   * Set session data.
   *
   * @param {string} sessionId - Session ID
   * @param {Object} data - Session data
   */
  set: (sessionId, data) => {
    sessions.set(sessionId, {
      ...(store.get(sessionId) || {}),
      ...data,
      lastAccessed: Date.now()
    });
  },

  /**
   * Delete session.
   *
   * @param {string} sessionId - Session ID
   */
  delete: (sessionId) => {
    sessions.delete(sessionId);
  },

  /**
   * Clear expired sessions (older than 24 hours).
   */
  clearExpired: () => {
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours

    for (const [key, value] of sessions.entries()) {
      if (now - value.lastAccessed > maxAge) {
        sessions.delete(key);
      }
    }
  }
};

/**
 * Session middleware
 * Attaches session object to request
 *
 * @returns {Function} Express middleware
 */
const sessionMiddleware = () => {
  return (req, res, next) => {
    // Get or create session ID from cookie
    let sessionId = req.cookies?.sessionId;

    if (!sessionId) {
      // Generate new session ID
      const crypto = require('crypto');
      sessionId = crypto.randomBytes(16).toString('hex');
      
      // Set cookie (httpOnly, secure in production)
      res.cookie('sessionId', sessionId, {
        httpOnly: true,
        secure: env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
      });
    }

    // Attach session to request
    req.session = store.get(sessionId) || {};
    req.sessionId = sessionId;

    // Save session on response
    res.on('finish', () => {
      store.set(sessionId, req.session);
    });

    // Periodically clear expired sessions
    if (Math.random() < 0.01) { // 1% of requests
      store.clearExpired();
    }

    return next();
  };
};

module.exports = sessionMiddleware;

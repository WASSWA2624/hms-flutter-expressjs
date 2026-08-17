/**
 * Session Middleware
 *
 * Provides session storage for CSRF tokens and other session data.
 * Uses simple in-memory session store for development.
 * Per auth-security.mdc: CSRF protection requires session storage.
 *
 * Session mutations are persisted immediately so a follow-up request
 * (e.g. POST after GET /csrf-token) cannot race the response `finish`
 * hook and validate against a stale CSRF token.
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
   * Replace session data (no merge with prior keys).
   *
   * @param {string} sessionId - Session ID
   * @param {Object} data - Session data
   */
  replace: (sessionId, data) => {
    sessions.set(sessionId, {
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
 * Persist session mutations as they happen so CSRF token reads cannot race
 * the asynchronous response `finish` save.
 *
 * @param {string} sessionId
 * @param {Object} sessionData
 * @returns {Proxy}
 */
const createSessionProxy = (sessionId, sessionData) => {
  const persist = () => {
    const { lastAccessed: _ignored, ...data } = sessionData;
    store.replace(sessionId, data);
  };

  return new Proxy(sessionData, {
    set(target, prop, value) {
      target[prop] = value;
      persist();
      return true;
    },
    deleteProperty(target, prop) {
      delete target[prop];
      persist();
      return true;
    }
  });
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
      
      // Set cookie (httpOnly, secure in production).
      //
      // The web client is served from its own origin and calls the API
      // cross-site, so `SameSite=Strict` meant the browser never sent this
      // cookie back and every request minted a new session — which broke CSRF
      // validation for every mutation. `SameSite=None` is required for a
      // cross-site cookie and is only legal alongside `Secure`, so it is used
      // when running over HTTPS and `Lax` is kept for plain-HTTP development.
      const isSecureContext = env.NODE_ENV === 'production';
      res.cookie('sessionId', sessionId, {
        httpOnly: true,
        secure: isSecureContext,
        sameSite: isSecureContext ? 'none' : 'lax',
        maxAge: 24 * 60 * 60 * 1000 // 24 hours
      });
    }

    const existing = store.get(sessionId) || {};
    const { lastAccessed: _ignored, ...sessionData } = existing;

    // Attach session to request (immediate-persist proxy)
    req.session = createSessionProxy(sessionId, { ...sessionData });
    req.sessionId = sessionId;

    // Final flush on response end (covers in-place mutations of nested objects)
    res.on('finish', () => {
      const { lastAccessed: _finishIgnored, ...data } = req.session || {};
      store.replace(sessionId, data);
    });

    // Periodically clear expired sessions
    if (Math.random() < 0.01) { // 1% of requests
      store.clearExpired();
    }

    return next();
  };
};

module.exports = sessionMiddleware;
module.exports._store = store;
module.exports._createSessionProxy = createSessionProxy;

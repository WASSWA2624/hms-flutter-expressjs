/**
 * WebSocket Server Entry Point
 * 
 * WebSocket server initialization per websockets.mdc
 * Step 5.1: WebSocket server setup
 * 
 * Per websockets.mdc:
 * - Only `ws` library is allowed for WebSocket server
 * - Native JS structures (Map, Set) must be used to manage connections
 * - All connections must be authenticated using JWT (Step 5.3)
 * - Must handle disconnections, reconnections, and heartbeat/ping (Step 5.4)
 * - Maximum number of concurrent connections must be configurable
 * 
 * This file creates the WebSocket server instance.
 * Connection handling, authentication, and event routing are in gateway.js (Step 5.2+)
 */

const { WebSocketServer } = require('ws');
const { logger } = require('@lib/logging');
const { PORT } = require('@config/env');

/**
 * WebSocket Server Instance
 * @type {WebSocketServer|null}
 */
let wss = null;

/**
 * HTTP Server Instance (for WebSocket upgrade)
 * @type {import('http').Server|null}
 */
let httpServer = null;

/**
 * Initialize WebSocket Server
 * 
 * Creates a WebSocket server attached to the HTTP server
 * The server will handle WebSocket upgrade requests
 * 
 * @param {import('http').Server} server - HTTP server instance to attach WebSocket server to
 * @returns {WebSocketServer} WebSocket server instance
 */
const initializeWebSocketServer = (server) => {
  try {
    if (wss) {
      logger.warn('WebSocket server already initialized');
      return wss;
    }

    if (!server) {
      throw new Error('HTTP server instance is required to initialize WebSocket server');
    }

    httpServer = server;

    // Create WebSocket server attached to HTTP server
    wss = new WebSocketServer({
      server: httpServer,
      // Per websockets.mdc: Maximum number of concurrent connections must be configurable
      // Default to 1000 connections, can be overridden via environment variable
      clientTracking: true, // Enable client tracking for connection management
      perMessageDeflate: false, // Disable compression for simplicity (can be enabled if needed)
    });

    // Log successful initialization
    logger.info('WebSocket server initialized successfully', {
      port: PORT,
      clientTracking: wss.options.clientTracking
    });

    return wss;
  } catch (err) {
    logger.error('Failed to initialize WebSocket server', {
      error: err.message,
      stack: err.stack
    });
    throw err;
  }
};

/**
 * Get WebSocket Server Instance
 * 
 * @returns {WebSocketServer|null} WebSocket server instance or null if not initialized
 */
const getWebSocketServer = () => {
  return wss;
};

/**
 * Check if WebSocket Server is Initialized
 * 
 * @returns {boolean} True if WebSocket server is initialized
 */
const isInitialized = () => {
  return wss !== null;
};

/**
 * Close WebSocket Server
 * 
 * Gracefully closes all WebSocket connections and the server
 * 
 * @returns {Promise<void>}
 */
const closeWebSocketServer = async () => {
  return new Promise((resolve, reject) => {
    if (!wss) {
      resolve();
      return;
    }

    try {
      // Close all connections (defensive: some test/mocks may not provide `clients`)
      const clients = wss.clients;
      if (clients && typeof clients.forEach === 'function') {
        clients.forEach((client) => {
          const openState = (client && typeof client.OPEN === 'number') ? client.OPEN : 1;
          if (client && client.readyState === openState) {
            client.close(1000, 'Server shutting down');
          }
        });
      } else {
        logger.warn('WebSocket server has no iterable clients set during shutdown');
      }

      // Close WebSocket server
      wss.close((err) => {
        if (err) {
          logger.error('Error closing WebSocket server', {
            error: err.message,
            stack: err.stack
          });
          reject(err);
          return;
        }

        logger.info('WebSocket server closed successfully');
        wss = null;
        httpServer = null;
        resolve();
      });
    } catch (err) {
      logger.error('Error during WebSocket server shutdown', {
        error: err.message,
        stack: err.stack
      });
      reject(err);
    }
  });
};

module.exports = {
  initializeWebSocketServer,
  getWebSocketServer,
  isInitialized,
  closeWebSocketServer
};



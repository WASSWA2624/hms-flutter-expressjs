/**
 * WebSocket Gateway
 * 
 * Handles connection routing and management per websockets.mdc
 * Step 5.2: WebSocket gateway
 * Step 5.3: WebSocket authentication (JWT)
 * Step 5.4: WebSocket heartbeat/ping mechanism
 * Step 5.5: WebSocket RBAC enforcement
 * 
 * Per websockets.mdc:
 * - Must maintain a Map of `UserID → WebSocket` for routing messages
 * - Must handle disconnections, reconnections, and heartbeat/ping
 * - All messages must be JSON: { "event": "event_name", "payload": {} }
 * - Event types must be centralized in lib/websocket/events.js
 * - Native JS structures (Map, Set) must be used to manage connections
 * - All connections must be authenticated using JWT
 * - JWT validation logic must reuse existing auth middleware
 * - Role-based access enforced for sensitive events
 */

const { logger } = require('@lib/logging');
const { CONNECTION_EVENTS, AUTH_EVENTS } = require('@lib/websocket/events');
const { getWebSocketServer } = require('@websockets/server');
const { verifyToken } = require('@lib/jwt');
const rolesConfig = require('@config/roles');
const permissionsConfig = require('@config/permissions');
const { normalizeRoleName } = require('@config/roles');
const { WS_MAX_CONNECTIONS, WS_HEARTBEAT_INTERVAL, WS_HEARTBEAT_TIMEOUT } = require('@config/env');

/**
 * Map of UserID → WebSocket connection
 * Per websockets.mdc: Must maintain a Map of UserID → WebSocket for routing messages
 * @type {Map<string, import('ws').WebSocket>}
 */
const userConnections = new Map();

/**
 * Map of WebSocket → UserID (reverse lookup for disconnection cleanup)
 * @type {Map<import('ws').WebSocket, string>}
 */
const connectionUsers = new Map();

/**
 * Map of WebSocket → User object (stores authenticated user data)
 * @type {Map<import('ws').WebSocket, Object>}
 */
const connectionUserData = new Map();

/**
 * Map of WebSocket → Authentication status
 * Tracks whether connection has been authenticated
 * @type {Map<import('ws').WebSocket, boolean>}
 */
const authenticatedConnections = new Map();

/**
 * Maximum number of concurrent connections
 * Per websockets.mdc: Maximum number of concurrent connections must be configurable
 * Default: 1000, can be overridden via environment variable
 */
const MAX_CONNECTIONS = WS_MAX_CONNECTIONS;

/**
 * Heartbeat configuration
 * Per websockets.mdc: Must handle disconnections, reconnections, and heartbeat/ping
 * 
 * HEARTBEAT_INTERVAL: How often to send ping messages (milliseconds)
 * Default: 30000 (30 seconds)
 * 
 * HEARTBEAT_TIMEOUT: How long to wait for pong before considering connection dead (milliseconds)
 * Default: 60000 (60 seconds)
 */
const HEARTBEAT_INTERVAL = WS_HEARTBEAT_INTERVAL;
const HEARTBEAT_TIMEOUT = WS_HEARTBEAT_TIMEOUT;

/**
 * Map of WebSocket → Last activity timestamp
 * Tracks last time connection sent a message or responded to ping
 * Used to detect dead connections
 * @type {Map<import('ws').WebSocket, number>}
 */
const lastActivity = new Map();

/**
 * Map of WebSocket → Pending ping status
 * Tracks whether a ping has been sent and is waiting for pong
 * @type {Map<import('ws').WebSocket, { sentAt: number, pingId: string }>}
 */
const pendingPings = new Map();

/**
 * Heartbeat interval timer
 * @type {NodeJS.Timeout|null}
 */
let heartbeatInterval = null;

/**
 * Send message to a specific user
 * 
 * @param {string} userId - User ID to send message to
 * @param {string} event - Event name (from @lib/websocket/events)
 * @param {Object} payload - Message payload
 * @returns {boolean} True if message was sent, false if user not connected
 */
const sendToUser = (userId, event, payload = {}) => {
  try {
    const ws = userConnections.get(userId);
    
    if (!ws || ws.readyState !== ws.OPEN) {
      logger.warn('Attempted to send message to disconnected user', {
        userId,
        event
      });
      return false;
    }

    const message = JSON.stringify({
      event,
      payload
    });

    ws.send(message);
    
    logger.info('Message sent to user', {
      userId,
      event
    });
    
    return true;
  } catch (err) {
    logger.error('Error sending message to user', {
      userId,
      event,
      error: err.message,
      stack: err.stack
    });
    return false;
  }
};

/**
 * Broadcast message to all connected users
 * 
 * @param {string} event - Event name (from @lib/websocket/events)
 * @param {Object} payload - Message payload
 * @param {string[]} [excludeUserIds] - User IDs to exclude from broadcast
 * @returns {number} Number of users who received the message
 */
const broadcast = (event, payload = {}, excludeUserIds = []) => {
  let sentCount = 0;
  const excludeSet = new Set(excludeUserIds);
  
  try {
    const message = JSON.stringify({
      event,
      payload
    });

    userConnections.forEach((ws, userId) => {
      // Skip excluded users
      if (excludeSet.has(userId)) {
        return;
      }

      // Only send to open connections
      if (ws.readyState === ws.OPEN) {
        try {
          ws.send(message);
          sentCount++;
        } catch (err) {
          logger.error('Error broadcasting to user', {
            userId,
            event,
            error: err.message
          });
        }
      }
    });

    logger.info('Message broadcasted', {
      event,
      sentCount,
      totalConnections: userConnections.size
    });

    return sentCount;
  } catch (err) {
    logger.error('Error broadcasting message', {
      event,
      error: err.message,
      stack: err.stack
    });
    return sentCount;
  }
};

/**
 * Get connection count
 * 
 * @returns {number} Number of active connections
 */
const getConnectionCount = () => {
  return userConnections.size;
};

/**
 * Check if user is connected
 * 
 * @param {string} userId - User ID to check
 * @returns {boolean} True if user is connected
 */
const isUserConnected = (userId) => {
  const ws = userConnections.get(userId);
  return ws !== undefined && ws.readyState === ws.OPEN;
};

/**
 * Get all connected user IDs
 * 
 * @returns {string[]} Array of connected user IDs
 */
const getConnectedUsers = () => {
  return Array.from(userConnections.keys());
};

/**
 * Get user data for a WebSocket connection
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @returns {Object|null} User data or null if not authenticated
 */
const getUserData = (ws) => {
  return connectionUserData.get(ws) || null;
};

/**
 * Check if user has required role or permission for WebSocket event
 * 
 * Per websockets.mdc: Role-based access enforced for sensitive events
 * Reuses RBAC logic from auth middleware
 * 
 * @param {Object} user - User object with role
 * @param {string|string[]} requiredRole - Required role(s) or permission(s)
 * @param {string} [type='role'] - Type of check: 'role' or 'permission'
 * @returns {boolean} True if user has required role/permission
 */
const checkWebSocketRBAC = (user, requiredRole, type = 'role') => {
  try {
    if (!user) {
      return false;
    }

    const sourceRole = user.role || (Array.isArray(user.roles) ? user.roles[0] : null);
    if (!sourceRole) {
      return false;
    }

    const userRole = normalizeRoleName(sourceRole) || String(sourceRole || '').toUpperCase();
    const roles = rolesConfig?.ROLES || rolesConfig || {};
    const rolePermissions = permissionsConfig?.ROLE_PERMISSIONS || permissionsConfig || {};
    
    // Convert single role to array
    const requiredRoles = (Array.isArray(requiredRole) ? requiredRole : [requiredRole])
      .map((role) => normalizeRoleName(role) || String(role || '').toUpperCase())
      .filter(Boolean);
    
    if (type === 'role') {
      // Check if user has required role
      const roleValues = Object.values(roles);
      const hasRole = requiredRoles.includes(userRole) || 
                     (roleValues.length > 0 && requiredRoles.some((r) => roles[r] === userRole));
      return hasRole;
    } else if (type === 'permission') {
      // Check if user's role has required permission
      const userPermissions = rolePermissions[userRole] || [];
      const hasPermission = requiredRoles.some((perm) => userPermissions.includes(perm));
      return hasPermission;
    }
    
    return false;
  } catch (err) {
    logger.error('Error checking WebSocket RBAC', {
      error: err.message,
      stack: err.stack
    });
    return false;
  }
};

/**
 * Get sensitive events that require RBAC
 * 
 * Per websockets.mdc: Role-based access enforced for sensitive events
 * 
 * @returns {Object} Map of event names to required roles/permissions
 */
const getSensitiveEvents = () => {
  return {};
};

/**
 * Update last activity timestamp for a connection
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 */
const updateLastActivity = (ws) => {
  lastActivity.set(ws, Date.now());
};

/**
 * Handle pong response to server-initiated ping
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {Object} payload - Pong message payload
 */
const handlePong = (ws, payload) => {
  try {
    const pending = pendingPings.get(ws);
    
    if (pending) {
      // Pong received, connection is alive
      pendingPings.delete(ws);
      updateLastActivity(ws);
      
    } else {
      // Pong received but no pending ping (client-initiated pong)
      updateLastActivity(ws);
    }
  } catch (err) {
    logger.error('Error handling pong', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Send ping to a connection
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @returns {boolean} True if ping was sent, false otherwise
 */
const sendPing = (ws) => {
  try {
    if (ws.readyState !== ws.OPEN) {
      return false;
    }

    const pingId = `ping_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const pingMessage = JSON.stringify({
      event: CONNECTION_EVENTS.PING,
      payload: {
        pingId,
        timestamp: Date.now()
      }
    });

    ws.send(pingMessage);
    
    // Track pending ping
    pendingPings.set(ws, {
      sentAt: Date.now(),
      pingId
    });

    return true;
  } catch (err) {
    logger.error('Error sending ping', {
      userId: connectionUsers.get(ws),
      error: err.message,
      stack: err.stack
    });
    return false;
  }
};

/**
 * Check and cleanup dead connections
 * 
 * Closes connections that haven't responded to pings within timeout period
 */
const checkDeadConnections = () => {
  try {
    const now = Date.now();
    const deadConnections = [];

    // Check all authenticated connections
    authenticatedConnections.forEach((isAuthenticated, ws) => {
      if (!isAuthenticated || ws.readyState !== ws.OPEN) {
        return;
      }

      const lastActive = lastActivity.get(ws) || 0;
      const timeSinceActivity = now - lastActive;

      // Check if connection has pending ping that timed out
      const pending = pendingPings.get(ws);
      if (pending) {
        const timeSincePing = now - pending.sentAt;
        if (timeSincePing > HEARTBEAT_TIMEOUT) {
          // Ping timeout - connection is dead
          deadConnections.push(ws);
          logger.warn('Connection timed out (no pong response)', {
            userId: connectionUsers.get(ws),
            pingId: pending.pingId,
            timeSincePing
          });
          return;
        }
      }

      // Check if connection has been inactive for too long
      if (timeSinceActivity > HEARTBEAT_TIMEOUT * 2) {
        // Connection inactive for too long (2x timeout)
        deadConnections.push(ws);
        logger.warn('Connection inactive for too long', {
          userId: connectionUsers.get(ws),
          timeSinceActivity
        });
      }
    });

    // Close dead connections
    deadConnections.forEach((ws) => {
      const userId = connectionUsers.get(ws);
      
      logger.info('Closing dead connection', {
        userId
      });

      if (ws.readyState === ws.OPEN) {
        ws.close(1000, 'Connection timeout');
      } else {
        // Connection already closed, just clean up
        handleDisconnection(ws, 1000, 'Connection timeout');
      }
    });

    if (deadConnections.length > 0) {
      logger.info('Cleaned up dead connections', {
        count: deadConnections.length,
        remainingConnections: userConnections.size
      });
    }
  } catch (err) {
    logger.error('Error checking dead connections', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Heartbeat interval handler
 * Sends ping to all connections and checks for dead connections
 */
const heartbeatTick = () => {
  try {
    // Send ping to all authenticated connections
    authenticatedConnections.forEach((isAuthenticated, ws) => {
      if (isAuthenticated && ws.readyState === ws.OPEN) {
        sendPing(ws);
      }
    });

    // Check for dead connections
    checkDeadConnections();

  } catch (err) {
    logger.error('Error in heartbeat tick', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Start heartbeat mechanism
 * 
 * Per websockets.mdc: Must handle disconnections, reconnections, and heartbeat/ping
 */
const startHeartbeat = () => {
  try {
    if (heartbeatInterval) {
      logger.warn('Heartbeat already started');
      return;
    }

    heartbeatInterval = setInterval(() => {
      heartbeatTick();
    }, HEARTBEAT_INTERVAL);
    if (typeof heartbeatInterval.unref === 'function') {
      heartbeatInterval.unref();
    }

    logger.info('Heartbeat mechanism started', {
      interval: HEARTBEAT_INTERVAL,
      timeout: HEARTBEAT_TIMEOUT
    });

  } catch (err) {
    logger.error('Failed to start heartbeat', {
      error: err.message,
      stack: err.stack
    });
    throw err;
  }
};

/**
 * Stop heartbeat mechanism
 */
const stopHeartbeat = () => {
  try {
    if (heartbeatInterval) {
      clearInterval(heartbeatInterval);
      heartbeatInterval = null;
      
      logger.info('Heartbeat mechanism stopped');
    }
  } catch (err) {
    logger.error('Error stopping heartbeat', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Extract JWT token from WebSocket connection
 * 
 * Per websockets.mdc: JWT validation logic must reuse existing auth middleware
 * Token can be provided via:
 * 1. Query parameter: ?token=<jwt_token>
 * 2. Authorization header in upgrade request: Authorization: Bearer <token>
 * 
 * @param {import('http').IncomingMessage} req - HTTP request
 * @returns {string|null} JWT token or null
 */
const extractToken = (req) => {
  try {
    // Try query parameter first (common for WebSocket connections)
    const url = new URL(req.url, `http://${req.headers.host}`);
    const tokenFromQuery = url.searchParams.get('token');
    
    if (tokenFromQuery) {
      return tokenFromQuery;
    }
    
    // Try Authorization header (Bearer token)
    const authHeader = req.headers.authorization;
    if (authHeader) {
      const parts = authHeader.split(' ');
      if (parts.length === 2 && parts[0] === 'Bearer') {
        return parts[1];
      }
    }
    
    return null;
  } catch (err) {
    return null;
  }
};

/**
 * Authenticate WebSocket connection
 * 
 * Per websockets.mdc: All connections must be authenticated using JWT
 * Reuses auth middleware logic (verifyToken)
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {string} token - JWT token
 * @returns {Promise<Object>} Authenticated user object
 * @throws {Error} If authentication fails
 */
const authenticateConnection = async (ws, token) => {
  try {
    // Verify token (reuses auth middleware logic)
    const decoded = verifyToken(token);
    
    // Extract user ID from token
    const userId = decoded.id || decoded.user_id || decoded.userId;
    
    if (!userId) {
      throw new Error('Token does not contain user ID');
    }
    
    // Return authenticated user data from token (no DB lookup at base phase)
    return {
      id: userId,
      email: decoded.email,
      role: decoded.role,
      ...decoded
    };
  } catch (err) {
    // Log authentication failure (but don't expose sensitive details)
    logger.warn('WebSocket authentication failed', {
      error: err.message,
      // Don't log token or user details
    });
    throw err;
  }
};

/**
 * Handle WebSocket connection
 * 
 * Per websockets.mdc: All connections must be authenticated using JWT
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {import('http').IncomingMessage} req - HTTP request
 */
const handleConnection = async (ws, req) => {
  try {
    // Check connection limit
    if (userConnections.size >= MAX_CONNECTIONS) {
      logger.warn('Maximum connections reached', {
        current: userConnections.size,
        max: MAX_CONNECTIONS
      });
      
      ws.close(1008, 'Server at maximum capacity');
      return;
    }

    // Extract JWT token from connection
    const token = extractToken(req);
    
    if (!token) {
      logger.warn('WebSocket connection attempted without token', {
        ip: req.socket.remoteAddress
      });
      
      // Send authentication failed event
      const errorMessage = JSON.stringify({
        event: AUTH_EVENTS.AUTHENTICATION_FAILED,
        payload: {
          message: 'Authentication required. Please provide a valid JWT token via query parameter (?token=...) or Authorization header.'
        }
      });
      
      if (ws.readyState === ws.OPEN || ws.readyState === ws.CONNECTING) {
        ws.send(errorMessage);
        ws.close(1008, 'Authentication required');
      }
      return;
    }

    // Authenticate connection
    let user;
    try {
      user = await authenticateConnection(ws, token);
    } catch (authErr) {
      // Send authentication failed event
      const errorMessage = JSON.stringify({
        event: AUTH_EVENTS.AUTHENTICATION_FAILED,
        payload: {
          message: authErr.message === 'Token has expired' 
            ? 'Token has expired. Please refresh your token.'
            : 'Authentication failed. Invalid or expired token.'
        }
      });
      
      if (ws.readyState === ws.OPEN || ws.readyState === ws.CONNECTING) {
        ws.send(errorMessage);
        ws.close(1008, 'Authentication failed');
      }
      return;
    }

    // Register authenticated connection
    registerUserConnection(user.id, ws);
    connectionUserData.set(ws, user);
    authenticatedConnections.set(ws, true);
    
    // Initialize heartbeat tracking
    updateLastActivity(ws);

    logger.info('WebSocket connection authenticated', {
      userId: user.id,
      email: user.email,
      role: user.role,
      ip: req.socket.remoteAddress,
      totalConnections: userConnections.size
    });

    // Send authenticated event
    const authMessage = JSON.stringify({
      event: AUTH_EVENTS.AUTHENTICATED,
      payload: {
        message: 'Successfully authenticated',
        user: {
          id: user.id,
          email: user.email,
          role: user.role
        }
      }
    });
    
    if (ws.readyState === ws.OPEN) {
      ws.send(authMessage);
    }

    // Handle incoming messages
    ws.on('message', (data) => {
      handleMessage(ws, data);
    });

    // Handle connection close
    ws.on('close', (code, reason) => {
      handleDisconnection(ws, code, reason);
    });

    // Handle errors
    ws.on('error', (error) => {
      handleError(ws, error);
    });

  } catch (err) {
    logger.error('Error handling WebSocket connection', {
      error: err.message,
      stack: err.stack
    });
    
    if (ws.readyState === ws.OPEN || ws.readyState === ws.CONNECTING) {
      const errorMessage = JSON.stringify({
        event: CONNECTION_EVENTS.ERROR,
        payload: {
          message: 'Internal server error'
        }
      });
      ws.send(errorMessage);
      ws.close(1011, 'Internal server error');
    }
  }
};

/**
 * Handle incoming WebSocket message
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {Buffer|string} data - Raw message data
 */
const handleMessage = (ws, data) => {
  try {
    // Parse JSON message
    // Per websockets.mdc: All messages must be JSON: { "event": "event_name", "payload": {} }
    let message;
    
    try {
      const messageStr = data.toString();
      message = JSON.parse(messageStr);
    } catch (parseErr) {
      logger.warn('Invalid JSON message received', {
        error: parseErr.message,
        data: data.toString().substring(0, 100) // Log first 100 chars only
      });
      
      // Send error response
      const errorMessage = JSON.stringify({
        event: CONNECTION_EVENTS.ERROR,
        payload: {
          message: 'Invalid message format. Expected JSON: { "event": "event_name", "payload": {} }'
        }
      });
      
      if (ws.readyState === ws.OPEN) {
        ws.send(errorMessage);
      }
      return;
    }

    // Validate message structure
    if (!message.event || typeof message.event !== 'string') {
      logger.warn('Invalid message structure: missing or invalid event', {
        message
      });
      
      const errorMessage = JSON.stringify({
        event: CONNECTION_EVENTS.ERROR,
        payload: {
          message: 'Invalid message structure. Expected: { "event": "event_name", "payload": {} }'
        }
      });
      
      if (ws.readyState === ws.OPEN) {
        ws.send(errorMessage);
      }
      return;
    }

    // Check if connection is authenticated
    const isAuthenticated = authenticatedConnections.get(ws);
    
    if (!isAuthenticated) {
      logger.warn('Unauthenticated WebSocket message received', {
        event: message.event
      });
      
      const errorMessage = JSON.stringify({
        event: AUTH_EVENTS.UNAUTHORIZED,
        payload: {
          message: 'Connection not authenticated. Please authenticate first.'
        }
      });
      
      if (ws.readyState === ws.OPEN) {
        ws.send(errorMessage);
        ws.close(1008, 'Unauthorized');
      }
      return;
    }

    // Get user ID from connection
    const userId = connectionUsers.get(ws);
    const user = connectionUserData.get(ws);
    
    // Update last activity for any message received
    updateLastActivity(ws);
    
    logger.info('WebSocket message received', {
      userId,
      event: message.event
    });

    // Check RBAC for sensitive events (Step 5.5)
    // Per websockets.mdc: Role-based access enforced for sensitive events
    const sensitiveEvents = getSensitiveEvents();
    const eventRBAC = sensitiveEvents[message.event];
    
    if (eventRBAC) {
      const hasAccess = checkWebSocketRBAC(user, eventRBAC.value, eventRBAC.type);
      
      if (!hasAccess) {
        logger.warn('WebSocket RBAC check failed', {
          userId,
          event: message.event,
          userRole: user.role,
          required: eventRBAC
        });
        
        const errorMessage = JSON.stringify({
          event: AUTH_EVENTS.UNAUTHORIZED,
          payload: {
            message: 'Insufficient permissions for this event',
            event: message.event
          }
        });
        
        if (ws.readyState === ws.OPEN) {
          ws.send(errorMessage);
        }
        return;
      }
    }

    // Handle message based on event type
    switch (message.event) {
      case CONNECTION_EVENTS.PING:
        // Handle client-initiated ping (respond with pong)
        if (ws.readyState === ws.OPEN) {
          const pongMessage = JSON.stringify({
            event: CONNECTION_EVENTS.PONG,
            payload: { timestamp: Date.now() }
          });
          ws.send(pongMessage);
          
          // Update last activity
          updateLastActivity(ws);
        }
        break;
        
      case CONNECTION_EVENTS.PONG:
        // Handle pong response to server-initiated ping
        handlePong(ws, message.payload);
        break;
        
      case CONNECTION_EVENTS.HEARTBEAT:
        // Handle heartbeat message (client-initiated)
        if (ws.readyState === ws.OPEN) {
          const heartbeatResponse = JSON.stringify({
            event: CONNECTION_EVENTS.HEARTBEAT,
            payload: { timestamp: Date.now() }
          });
          ws.send(heartbeatResponse);
          
          // Update last activity
          updateLastActivity(ws);
        }
        break;
        
      default:
        // Log unhandled events (will be handled by services in later steps)
        logger.info('Unhandled WebSocket event', {
          userId,
          event: message.event,
          payload: message.payload
        });
        break;
    }

  } catch (err) {
    logger.error('Error handling WebSocket message', {
      error: err.message,
      stack: err.stack
    });
    
    // Send error response
    const errorMessage = JSON.stringify({
      event: CONNECTION_EVENTS.ERROR,
      payload: {
        message: 'Internal server error processing message'
      }
    });
    
    if (ws.readyState === ws.OPEN) {
      ws.send(errorMessage);
    }
  }
};

/**
 * Handle WebSocket disconnection
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {number} code - Close code
 * @param {Buffer} reason - Close reason
 */
const handleDisconnection = (ws, code, reason) => {
  try {
    const userId = connectionUsers.get(ws);
    
    if (userId) {
      // Remove from user connections map
      userConnections.delete(userId);
      connectionUsers.delete(ws);
      connectionUserData.delete(ws);
      authenticatedConnections.delete(ws);
      
      // Clean up heartbeat tracking
      lastActivity.delete(ws);
      pendingPings.delete(ws);
      
      logger.info('WebSocket connection closed', {
        userId,
        code,
        reason: reason ? reason.toString() : 'No reason provided',
        remainingConnections: userConnections.size
      });
    } else {
      logger.warn('WebSocket disconnected but user ID not found', {
        code,
        reason: reason ? reason.toString() : 'No reason provided'
      });
      
      // Clean up any remaining references
      connectionUserData.delete(ws);
      authenticatedConnections.delete(ws);
      lastActivity.delete(ws);
      pendingPings.delete(ws);
    }
  } catch (err) {
    logger.error('Error handling WebSocket disconnection', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Handle WebSocket error
 * 
 * @param {import('ws').WebSocket} ws - WebSocket connection
 * @param {Error} error - Error object
 */
const handleError = (ws, error) => {
  try {
    const userId = connectionUsers.get(ws);
    
    logger.error('WebSocket error', {
      userId,
      error: error.message,
      stack: error.stack
    });

    // Send error event if connection is authenticated
    if (authenticatedConnections.get(ws) && ws.readyState === ws.OPEN) {
      const errorMessage = JSON.stringify({
        event: CONNECTION_EVENTS.ERROR,
        payload: {
          message: 'An error occurred on the connection'
        }
      });
      
      try {
        ws.send(errorMessage);
      } catch (sendErr) {
        // Ignore send errors during error handling
      }
    }

    // Close connection on error
    if (ws.readyState === ws.OPEN || ws.readyState === ws.CONNECTING) {
      ws.close(1011, 'Internal server error');
    }
  } catch (err) {
    logger.error('Error handling WebSocket error', {
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Register user connection
 * 
 * Associates a WebSocket connection with a user ID
 * This will be called after authentication in Step 5.3
 * 
 * @param {string} userId - User ID
 * @param {import('ws').WebSocket} ws - WebSocket connection
 */
const registerUserConnection = (userId, ws) => {
  try {
    // Remove old connection if user already connected
    const oldWs = userConnections.get(userId);
    if (oldWs && oldWs !== ws) {
      logger.info('Replacing existing connection for user', {
        userId
      });
      
      // Close old connection
      if (oldWs.readyState === oldWs.OPEN) {
        oldWs.close(1000, 'New connection established');
      }
      
      // Clean up old connection
      connectionUsers.delete(oldWs);
      connectionUserData.delete(oldWs);
      authenticatedConnections.delete(oldWs);
    }

    // Register new connection
    userConnections.set(userId, ws);
    connectionUsers.set(ws, userId);

    logger.info('User connection registered', {
      userId,
      totalConnections: userConnections.size
    });
  } catch (err) {
    logger.error('Error registering user connection', {
      userId,
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Unregister user connection
 * 
 * Removes a user's WebSocket connection
 * 
 * @param {string} userId - User ID
 */
const unregisterUserConnection = (userId) => {
  try {
    const ws = userConnections.get(userId);
    
    if (ws) {
      userConnections.delete(userId);
      connectionUsers.delete(ws);
      connectionUserData.delete(ws);
      authenticatedConnections.delete(ws);
      
      // Clean up heartbeat tracking
      lastActivity.delete(ws);
      pendingPings.delete(ws);
      
      logger.info('User connection unregistered', {
        userId,
        remainingConnections: userConnections.size
      });
    }
  } catch (err) {
    logger.error('Error unregistering user connection', {
      userId,
      error: err.message,
      stack: err.stack
    });
  }
};

/**
 * Initialize WebSocket Gateway
 * 
 * Sets up event handlers on the WebSocket server
 * Must be called after WebSocket server is initialized
 * 
 * Per websockets.mdc: Must handle disconnections, reconnections, and heartbeat/ping
 */
const initializeGateway = () => {
  try {
    const wss = getWebSocketServer();
    
    if (!wss) {
      throw new Error('WebSocket server not initialized. Call initializeWebSocketServer() first.');
    }

    // Handle new connections
    wss.on('connection', async (ws, req) => {
      await handleConnection(ws, req);
    });

    // Start heartbeat mechanism
    startHeartbeat();

    logger.info('WebSocket gateway initialized successfully', {
      maxConnections: MAX_CONNECTIONS,
      heartbeatInterval: HEARTBEAT_INTERVAL,
      heartbeatTimeout: HEARTBEAT_TIMEOUT
    });

  } catch (err) {
    logger.error('Failed to initialize WebSocket gateway', {
      error: err.message,
      stack: err.stack
    });
    throw err;
  }
};

/**
 * Cleanup all connections
 * 
 * Removes all user connections (for shutdown)
 */
const cleanup = () => {
  try {
    // Stop heartbeat mechanism
    stopHeartbeat();

    // Close all connections
    userConnections.forEach((ws, userId) => {
      if (ws.readyState === ws.OPEN) {
        ws.close(1001, 'Server shutting down');
      }
    });

    // Clear all maps
    userConnections.clear();
    connectionUsers.clear();
    connectionUserData.clear();
    authenticatedConnections.clear();
    lastActivity.clear();
    pendingPings.clear();

    logger.info('WebSocket gateway cleaned up');
  } catch (err) {
    logger.error('Error during WebSocket gateway cleanup', {
      error: err.message,
      stack: err.stack
    });
  }
};

module.exports = {
  // Connection management
  initializeGateway,
  registerUserConnection,
  unregisterUserConnection,
  cleanup,
  
  // Message sending
  sendToUser,
  broadcast,
  
  // Connection queries
  getConnectionCount,
  isUserConnected,
  getConnectedUsers,
  getUserData,
  
  // Heartbeat management
  startHeartbeat,
  stopHeartbeat
};


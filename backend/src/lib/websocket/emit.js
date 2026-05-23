/**
 * WebSocket Event Emission Utility
 * 
 * Per websockets.mdc:
 * - Only services may emit WebSocket events
 * - Controllers must not emit events directly
 * - All sensitive events must generate audit logs
 * - Broadcasts must be explicit and avoid unnecessary data duplication
 * 
 * This utility provides functions for services to emit WebSocket events
 * Services should use this module to send real-time updates to connected clients
 */

const { logger } = require('@lib/logging');
const { sanitizeFriendlyIds } = require('@lib/identifiers/sanitize-friendly-ids');

// Import gateway functions (using require to avoid circular dependency)
// These functions are exported from gateway.js
let gateway = null;
const getGateway = () => {
  if (!gateway) {
    gateway = require('@websockets/gateway');
  }
  return gateway;
};

/**
 * Emit WebSocket event to a specific user
 * 
 * @param {string} userId - User ID to send event to
 * @param {string} event - Event name (from @lib/websocket/events)
 * @param {Object} payload - Event payload (should not contain raw database entities)
 * @returns {boolean} True if event was sent, false if user not connected
 */
const emitToUser = (userId, event, payload = {}) => {
  try {
    // Per websockets.mdc: No raw database entities are sent directly
    // Services should sanitize and format data before emitting
    
    const sanitizedPayload = sanitizeFriendlyIds(payload);
    const { sendToUser } = getGateway();
    const sent = sendToUser(userId, event, sanitizedPayload);
    
    if (sent) {
      logger.info('WebSocket event emitted to user', {
        userId,
        event
      });
    } else {
      logger.info('WebSocket event not sent (user not connected)', {
        userId,
        event
      });
    }
    
    return sent;
  } catch (err) {
    logger.error('Error emitting WebSocket event to user', {
      userId,
      event,
      error: err.message,
      stack: err.stack
    });
    return false;
  }
};

/**
 * Broadcast WebSocket event to all connected users
 * 
 * Per websockets.mdc: Broadcasts must be explicit and avoid unnecessary data duplication
 * 
 * @param {string} event - Event name (from @lib/websocket/events)
 * @param {Object} payload - Event payload (should not contain raw database entities)
 * @param {string[]} [excludeUserIds] - User IDs to exclude from broadcast
 * @returns {number} Number of users who received the event
 */
const emitBroadcast = (event, payload = {}, excludeUserIds = []) => {
  try {
    // Per websockets.mdc: No raw database entities are sent directly
    // Services should sanitize and format data before emitting
    
    const sanitizedPayload = sanitizeFriendlyIds(payload);
    const { broadcast } = getGateway();
    const sentCount = broadcast(event, sanitizedPayload, excludeUserIds);
    
    logger.info('WebSocket event broadcasted', {
      event,
      sentCount,
      excludedUsers: excludeUserIds.length
    });
    
    return sentCount;
  } catch (err) {
    logger.error('Error broadcasting WebSocket event', {
      event,
      error: err.message,
      stack: err.stack
    });
    return 0;
  }
};

/**
 * Emit WebSocket event to multiple specific users
 * 
 * @param {string[]} userIds - Array of user IDs to send event to
 * @param {string} event - Event name (from @lib/websocket/events)
 * @param {Object} payload - Event payload (should not contain raw database entities)
 * @returns {number} Number of users who received the event
 */
const emitToUsers = (userIds, event, payload = {}) => {
  try {
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return 0;
    }
    
    const sanitizedPayload = sanitizeFriendlyIds(payload);
    let sentCount = 0;
    
    userIds.forEach((userId) => {
      if (emitToUser(userId, event, sanitizedPayload)) {
        sentCount++;
      }
    });
    
    logger.info('WebSocket event emitted to multiple users', {
      event,
      targetCount: userIds.length,
      sentCount
    });
    
    return sentCount;
  } catch (err) {
    logger.error('Error emitting WebSocket event to multiple users', {
      event,
      error: err.message,
      stack: err.stack
    });
    return 0;
  }
};


const normalizeRecipientIds = (recipientUserIds = [], actorUserId = null) => {
  const values = Array.isArray(recipientUserIds) ? recipientUserIds : [];
  return Array.from(
    new Set(
      [...values, actorUserId]
        .map((value) => String(value || '').trim())
        .filter(Boolean)
    )
  );
};

/**
 * Publish a stable HMS domain event envelope to explicit recipients.
 *
 * This helper owns delivery shape only. Services/repositories remain
 * responsible for mutations, recipient lookup, and business decisions.
 *
 * @param {Object} params
 * @param {string} params.event
 * @param {string|null} [params.tenant_id]
 * @param {string|null} [params.facility_id]
 * @param {string|null} [params.actor_user_id]
 * @param {string} params.resource_type
 * @param {string|null} [params.resource_id]
 * @param {Object} [params.affected]
 * @param {Object} [params.payload]
 * @param {string[]} [params.recipient_user_ids]
 * @returns {number} Number of connected recipient users reached
 */
const publishDomainEvent = ({
  event,
  tenant_id = null,
  facility_id = null,
  actor_user_id = null,
  resource_type,
  resource_id = null,
  affected = {},
  payload = {},
  recipient_user_ids = []
} = {}) => {
  const occurred_at = new Date().toISOString();
  try {
    if (!event || !resource_type) {
      logger.warn('WebSocket domain event skipped due to missing required fields', {
        event,
        resource_type
      });
      return 0;
    }

    const recipients = normalizeRecipientIds(recipient_user_ids, actor_user_id);
    if (recipients.length === 0) {
      logger.info('WebSocket domain event skipped due to no recipients', {
        event,
        tenant_id,
        facility_id,
        resource_type,
        resource_id
      });
      return 0;
    }

    const messagePayload = {
      event,
      tenant_id: tenant_id || null,
      facility_id: facility_id || null,
      actor_user_id: actor_user_id || null,
      resource_type,
      resource_id: resource_id || null,
      affected: affected || {},
      payload: {
        ...(payload || {}),
        occurred_at: payload?.occurred_at || occurred_at
      },
      occurred_at
    };

    return emitToUsers(recipients, event, messagePayload);
  } catch (err) {
    logger.error('Error publishing WebSocket domain event', {
      event,
      tenant_id,
      facility_id,
      resource_type,
      resource_id,
      error: err.message,
      stack: err.stack
    });
    return 0;
  }
};

module.exports = {
  emitToUser,
  emitBroadcast,
  emitToUsers,
  publishDomainEvent
};


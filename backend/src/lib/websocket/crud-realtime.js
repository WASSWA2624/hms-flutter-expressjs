/**
 * CRUD realtime publishing helper
 *
 * Services call this after successful persistence to broadcast stable
 * domain events to scoped recipients. Delivery failures must never
 * roll back committed database mutations.
 */

const { logger } = require('@lib/logging');
const { publishDomainEvent } = require('@lib/websocket/emit');
const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');

const compactId = (value) => String(value || '').trim() || null;

/**
 * Publish a CRUD realtime event after persistence.
 *
 * @param {Object} params
 * @param {string} params.event - Event name from @lib/websocket/events
 * @param {Object} params.resource - Persisted resource with tenant_id and id
 * @param {string} params.resource_type - Stable resource type key (snake_case)
 * @param {string|null} [params.actor_user_id]
 * @param {string[]} [params.recipient_roles]
 * @param {Object} [params.affected]
 * @param {Object} [params.payload]
 * @param {string[]} [params.extra_user_ids]
 * @returns {Promise<number>} Number of connected recipients reached
 */
const publishCrudRealtimeEvent = async ({
  event,
  resource,
  resource_type,
  actor_user_id = null,
  recipient_roles = [],
  affected = {},
  payload = {},
  extra_user_ids = []
} = {}) => {
  try {
    const tenantId = compactId(resource?.tenant_id);
    if (!tenantId || !event || !resource_type) {
      return 0;
    }

    const facilityId = compactId(resource?.facility_id);
    const resourceId = compactId(resource?.id);
    const occurredAt = new Date().toISOString();
    const resourceIdKey = `${resource_type}_id`;

    const recipientUserIds = await findRealtimeRecipientUserIds({
      tenantId,
      facilityId,
      roles: recipient_roles,
      extraUserIds: [actor_user_id, ...extra_user_ids]
    });

    return publishDomainEvent({
      event,
      tenant_id: tenantId,
      facility_id: facilityId,
      actor_user_id,
      resource_type,
      resource_id: resourceId,
      affected: {
        [resourceIdKey]: resourceId,
        ...affected
      },
      recipient_user_ids: recipientUserIds,
      payload: {
        [resourceIdKey]: resourceId,
        tenant_id: tenantId,
        facility_id: facilityId,
        actor_user_id: actor_user_id || null,
        occurred_at: occurredAt,
        ...payload
      }
    });
  } catch (error) {
    logger.error('Failed to publish CRUD realtime event', {
      event,
      resource_type,
      resourceId: resource?.id,
      error: error.message
    });
    return 0;
  }
};

module.exports = {
  publishCrudRealtimeEvent
};

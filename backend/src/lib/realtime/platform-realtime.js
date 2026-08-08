/**
 * Platform-scoped realtime publishing for Platform Admin dashboards.
 *
 * CRUD realtime requires tenant_id on the resource; platform entities such as
 * tenant do not have one. This helper resolves platform admin recipients and
 * emits stable domain events with optional dashboard count deltas.
 */

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');
const { logger } = require('@lib/logging');
const { publishDomainEvent } = require('@lib/websocket/emit');

const PLATFORM_REALTIME_RECIPIENT_ROLES = Object.freeze([
  ROLES.PLATFORM_ADMIN,
  ROLES.OPERATIONS
]);

const compactId = (value) => String(value || '').trim() || null;

/**
 * Resolve user IDs with platform admin roles across all tenants.
 *
 * @param {string[]} [extraUserIds]
 * @returns {Promise<string[]>}
 */
const findPlatformAdminRecipientUserIds = async (extraUserIds = []) => {
  const recipients = new Set(
    (Array.isArray(extraUserIds) ? extraUserIds : [])
      .map((value) => compactId(value))
      .filter(Boolean)
  );

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      role: {
        name: { in: PLATFORM_REALTIME_RECIPIENT_ROLES },
        deleted_at: null
      }
    },
    select: { user_id: true }
  });

  rows.forEach((row) => {
    if (row?.user_id) {
      recipients.add(row.user_id);
    }
  });

  return Array.from(recipients);
};

/**
 * Publish a platform-scoped realtime event to Platform Admin / Operations users.
 *
 * @param {Object} params
 * @param {string} params.event
 * @param {string} params.resource_type
 * @param {string|null} [params.resource_id]
 * @param {string|null} [params.actor_user_id]
 * @param {string|null} [params.tenant_id]
 * @param {string|null} [params.facility_id]
 * @param {Object} [params.dashboard_deltas]
 * @param {Object} [params.payload]
 * @returns {Promise<number>}
 */
const publishPlatformRealtimeEvent = async ({
  event,
  resource_type,
  resource_id = null,
  actor_user_id = null,
  tenant_id = null,
  facility_id = null,
  dashboard_deltas = {},
  payload = {}
} = {}) => {
  try {
    if (!event || !resource_type) {
      return 0;
    }

    const recipientUserIds = await findPlatformAdminRecipientUserIds([
      actor_user_id
    ]);
    const resourceIdKey = `${resource_type}_id`;
    const occurredAt = new Date().toISOString();

    return publishDomainEvent({
      event,
      tenant_id,
      facility_id,
      actor_user_id,
      resource_type,
      resource_id,
      affected: {
        [resourceIdKey]: resource_id,
        scope: 'platform'
      },
      recipient_user_ids: recipientUserIds,
      payload: {
        scope: 'platform',
        [resourceIdKey]: resource_id,
        tenant_id,
        facility_id,
        dashboard_deltas,
        ...payload,
        occurred_at: occurredAt
      }
    });
  } catch (error) {
    logger.error('Failed to publish platform realtime event', {
      event,
      resource_type,
      resource_id,
      error: error.message
    });
    return 0;
  }
};

const activeDelta = (isActive, delta = 1) => (isActive === false ? 0 : delta);

const buildTenantDashboardDeltas = (tenant, operation = 'create', before = null) => {
  if (operation === 'update') {
    if (!before) {
      return {};
    }

    const wasActive = before.is_active !== false;
    const isActive = tenant?.is_active !== false;
    if (wasActive === isActive) {
      return {};
    }

    const sign = isActive ? 1 : -1;
    return {
      status_cards: {
        tenants_active: {
          value_delta: sign,
          secondary_delta: 0
        }
      }
    };
  }

  const sign = operation === 'delete' ? -1 : 1;
  const isActive = tenant?.is_active !== false;

  return {
    status_cards: {
      tenants_active: {
        value_delta: activeDelta(isActive, sign),
        secondary_delta: sign
      },
      subscriptions_health: {
        secondary_delta: sign
      }
    },
    alerts: {
      tenants_without_subscription: {
        count_delta: operation === 'create' ? sign : 0
      }
    }
  };
};

const buildFacilityDashboardDeltas = (facility, operation = 'create') => {
  if (operation === 'update') {
    return {};
  }

  const sign = operation === 'delete' ? -1 : 1;
  const isActive = facility?.is_active !== false;

  return {
    status_cards: {
      facilities_active: {
        value_delta: activeDelta(isActive, sign),
        secondary_delta: sign
      }
    }
  };
};

module.exports = {
  PLATFORM_REALTIME_RECIPIENT_ROLES,
  findPlatformAdminRecipientUserIds,
  publishPlatformRealtimeEvent,
  buildTenantDashboardDeltas,
  buildFacilityDashboardDeltas
};

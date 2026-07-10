/**
 * Realtime recipient resolution
 *
 * Shared helper for resolving WebSocket event recipients by tenant,
 * facility scope, and role. Repositories may delegate here instead of
 * duplicating user_role queries.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Resolve connected-user recipient IDs for a scoped domain event.
 *
 * @param {Object} params
 * @param {string} params.tenantId
 * @param {string|null} [params.facilityId]
 * @param {string[]} [params.roles]
 * @param {string[]} [params.extraUserIds]
 * @returns {Promise<string[]>}
 */
const findRealtimeRecipientUserIds = async ({
  tenantId,
  facilityId = null,
  roles = [],
  extraUserIds = []
} = {}) => {
  try {
    const recipients = new Set(
      (Array.isArray(extraUserIds) ? extraUserIds : [])
        .map((value) => String(value || '').trim())
        .filter(Boolean)
    );

    if (!tenantId || !Array.isArray(roles) || roles.length === 0) {
      return Array.from(recipients);
    }

    const rows = await prisma.user_role.findMany({
      where: {
        deleted_at: null,
        tenant_id: tenantId,
        role: {
          name: { in: roles },
          deleted_at: null
        },
        ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {})
      },
      select: { user_id: true }
    });

    rows.forEach((item) => {
      if (item?.user_id) recipients.add(item.user_id);
    });

    return Array.from(recipients);
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const {
  findPlatformAdminRecipientUserIds
} = require('@lib/realtime/platform-realtime');

module.exports = {
  findRealtimeRecipientUserIds,
  findPlatformAdminRecipientUserIds
};

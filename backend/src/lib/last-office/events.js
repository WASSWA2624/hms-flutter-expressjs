const prisma = require('@prisma/client');
const { emitToUsers, LAST_OFFICE_EVENTS, ACCESS_CONTROL_EVENTS } = require('@lib/websocket');

const WORKFLOW_RECIPIENT_ROLES = Object.freeze([
  'TENANT_ADMIN',
  'FACILITY_ADMIN',
  'OPERATIONS',
  'BILLING',
  'NURSE',
]);

const REVIEW_RECIPIENT_ROLES = Object.freeze([
  'TENANT_ADMIN',
  'FACILITY_ADMIN',
  'OPERATIONS',
]);

const findRecipientIds = async ({ tenant_id, facility_id = null, roles = WORKFLOW_RECIPIENT_ROLES } = {}) => {
  if (!tenant_id) {
    return [];
  }

  const rows = await prisma.user_role.findMany({
    where: {
      tenant_id,
      deleted_at: null,
      ...(facility_id ? { OR: [{ facility_id }, { facility_id: null }] } : {}),
      role: {
        deleted_at: null,
        name: { in: roles },
      },
      user: {
        deleted_at: null,
      },
    },
    select: { user_id: true },
  });

  return Array.from(new Set(rows.map((entry) => entry.user_id).filter(Boolean)));
};

const emitLastOfficeEvent = async ({ tenant_id, facility_id, event, payload }) => {
  const recipientIds = await findRecipientIds({ tenant_id, facility_id, roles: WORKFLOW_RECIPIENT_ROLES });
  if (!recipientIds.length) return;
  emitToUsers(recipientIds, event, payload);
};

const emitAccessControlEvent = async ({ tenant_id, facility_id, event, payload }) => {
  const recipientIds = await findRecipientIds({ tenant_id, facility_id, roles: REVIEW_RECIPIENT_ROLES });
  if (!recipientIds.length) return;
  emitToUsers(recipientIds, event, payload);
};

module.exports = {
  ACCESS_CONTROL_EVENTS,
  LAST_OFFICE_EVENTS,
  emitAccessControlEvent,
  emitLastOfficeEvent,
};

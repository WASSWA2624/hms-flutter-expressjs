const { ROLES } = require('@config/roles');
const prisma = require('@prisma/client');

const LAB_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const resolveOrderContext = (orderRecord, resultRecord = null) => {
  if (orderRecord && typeof orderRecord === 'object') {
    return orderRecord;
  }
  return resultRecord?.lab_order_item?.lab_order || null;
};

const resolveLabRealtimeRecipients = async ({
  orderRecord = null,
  resultRecord = null,
  actorUserId = null,
} = {}) => {
  const order = resolveOrderContext(orderRecord, resultRecord);
  const patient = order?.patient || {};
  const encounter = order?.encounter || {};
  const tenantId = String(patient.tenant_id || '').trim();
  if (!tenantId || !prisma?.user_role?.findMany) {
    return [];
  }

  const facilityId = String(patient.facility_id || '').trim() || null;
  const targetedUserIds = [
    order?.ordered_by_user_id,
    encounter?.provider_user_id,
  ]
    .map((value) => String(value || '').trim())
    .filter(Boolean);

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        name: { in: LAB_RECIPIENT_ROLES },
        deleted_at: null,
      },
      ...(facilityId ? { OR: [{ facility_id: null }, { facility_id: facilityId }] } : {}),
    },
    select: { user_id: true },
  });

  const roleRecipients = rows.map((row) => row.user_id).filter(Boolean);
  const recipients = [...new Set([...targetedUserIds, ...roleRecipients])];
  return actorUserId
    ? recipients.filter((userId) => userId && userId !== actorUserId)
    : recipients.filter(Boolean);
};

const resolveFacilityLabCatalogRecipients = async ({
  tenantId = null,
  facilityId = null,
  actorUserId = null,
} = {}) => {
  const normalizedTenantId = String(tenantId || '').trim();
  if (!normalizedTenantId || !prisma?.user_role?.findMany) {
    return [];
  }

  const normalizedFacilityId = String(facilityId || '').trim() || null;
  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: normalizedTenantId,
      role: {
        name: { in: LAB_RECIPIENT_ROLES },
        deleted_at: null,
      },
      ...(normalizedFacilityId
        ? { OR: [{ facility_id: null }, { facility_id: normalizedFacilityId }] }
        : {}),
    },
    select: { user_id: true },
  });

  const recipients = [...new Set(rows.map((row) => row.user_id).filter(Boolean))];
  return actorUserId
    ? recipients.filter((userId) => userId && userId !== actorUserId)
    : recipients;
};

module.exports = {
  LAB_RECIPIENT_ROLES,
  resolveLabRealtimeRecipients,
  resolveFacilityLabCatalogRecipients,
};

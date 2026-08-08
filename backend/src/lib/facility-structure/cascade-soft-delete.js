/**
 * Hierarchical soft-delete / restore helpers for facility structure.
 *
 * Trees:
 *   Tenant → Facility → (Department → Unit) + (Ward → Room → Bed)
 *   Department → Unit
 *   Ward → Room → Bed
 *   Room → Bed
 *
 * Soft-delete cascades to hierarchical descendants.
 * Tenant restore cascade-restores facilities and structure soft-deleted with
 * the same deleted_at timestamp; independent earlier soft-deletes are left
 * alone. Standalone facility/department/ward/room/bed restore remains
 * parent-only (children stay deleted until restored individually) and
 * requires an active parent chain. Optional parents (e.g. ward.department_id)
 * are not cascade-deleted with the parent and must be flagged in the UI when
 * deleted.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const assertActiveParent = async ({
  model,
  id,
  errorKey,
  optional = false,
}) => {
  if (!id) {
    if (optional) return null;
    throw new HttpError(errorKey, 409);
  }

  const record = await prisma[model].findFirst({
    where: { id, deleted_at: null },
    select: { id: true },
  });

  if (!record) {
    throw new HttpError(errorKey, 409);
  }

  return record;
};

const softDeleteByIds = async (tx, model, ids, deletedAt) => {
  if (!ids.length) {
    return [];
  }

  await tx[model].updateMany({
    where: { id: { in: ids }, deleted_at: null },
    data: { deleted_at: deletedAt },
  });

  return ids;
};

/**
 * Soft-delete all structure rows under a facility (does not touch the facility).
 * Order: beds → rooms → units → wards → departments.
 */
const softDeleteFacilityDescendantsInTx = async (tx, facilityId, deletedAt) => {
  const beds = await tx.bed.findMany({
    where: { facility_id: facilityId, deleted_at: null },
    select: { id: true },
  });
  const bedIds = beds.map((row) => row.id);
  await softDeleteByIds(tx, 'bed', bedIds, deletedAt);

  const rooms = await tx.room.findMany({
    where: { facility_id: facilityId, deleted_at: null },
    select: { id: true },
  });
  const roomIds = rooms.map((row) => row.id);
  await softDeleteByIds(tx, 'room', roomIds, deletedAt);

  const units = await tx.unit.findMany({
    where: { facility_id: facilityId, deleted_at: null },
    select: { id: true },
  });
  const unitIds = units.map((row) => row.id);
  await softDeleteByIds(tx, 'unit', unitIds, deletedAt);

  const wards = await tx.ward.findMany({
    where: { facility_id: facilityId, deleted_at: null },
    select: { id: true },
  });
  const wardIds = wards.map((row) => row.id);
  await softDeleteByIds(tx, 'ward', wardIds, deletedAt);

  const departments = await tx.department.findMany({
    where: { facility_id: facilityId, deleted_at: null },
    select: { id: true },
  });
  const departmentIds = departments.map((row) => row.id);
  await softDeleteByIds(tx, 'department', departmentIds, deletedAt);

  return { bedIds, roomIds, unitIds, wardIds, departmentIds };
};

/**
 * Soft-delete tenant-scoped structure, then each facility and its descendants.
 * All cascade rows share the same deletedAt for matching restore.
 */
const softDeleteTenantStructureInTx = async (tx, tenantId, deletedAt) => {
  const orphanBeds = await tx.bed.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: { id: true },
  });
  await softDeleteByIds(
    tx,
    'bed',
    orphanBeds.map((row) => row.id),
    deletedAt
  );

  const orphanRooms = await tx.room.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: { id: true },
  });
  await softDeleteByIds(
    tx,
    'room',
    orphanRooms.map((row) => row.id),
    deletedAt
  );

  const orphanUnits = await tx.unit.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: { id: true },
  });
  await softDeleteByIds(
    tx,
    'unit',
    orphanUnits.map((row) => row.id),
    deletedAt
  );

  const orphanWards = await tx.ward.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: { id: true },
  });
  await softDeleteByIds(
    tx,
    'ward',
    orphanWards.map((row) => row.id),
    deletedAt
  );

  const orphanDepartments = await tx.department.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: { id: true },
  });
  await softDeleteByIds(
    tx,
    'department',
    orphanDepartments.map((row) => row.id),
    deletedAt
  );

  const facilities = await tx.facility.findMany({
    where: { tenant_id: tenantId, deleted_at: null },
    select: {
      id: true,
      tenant_id: true,
      name: true,
      facility_type: true,
      is_active: true,
    },
  });

  for (const facility of facilities) {
    // Catch any facility-scoped structure that may not have been covered above.
    await softDeleteFacilityDescendantsInTx(tx, facility.id, deletedAt);
  }

  if (facilities.length > 0) {
    await tx.facility.updateMany({
      where: { tenant_id: tenantId, deleted_at: null },
      data: { deleted_at: deletedAt },
    });
  }

  return { facilities };
};

/**
 * Restore facilities and structure soft-deleted together with a tenant
 * (matching deleted_at). Independently soft-deleted rows keep their tombstones.
 */
const restoreTenantStructureInTx = async (tx, tenantId, deletedAt) => {
  const facilities = await tx.facility.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: deletedAt,
    },
    select: {
      id: true,
      tenant_id: true,
      name: true,
      facility_type: true,
      is_active: true,
    },
  });

  if (facilities.length > 0) {
    await tx.facility.updateMany({
      where: {
        tenant_id: tenantId,
        deleted_at: deletedAt,
      },
      data: { deleted_at: null },
    });
  }

  // Parent-before-child order for any mid-tx readers of active parents.
  for (const model of ['department', 'unit', 'ward', 'room', 'bed']) {
    await tx[model].updateMany({
      where: {
        tenant_id: tenantId,
        deleted_at: deletedAt,
      },
      data: { deleted_at: null },
    });
  }

  return { facilities };
};

/**
 * Soft-delete a department and all units under it.
 */
const softDeleteDepartmentCascade = async (departmentId) => {
  const deletedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const department = await tx.department.findFirst({
      where: { id: departmentId, deleted_at: null },
    });
    if (!department) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const units = await tx.unit.findMany({
      where: { department_id: departmentId, deleted_at: null },
      select: { id: true },
    });
    const unitIds = units.map((row) => row.id);
    await softDeleteByIds(tx, 'unit', unitIds, deletedAt);

    const updated = await tx.department.update({
      where: { id: departmentId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, department: updated, unitIds };
  });
};

/**
 * Soft-delete a ward and all rooms/beds under it.
 */
const softDeleteWardCascade = async (wardId) => {
  const deletedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const ward = await tx.ward.findFirst({
      where: { id: wardId, deleted_at: null },
    });
    if (!ward) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const rooms = await tx.room.findMany({
      where: { ward_id: wardId, deleted_at: null },
      select: { id: true },
    });
    const roomIds = rooms.map((row) => row.id);

    const beds = await tx.bed.findMany({
      where: {
        deleted_at: null,
        OR: [
          { ward_id: wardId },
          ...(roomIds.length > 0 ? [{ room_id: { in: roomIds } }] : []),
        ],
      },
      select: { id: true },
    });
    const bedIds = beds.map((row) => row.id);
    await softDeleteByIds(tx, 'bed', bedIds, deletedAt);
    await softDeleteByIds(tx, 'room', roomIds, deletedAt);

    const updated = await tx.ward.update({
      where: { id: wardId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, ward: updated, roomIds, bedIds };
  });
};

/**
 * Soft-delete a room and all beds under it.
 */
const softDeleteRoomCascade = async (roomId) => {
  const deletedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const room = await tx.room.findFirst({
      where: { id: roomId, deleted_at: null },
    });
    if (!room) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const beds = await tx.bed.findMany({
      where: { room_id: roomId, deleted_at: null },
      select: { id: true },
    });
    const bedIds = beds.map((row) => row.id);
    await softDeleteByIds(tx, 'bed', bedIds, deletedAt);

    const updated = await tx.room.update({
      where: { id: roomId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, room: updated, bedIds };
  });
};

/**
 * Soft-delete a facility and all departments/units/wards/rooms/beds under it.
 */
const softDeleteFacilityCascade = async (facilityId) => {
  const deletedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const facility = await tx.facility.findFirst({
      where: { id: facilityId, deleted_at: null },
    });
    if (!facility) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const descendants = await softDeleteFacilityDescendantsInTx(
      tx,
      facilityId,
      deletedAt
    );

    const updated = await tx.facility.update({
      where: { id: facilityId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, facility: updated, ...descendants };
  });
};

const restoreDepartment = async (departmentId) => {
  const existing = await prisma.department.findUnique({
    where: { id: departmentId },
    select: {
      id: true,
      facility_id: true,
      deleted_at: true,
    },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.department.restore_requires_active_facility',
    optional: !existing.facility_id,
  });

  return prisma.department.update({
    where: { id: departmentId },
    data: { deleted_at: null },
  });
};

const restoreUnit = async (unitId) => {
  const existing = await prisma.unit.findUnique({
    where: { id: unitId },
    select: {
      id: true,
      facility_id: true,
      department_id: true,
      deleted_at: true,
    },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.unit.restore_requires_active_facility',
    optional: !existing.facility_id,
  });
  await assertActiveParent({
    model: 'department',
    id: existing.department_id,
    errorKey: 'errors.unit.restore_requires_active_department',
    optional: !existing.department_id,
  });

  return prisma.unit.update({
    where: { id: unitId },
    data: { deleted_at: null },
  });
};

const restoreWard = async (wardId) => {
  const existing = await prisma.ward.findUnique({
    where: { id: wardId },
    select: { id: true, facility_id: true, deleted_at: true },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.ward.restore_requires_active_facility',
  });

  return prisma.ward.update({
    where: { id: wardId },
    data: { deleted_at: null },
  });
};

const restoreRoom = async (roomId) => {
  const existing = await prisma.room.findUnique({
    where: { id: roomId },
    select: {
      id: true,
      ward_id: true,
      facility_id: true,
      deleted_at: true,
    },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  if (existing.ward_id) {
    await assertActiveParent({
      model: 'ward',
      id: existing.ward_id,
      errorKey: 'errors.room.restore_requires_active_ward',
    });
  } else {
    await assertActiveParent({
      model: 'facility',
      id: existing.facility_id,
      errorKey: 'errors.room.restore_requires_active_facility',
    });
  }

  return prisma.room.update({
    where: { id: roomId },
    data: { deleted_at: null },
  });
};

const restoreBed = async (bedId) => {
  const existing = await prisma.bed.findUnique({
    where: { id: bedId },
    select: { id: true, room_id: true, ward_id: true, deleted_at: true },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  if (existing.room_id) {
    await assertActiveParent({
      model: 'room',
      id: existing.room_id,
      errorKey: 'errors.bed.restore_requires_active_room',
    });
  } else {
    await assertActiveParent({
      model: 'ward',
      id: existing.ward_id,
      errorKey: 'errors.bed.restore_requires_active_ward',
      optional: !existing.ward_id,
    });
  }

  return prisma.bed.update({
    where: { id: bedId },
    data: { deleted_at: null },
  });
};

module.exports = {
  softDeleteDepartmentCascade,
  softDeleteWardCascade,
  softDeleteRoomCascade,
  softDeleteFacilityCascade,
  softDeleteFacilityDescendantsInTx,
  softDeleteTenantStructureInTx,
  restoreTenantStructureInTx,
  restoreDepartment,
  restoreUnit,
  restoreWard,
  restoreRoom,
  restoreBed,
};

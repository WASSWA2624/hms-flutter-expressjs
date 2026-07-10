/**
 * Hierarchical soft-delete / restore helpers for facility structure.
 *
 * Trees:
 *   Branch → Department → Unit
 *   Ward → Room → Bed
 *
 * Soft-delete cascades to descendants. Restore is parent-only (children stay
 * deleted until restored individually) and requires an active parent chain.
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

/**
 * Soft-delete a branch and all departments/units under it.
 * @returns {{ deletedAt: Date, branch: Object, departmentIds: string[], unitIds: string[] }}
 */
const softDeleteBranchCascade = async (branchId) => {
  const deletedAt = new Date();

  return prisma.$transaction(async (tx) => {
    const branch = await tx.branch.findFirst({
      where: { id: branchId, deleted_at: null },
    });
    if (!branch) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const departments = await tx.department.findMany({
      where: { branch_id: branchId, deleted_at: null },
      select: { id: true },
    });
    const departmentIds = departments.map((row) => row.id);

    let unitIds = [];
    if (departmentIds.length > 0) {
      const units = await tx.unit.findMany({
        where: { department_id: { in: departmentIds }, deleted_at: null },
        select: { id: true },
      });
      unitIds = units.map((row) => row.id);

      if (unitIds.length > 0) {
        await tx.unit.updateMany({
          where: { id: { in: unitIds }, deleted_at: null },
          data: { deleted_at: deletedAt },
        });
      }

      await tx.department.updateMany({
        where: { id: { in: departmentIds }, deleted_at: null },
        data: { deleted_at: deletedAt },
      });
    }

    const updated = await tx.branch.update({
      where: { id: branchId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, branch: updated, departmentIds, unitIds };
  });
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

    if (unitIds.length > 0) {
      await tx.unit.updateMany({
        where: { id: { in: unitIds }, deleted_at: null },
        data: { deleted_at: deletedAt },
      });
    }

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

    if (bedIds.length > 0) {
      await tx.bed.updateMany({
        where: { id: { in: bedIds }, deleted_at: null },
        data: { deleted_at: deletedAt },
      });
    }

    if (roomIds.length > 0) {
      await tx.room.updateMany({
        where: { id: { in: roomIds }, deleted_at: null },
        data: { deleted_at: deletedAt },
      });
    }

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

    if (bedIds.length > 0) {
      await tx.bed.updateMany({
        where: { id: { in: bedIds }, deleted_at: null },
        data: { deleted_at: deletedAt },
      });
    }

    const updated = await tx.room.update({
      where: { id: roomId },
      data: { deleted_at: deletedAt },
    });

    return { deletedAt, room: updated, bedIds };
  });
};

const restoreBranch = async (branchId) => {
  const existing = await prisma.branch.findUnique({
    where: { id: branchId },
    select: { id: true, facility_id: true, deleted_at: true },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.branch.restore_requires_active_facility',
    optional: !existing.facility_id,
  });

  return prisma.branch.update({
    where: { id: branchId },
    data: { deleted_at: null },
  });
};

const restoreDepartment = async (departmentId) => {
  const existing = await prisma.department.findUnique({
    where: { id: departmentId },
    select: {
      id: true,
      facility_id: true,
      branch_id: true,
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
  await assertActiveParent({
    model: 'branch',
    id: existing.branch_id,
    errorKey: 'errors.department.restore_requires_active_branch',
    optional: !existing.branch_id,
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
    select: { id: true, facility_id: true, ward_id: true, deleted_at: true },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.room.restore_requires_active_facility',
  });
  await assertActiveParent({
    model: 'ward',
    id: existing.ward_id,
    errorKey: 'errors.room.restore_requires_active_ward',
    optional: !existing.ward_id,
  });

  return prisma.room.update({
    where: { id: roomId },
    data: { deleted_at: null },
  });
};

const restoreBed = async (bedId) => {
  const existing = await prisma.bed.findUnique({
    where: { id: bedId },
    select: {
      id: true,
      facility_id: true,
      ward_id: true,
      room_id: true,
      deleted_at: true,
    },
  });
  if (!existing || !existing.deleted_at) {
    throw Object.assign(new Error('Record not found'), { code: 'P2025' });
  }

  await assertActiveParent({
    model: 'facility',
    id: existing.facility_id,
    errorKey: 'errors.bed.restore_requires_active_facility',
  });
  await assertActiveParent({
    model: 'ward',
    id: existing.ward_id,
    errorKey: 'errors.bed.restore_requires_active_ward',
  });
  await assertActiveParent({
    model: 'room',
    id: existing.room_id,
    errorKey: 'errors.bed.restore_requires_active_room',
    optional: !existing.room_id,
  });

  return prisma.bed.update({
    where: { id: bedId },
    data: { deleted_at: null },
  });
};

module.exports = {
  softDeleteBranchCascade,
  softDeleteDepartmentCascade,
  softDeleteWardCascade,
  softDeleteRoomCascade,
  restoreBranch,
  restoreDepartment,
  restoreUnit,
  restoreWard,
  restoreRoom,
  restoreBed,
};

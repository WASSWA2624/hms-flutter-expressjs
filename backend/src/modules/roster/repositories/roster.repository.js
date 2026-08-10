/**
 * Roster repository
 *
 * @module modules/roster/repositories
 * @description Data access layer for roster operations.
 * Soft-delete inactivates roster-owned shifts/assignments for attached staff.
 * Restore reactivates matching soft-deleted dependents.
 * Permanent delete removes the template and its staff schedule links.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { runWithoutTenantGuard } = require('../../../prisma/tenant-guard');

const rosterWhereById = (id, { includeDeleted = false } = {}) =>
  includeDeleted
    ? {
        id,
        OR: [{ deleted_at: null }, { deleted_at: { not: null } }],
      }
    : { id, deleted_at: null };

const findById = async (id, include = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.roster.findFirst({
      where: rosterWhereById(id, { includeDeleted }),
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  include = {},
  { includeDeleted = false } = {}
) => {
  try {
    const hasDeletedAtFilter = Object.prototype.hasOwnProperty.call(
      filters,
      'deleted_at'
    );
    const where = {
      ...(includeDeleted || hasDeletedAtFilter ? {} : { deleted_at: null }),
      ...filters,
    };

    return await prisma.roster.findMany({
      where,
      skip,
      take,
      orderBy,
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    const hasDeletedAtFilter = Object.prototype.hasOwnProperty.call(
      filters,
      'deleted_at'
    );
    const where = {
      ...(includeDeleted || hasDeletedAtFilter ? {} : { deleted_at: null }),
      ...filters,
    };

    return await prisma.roster.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const create = async (data) => {
  try {
    return await prisma.roster.create({
      data,
    });
  } catch (error) {
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: target },
      ]);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.roster.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.roster.not_found', 404);
    }
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: target },
      ]);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Soft-delete a roster and inactivate active shifts/assignments/day-offs for
 * staff using this template (shared deleted_at timestamp for restore).
 */
const softDelete = async (id, { constraints } = {}) => {
  try {
    const now = new Date();
    return await prisma.$transaction(async (tx) => {
      const shifts = await tx.shift.findMany({
        where: { roster_id: id, deleted_at: null },
        select: { id: true },
      });
      const shiftIds = shifts.map((row) => row.id);

      let inactivatedAssignments = 0;
      if (shiftIds.length) {
        const assignmentResult = await tx.shift_assignment.updateMany({
          where: { shift_id: { in: shiftIds }, deleted_at: null },
          data: { deleted_at: now },
        });
        inactivatedAssignments = assignmentResult.count || 0;
        await tx.shift.updateMany({
          where: { id: { in: shiftIds }, deleted_at: null },
          data: { deleted_at: now },
        });
      }

      const dayOffResult = await tx.roster_day_off.updateMany({
        where: { roster_id: id, deleted_at: null },
        data: { deleted_at: now },
      });

      const roster = await tx.roster.update({
        where: { id },
        data: {
          deleted_at: now,
          ...(constraints ? { constraints } : {}),
        },
      });

      return {
        roster,
        inactivated_shifts: shiftIds.length,
        inactivated_assignments: inactivatedAssignments,
        inactivated_day_offs: dayOffResult.count || 0,
      };
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.roster.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Restore a soft-deleted roster and matching soft-deleted dependents that share
 * the roster soft-delete timestamp.
 */
const restore = async (id, { constraints } = {}) => {
  try {
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.roster.findFirst({
        where: rosterWhereById(id, { includeDeleted: true }),
        select: { id: true, deleted_at: true, constraints: true },
      });

      if (!existing || !existing.deleted_at) {
        throw Object.assign(new Error('Record not found'), { code: 'P2025' });
      }

      const deletedAt = existing.deleted_at;

      return prisma.$transaction(async (tx) => {
        const shifts = await tx.shift.findMany({
          where: { roster_id: id, deleted_at: deletedAt },
          select: { id: true },
        });
        const shiftIds = shifts.map((row) => row.id);

        let restoredAssignments = 0;
        if (shiftIds.length) {
          const assignmentResult = await tx.shift_assignment.updateMany({
            where: { shift_id: { in: shiftIds }, deleted_at: deletedAt },
            data: { deleted_at: null },
          });
          restoredAssignments = assignmentResult.count || 0;
          await tx.shift.updateMany({
            where: { id: { in: shiftIds }, deleted_at: deletedAt },
            data: { deleted_at: null },
          });
        }

        const dayOffResult = await tx.roster_day_off.updateMany({
          where: { roster_id: id, deleted_at: deletedAt },
          data: { deleted_at: null },
        });

        const roster = await tx.roster.update({
          where: { id },
          data: {
            deleted_at: null,
            ...(constraints ? { constraints } : {}),
          },
        });

        return {
          roster,
          restored_shifts: shiftIds.length,
          restored_assignments: restoredAssignments,
          restored_day_offs: dayOffResult.count || 0,
        };
      });
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.roster.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Permanently delete a soft-deleted roster and remove all schedule links for
 * staff that used this template.
 */
const permanentDelete = async (id) => {
  try {
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.roster.findFirst({
        where: rosterWhereById(id, { includeDeleted: true }),
        select: { id: true, deleted_at: true, constraints: true },
      });

      if (!existing) {
        return {
          removed_staff_ids: [],
          removed_shifts: 0,
          removed_assignments: 0,
          removed_day_offs: 0,
        };
      }
      if (!existing.deleted_at) {
        throw new HttpError(
          'errors.roster.permanent_delete_requires_soft_delete',
          400
        );
      }

      const constraints =
        existing.constraints && typeof existing.constraints === 'object'
          ? existing.constraints
          : {};
      const removedStaffIds = Array.isArray(constraints.attached_staff_ids)
        ? [
            ...new Set(
              constraints.attached_staff_ids
                .map((value) => String(value || '').trim())
                .filter(Boolean)
            ),
          ]
        : [];

      return prisma.$transaction(async (tx) => {
        const shifts = await tx.shift.findMany({
          where: { roster_id: id },
          select: { id: true },
        });
        const shiftIds = shifts.map((row) => row.id);

        let removedAssignments = 0;
        if (shiftIds.length) {
          const assignmentResult = await tx.shift_assignment.deleteMany({
            where: { shift_id: { in: shiftIds } },
          });
          removedAssignments = assignmentResult.count || 0;
          await tx.shift_swap_request.deleteMany({
            where: { shift_id: { in: shiftIds } },
          });
          await tx.office_context.deleteMany({
            where: { shift_id: { in: shiftIds } },
          });
          await tx.shift_close.deleteMany({
            where: { shift_id: { in: shiftIds } },
          });
          await tx.shift.deleteMany({
            where: { id: { in: shiftIds } },
          });
        }

        const dayOffResult = await tx.roster_day_off.deleteMany({
          where: { roster_id: id },
        });
        await tx.roster.delete({ where: { id } });

        return {
          removed_staff_ids: removedStaffIds,
          removed_shifts: shiftIds.length,
          removed_assignments: removedAssignments,
          removed_day_offs: dayOffResult.count || 0,
        };
      });
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.roster.not_found', 404);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: target },
      ]);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
  restore,
  permanentDelete,
};

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error?.code === 'P2025') {
      throw new HttpError('errors.resource.not_found', 404);
    }
    if (error?.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error?.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countStaffProfiles = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.staff_profile.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const countStaffLeaves = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.staff_leave.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const countShiftSwaps = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.shift_swap_request.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const countRosters = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.nurse_roster.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const countPayrollRuns = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payroll_run.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const countShifts = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.shift.count({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
    })
  );

const findManyLeaves = async ({ where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.staff_leave.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      include: {
        staff_profile: {
          select: {
            id: true,
            human_friendly_id: true,
            staff_number: true,
            position: true,
            user: {
              select: {
                id: true,
                human_friendly_id: true,
                first_name: true,
                last_name: true,
                email: true,
              },
            },
          },
        },
      },
      skip,
      take,
      orderBy,
    })
  );

const findManyShiftSwaps = async ({ where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.shift_swap_request.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      include: {
        shift: {
          select: {
            id: true,
            human_friendly_id: true,
            shift_type: true,
            start_time: true,
            end_time: true,
            facility_id: true,
            tenant_id: true,
          },
        },
        requester: {
          select: {
            id: true,
            human_friendly_id: true,
            staff_number: true,
            position: true,
          },
        },
        target: {
          select: {
            id: true,
            human_friendly_id: true,
            staff_number: true,
            position: true,
          },
        },
      },
      skip,
      take,
      orderBy,
    })
  );

const findManyRosters = async ({ where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.nurse_roster.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      skip,
      take,
      orderBy,
    })
  );

const findManyPayrollRuns = async ({ where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.payroll_run.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      skip,
      take,
      orderBy,
    })
  );

const findManyUnassignedShifts = async ({ where = {}, skip = 0, take = 20, orderBy = { start_time: 'asc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.shift.findMany({
      where: {
        deleted_at: null,
        assignments: {
          none: {
            deleted_at: null,
          },
        },
        ...(where || {}),
      },
      include: {
        nurse_roster: {
          select: {
            id: true,
            human_friendly_id: true,
            status: true,
          },
        },
      },
      skip,
      take,
      orderBy,
    })
  );

const findManyOverdueShifts = async ({ where = {}, skip = 0, take = 20, orderBy = { start_time: 'asc' } } = {}) =>
  withDbErrorHandling(() =>
    prisma.shift.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      include: {
        assignments: {
          where: { deleted_at: null },
          select: {
            id: true,
            human_friendly_id: true,
            staff_profile_id: true,
          },
        },
      },
      skip,
      take,
      orderBy,
    })
  );

const findTimelineLeaves = async (where = {}, take = 10) =>
  withDbErrorHandling(() =>
    prisma.staff_leave.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      take,
      orderBy: { updated_at: 'desc' },
      include: {
        staff_profile: {
          select: {
            human_friendly_id: true,
            staff_number: true,
          },
        },
      },
    })
  );

const findTimelineSwaps = async (where = {}, take = 10) =>
  withDbErrorHandling(() =>
    prisma.shift_swap_request.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      take,
      orderBy: { updated_at: 'desc' },
      include: {
        shift: {
          select: {
            human_friendly_id: true,
          },
        },
      },
    })
  );

const findTimelineRosters = async (where = {}, take = 10) =>
  withDbErrorHandling(() =>
    prisma.nurse_roster.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      take,
      orderBy: { updated_at: 'desc' },
    })
  );

const findTimelinePayrollRuns = async (where = {}, take = 10) =>
  withDbErrorHandling(() =>
    prisma.payroll_run.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      take,
      orderBy: { updated_at: 'desc' },
    })
  );

const findTimelineShifts = async (where = {}, take = 10) =>
  withDbErrorHandling(() =>
    prisma.shift.findMany({
      where: {
        deleted_at: null,
        ...(where || {}),
      },
      take,
      orderBy: { updated_at: 'desc' },
    })
  );

const withTransaction = async (callback) => withDbErrorHandling(() => prisma.$transaction((tx) => callback(tx)));

module.exports = {
  countStaffProfiles,
  countStaffLeaves,
  countShiftSwaps,
  countRosters,
  countPayrollRuns,
  countShifts,
  findManyLeaves,
  findManyShiftSwaps,
  findManyRosters,
  findManyPayrollRuns,
  findManyUnassignedShifts,
  findManyOverdueShifts,
  findTimelineLeaves,
  findTimelineSwaps,
  findTimelineRosters,
  findTimelinePayrollRuns,
  findTimelineShifts,
  withTransaction,
};

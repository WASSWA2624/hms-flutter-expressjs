/**
 * Shared roster period queries used by roster engine and payroll activity.
 */

const prisma = require('@prisma/client');

const listAvailability = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.staff_availability.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: { in: profileIds },
      effective_from: { lte: periodEnd },
      OR: [{ effective_to: null }, { effective_to: { gte: periodStart } }],
    },
  });
};

const listApprovedLeaves = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.staff_leave.findMany({
    where: {
      deleted_at: null,
      status: 'APPROVED',
      staff_profile_id: { in: profileIds },
      start_date: { lte: periodEnd },
      end_date: { gte: periodStart },
    },
  });
};

const listExistingAssignments = async (profileIds, periodStart, periodEnd) => {
  if (!Array.isArray(profileIds) || !profileIds.length) return [];

  return prisma.shift_assignment.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: { in: profileIds },
      shift: {
        deleted_at: null,
        start_time: { lte: periodEnd },
        end_time: { gte: periodStart },
      },
    },
    include: {
      shift: {
        select: {
          id: true,
          human_friendly_id: true,
          start_time: true,
          end_time: true,
          roster_id: true,
        },
      },
    },
  });
};

module.exports = {
  listAvailability,
  listApprovedLeaves,
  listExistingAssignments,
};

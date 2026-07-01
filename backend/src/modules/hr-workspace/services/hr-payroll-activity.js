/**
 * Period-scoped activity aggregates for payroll calculation.
 *
 * Data sources:
 * - shift_assignment (via roster engine listExistingAssignments)
 * - staff_availability (via roster engine listAvailability)
 * - staff_leave APPROVED (via roster engine listApprovedLeaves)
 * - encounter OPD CLOSED for consultation counts (provider_user_id → staff user)
 * - procedure.performed_at on provider encounters for procedure counts
 */

const prisma = require('@prisma/client');
const {
  listAvailability,
  listApprovedLeaves,
  listExistingAssignments,
} = require('./hr-roster-engine-queries');

const buildStaffActivityMap = (staffProfiles = []) => {
  const map = new Map();
  for (const profile of staffProfiles) {
    if (!profile?.id) continue;
    map.set(profile.id, {
      profile,
      assignments: [],
      availability: [],
      leaves: [],
      totalHours: 0,
      assignmentCount: 0,
      consultationCount: 0,
      procedureCount: 0,
    });
  }
  return map;
};

const sumAssignmentHours = (assignments = []) => {
  let totalHours = 0;
  for (const assignment of assignments) {
    const start = assignment?.shift?.start_time;
    const end = assignment?.shift?.end_time;
    if (!start || !end) continue;
    totalHours += Math.max(0, (new Date(end).getTime() - new Date(start).getTime()) / 3600000);
  }
  return Number(totalHours.toFixed(2));
};

const countConsultationsForUser = async ({ tenantId, userId, periodStart, periodEnd, facilityId }) => {
  if (!userId) return 0;
  return prisma.encounter.count({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      provider_user_id: userId,
      encounter_type: 'OPD',
      status: 'CLOSED',
      ...(facilityId ? { facility_id: facilityId } : {}),
      started_at: { lte: periodEnd },
      OR: [
        { ended_at: { gte: periodStart } },
        { ended_at: null, started_at: { gte: periodStart } },
      ],
    },
  });
};

const countProceduresForUser = async ({ tenantId, userId, periodStart, periodEnd, facilityId }) => {
  if (!userId) return 0;
  return prisma.procedure.count({
    where: {
      deleted_at: null,
      performed_at: { gte: periodStart, lte: periodEnd },
      encounter: {
        deleted_at: null,
        tenant_id: tenantId,
        provider_user_id: userId,
        ...(facilityId ? { facility_id: facilityId } : {}),
      },
    },
  });
};

const loadStaffPayrollActivity = async ({
  staffProfiles = [],
  periodStart,
  periodEnd,
  tenantId,
  facilityId = null,
}) => {
  const profileIds = staffProfiles.map((profile) => profile.id).filter(Boolean);
  const activityMap = buildStaffActivityMap(staffProfiles);

  if (!profileIds.length) {
    return activityMap;
  }

  const [availability, leaves, assignments] = await Promise.all([
    listAvailability(profileIds, periodStart, periodEnd),
    listApprovedLeaves(profileIds, periodStart, periodEnd),
    listExistingAssignments(profileIds, periodStart, periodEnd),
  ]);

  for (const record of availability) {
    const entry = activityMap.get(record.staff_profile_id);
    if (entry) entry.availability.push(record);
  }
  for (const record of leaves) {
    const entry = activityMap.get(record.staff_profile_id);
    if (entry) entry.leaves.push(record);
  }
  for (const record of assignments) {
    const entry = activityMap.get(record.staff_profile_id);
    if (!entry) continue;
    entry.assignments.push(record);
    entry.assignmentCount += 1;
  }

  await Promise.all(
    [...activityMap.values()].map(async (entry) => {
      entry.totalHours = sumAssignmentHours(entry.assignments);
      const userId = entry.profile?.user_id || entry.profile?.user?.id;
      const [consultationCount, procedureCount] = await Promise.all([
        countConsultationsForUser({ tenantId, userId, periodStart, periodEnd, facilityId }),
        countProceduresForUser({ tenantId, userId, periodStart, periodEnd, facilityId }),
      ]);
      entry.consultationCount = consultationCount;
      entry.procedureCount = procedureCount;
    })
  );

  return activityMap;
};

module.exports = {
  loadStaffPayrollActivity,
  countConsultationsForUser,
  countProceduresForUser,
};

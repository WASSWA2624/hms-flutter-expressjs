/**
 * Keeps staff_profile.department_id aligned with active department assignments.
 *
 * @module lib/hr/staff-department-sync
 */

const prisma = require('@prisma/client');

const activeAssignmentWhere = (staffProfileId) => ({
  staff_profile_id: staffProfileId,
  deleted_at: null,
  department_id: { not: null },
  OR: [{ end_date: null }, { end_date: { gt: new Date() } }],
});

const resolvePrimaryDepartmentId = async (staffProfileId) => {
  const assignment = await prisma.staff_assignment.findFirst({
    where: activeAssignmentWhere(staffProfileId),
    orderBy: [{ start_date: 'desc' }, { created_at: 'desc' }],
    select: { department_id: true },
  });
  return assignment?.department_id || null;
};

/**
 * Sync staff profile primary department from active assignments.
 *
 * @param {string} staffProfileId
 * @returns {Promise<Object|null>} Updated profile snapshot or null when missing
 */
const syncStaffProfilePrimaryDepartment = async (staffProfileId) => {
  const profile = await prisma.staff_profile.findFirst({
    where: { id: staffProfileId, deleted_at: null },
    select: {
      id: true,
      department_id: true,
      tenant_id: true,
      human_friendly_id: true,
      staff_number: true,
    },
  });
  if (!profile) {
    return null;
  }

  const nextDepartmentId = await resolvePrimaryDepartmentId(staffProfileId);

  if (nextDepartmentId) {
    if (profile.department_id !== nextDepartmentId) {
      return prisma.staff_profile.update({
        where: { id: profile.id },
        data: { department_id: nextDepartmentId },
        select: {
          id: true,
          department_id: true,
          tenant_id: true,
          human_friendly_id: true,
          staff_number: true,
        },
      });
    }
    return profile;
  }

  if (!profile.department_id) {
    return profile;
  }

  const assignmentBackedDepartment = await prisma.staff_assignment.findFirst({
    where: {
      staff_profile_id: staffProfileId,
      deleted_at: null,
      department_id: profile.department_id,
    },
    select: { id: true },
  });

  if (!assignmentBackedDepartment) {
    return profile;
  }

  return prisma.staff_profile.update({
    where: { id: profile.id },
    data: { department_id: null },
    select: {
      id: true,
      department_id: true,
      tenant_id: true,
      human_friendly_id: true,
      staff_number: true,
    },
  });
};

module.exports = {
  resolvePrimaryDepartmentId,
  syncStaffProfilePrimaryDepartment,
};

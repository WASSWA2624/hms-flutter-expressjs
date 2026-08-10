const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Resolve the caller's active staff_profile by authenticated user id.
 * @param {string|undefined|null} userId
 * @returns {Promise<{id: string, tenant_id: string, human_friendly_id: string|null, staff_number: string|null, position: string|null}>}
 */
const requireStaffProfileForUser = async (userId) => {
  if (!userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const profile = await prisma.staff_profile.findFirst({
    where: {
      user_id: userId,
      deleted_at: null,
    },
    select: {
      id: true,
      tenant_id: true,
      human_friendly_id: true,
      staff_number: true,
      position: true,
    },
  });

  if (!profile) {
    throw new HttpError('errors.staff_profile.not_found', 404, [
      { field: 'staff_profile', message: 'No staff profile linked to this user.' },
    ]);
  }

  return profile;
};

module.exports = {
  requireStaffProfileForUser,
};

/**
 * Resolve the operational facility for scoped clinical/lab workflows.
 */

const authRepository = require('@repositories/auth/auth.repository');

const resolveOperationalFacilityId = async ({
  facilityId = null,
  userId = null,
  tenantId = null,
} = {}) => {
  if (facilityId) {
    return facilityId;
  }
  if (!userId || !tenantId) {
    return null;
  }

  const facilities = await authRepository.getUserFacilities(userId, tenantId);
  return facilities.length === 1 ? facilities[0].id : null;
};

module.exports = {
  resolveOperationalFacilityId,
};

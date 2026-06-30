/**
 * Tenant-scoped staff number generation.
 *
 * @module lib/hr/staff-number
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const normalizeString = (value) => String(value || '').trim();

const buildStaffNumberPrefix = (tenant = {}) => {
  const slug = normalizeString(tenant.slug || tenant.human_friendly_id || tenant.name)
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, 8);
  return slug ? `${slug}-STF` : 'STF';
};

const resolveTenantRecord = async (tenantId) => {
  if (!tenantId) {
    return null;
  }
  return prisma.tenant.findFirst({
    where: { id: tenantId, deleted_at: null },
    select: { id: true, human_friendly_id: true, slug: true, name: true },
  });
};

const resolveTenantId = async ({ tenantId = null, facilityId = null } = {}) => {
  if (tenantId) {
    return tenantId;
  }
  if (!facilityId) {
    return null;
  }
  const facility = await prisma.facility.findFirst({
    where: { id: facilityId, deleted_at: null },
    select: { tenant_id: true },
  });
  return facility?.tenant_id || null;
};

/**
 * Generate a unique staff number for a tenant.
 *
 * @param {{ tenantId?: string|null, facilityId?: string|null }} params
 * @returns {Promise<{ staff_number: string, tenant_id: string }>}
 */
const generateStaffNumber = async ({ tenantId = null, facilityId = null } = {}) => {
  const resolvedTenantId = await resolveTenantId({ tenantId, facilityId });
  if (!resolvedTenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const tenant = await resolveTenantRecord(resolvedTenantId);
  if (!tenant) {
    throw new HttpError('errors.tenant.not_found', 404);
  }

  const prefix = buildStaffNumberPrefix(tenant);
  const count = await prisma.staff_profile.count({
    where: { tenant_id: resolvedTenantId, deleted_at: null },
  });

  for (let attempt = 0; attempt < 25; attempt += 1) {
    const sequence = String(count + 1 + attempt).padStart(4, '0');
    const candidate = `${prefix}-${sequence}`;
    const existing = await prisma.staff_profile.findFirst({
      where: {
        tenant_id: resolvedTenantId,
        staff_number: candidate,
        deleted_at: null,
      },
      select: { id: true },
    });
    if (!existing) {
      return { staff_number: candidate, tenant_id: resolvedTenantId };
    }
  }

  throw new HttpError('errors.staff_profile.staff_number_generation_failed', 500);
};

module.exports = {
  buildStaffNumberPrefix,
  generateStaffNumber,
  resolveTenantId,
};

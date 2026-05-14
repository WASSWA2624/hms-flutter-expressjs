/**
 * License service
 *
 * @module modules/license/services
 * @description Business logic for license operations.
 */

const licenseRepository = require('@repositories/license/license.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const { serializeLicense } = require('@lib/subscriptions/serializers');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  canAccessTenant,
  resolveUserTenantScope,
} = require('@lib/subscriptions/access');

const requireTenantScope = (user = {}) => {
  const scope = resolveUserTenantScope(user);
  if (!scope.is_elevated && !scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return scope;
};

const emptyList = (page, limit) => ({
  licenses: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const loadLicenseRecord = async (identifier, user = {}) => {
  const scope = requireTenantScope(user);
  const resolvedId = await resolveEntityId({
    model: 'license',
    identifier,
    where: scope.is_elevated ? {} : { tenant_id: scope.tenant_id },
  });
  const record = await licenseRepository.findById(resolvedId);

  if (!record || !canAccessTenant(scope, record.tenant_id)) {
    throw new HttpError('errors.license.not_found', 404);
  }

  return record;
};

const resolveLicensePayload = async (data = {}, context = {}) => {
  const scope = requireTenantScope(context.user);
  const payload = {
    ...data,
  };

  if (!scope.is_elevated) {
    payload.tenant_id = scope.tenant_id;
    return payload;
  }

  if (data.tenant_id !== undefined) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
    });
  }

  return payload;
};

const listLicenses = async (
  filters = {},
  page = 1,
  limit = 20,
  sort_by = 'created_at',
  order = 'desc',
  user = {}
) => {
  const scope = requireTenantScope(user);
  const repoFilters = !scope.is_elevated ? { tenant_id: scope.tenant_id } : {};

  if (filters.tenant_id) {
    const requestedTenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });

    if (requestedTenantId === null) {
      return emptyList(page, limit);
    }

    if (
      !scope.is_elevated
      && requestedTenantId
      && requestedTenantId !== scope.tenant_id
    ) {
      return emptyList(page, limit);
    }

    if (requestedTenantId) {
      repoFilters.tenant_id = requestedTenantId;
    }
  }

  if (filters.license_type) {
    repoFilters.license_type = filters.license_type;
  }

  if (filters.status) {
    repoFilters.status = filters.status;
  }

  const skip = (page - 1) * limit;
  const orderBy = {
    [sort_by]: order,
  };

  const [licenses, total] = await Promise.all([
    licenseRepository.findMany(repoFilters, skip, limit, orderBy),
    licenseRepository.count(repoFilters),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    licenses: licenses.map(serializeLicense),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage,
    },
  };
};

const getLicenseById = async (id, user = {}) => {
  const license = await loadLicenseRecord(id, user);
  return serializeLicense(license);
};

const createLicense = async (data, context) => {
  const scope = requireTenantScope(context.user);
  const created = await licenseRepository.create({
    ...(await resolveLicensePayload(
      {
        ...data,
        tenant_id: scope.is_elevated ? data.tenant_id : scope.tenant_id,
      },
      context
    )),
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.license),
  });
  const license = await loadLicenseRecord(created.id, context.user);

  createAuditLog({
    user_id: context.user?.id,
    action: 'CREATE',
    entity: 'license',
    entity_id: license.id,
    diff: { after: license },
    ip_address: context.ip,
    tenant_id: license.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeLicense(license);
};

const updateLicense = async (id, data, context) => {
  const existingLicense = await loadLicenseRecord(id, context.user);
  await licenseRepository.update(
    existingLicense.id,
    await resolveLicensePayload(data, context)
  );
  const updatedLicense = await loadLicenseRecord(existingLicense.id, context.user);

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'license',
    entity_id: updatedLicense.id,
    diff: { before: existingLicense, after: updatedLicense },
    ip_address: context.ip,
    tenant_id: existingLicense.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeLicense(updatedLicense);
};

const deleteLicense = async (id, context) => {
  const existingLicense = await loadLicenseRecord(id, context.user);
  const deletedLicense = await licenseRepository.softDelete(existingLicense.id);

  createAuditLog({
    user_id: context.user?.id,
    action: 'DELETE',
    entity: 'license',
    entity_id: deletedLicense.id,
    diff: { before: existingLicense, after: deletedLicense },
    ip_address: context.ip,
    tenant_id: existingLicense.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return deletedLicense;
};

module.exports = {
  listLicenses,
  getLicenseById,
  createLicense,
  updateLicense,
  deleteLicense,
};

const abacPolicyRepository = require('@repositories/abac-policy/abac-policy.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const { buildPagination } = require('@lib/last-office/shared');
const { serializeAbacPolicy } = require('@lib/authorization/serializers');

const listAbacPolicies = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const skip = (page - 1) * limit;
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const where = { tenant_id: tenantId };
  const facilityId = await resolveIdentifierForFilter({
    value: filters.facility_id ?? context.facility_id,
    model: 'facility',
    where: { tenant_id: tenantId },
  });
  const branchId = await resolveIdentifierForFilter({
    value: filters.branch_id ?? context.branch_id,
    model: 'branch',
    where: { tenant_id: tenantId },
  });
  const departmentId = await resolveIdentifierForFilter({
    value: filters.department_id,
    model: 'department',
    where: { tenant_id: tenantId },
  });

  if (facilityId) where.facility_id = facilityId;
  if (branchId) where.branch_id = branchId;
  if (departmentId) where.department_id = departmentId;
  if (filters.resource_type) where.resource_type = String(filters.resource_type).trim();
  if (filters.action) where.action = String(filters.action).trim();
  if (filters.effect) where.effect = String(filters.effect).trim().toUpperCase();
  if (filters.is_active !== undefined) where.is_active = String(filters.is_active) === 'true';

  const [rows, total] = await Promise.all([
    abacPolicyRepository.findMany(where, skip, limit),
    abacPolicyRepository.count(where),
  ]);

  return {
    policies: rows.map(serializeAbacPolicy),
    pagination: buildPagination(page, limit, total),
  };
};

const getAbacPolicyById = async (id) => {
  const resolvedId = await resolveEntityId({ model: 'abac_policy', identifier: id });
  const policy = await abacPolicyRepository.findById(resolvedId);
  if (!policy) {
    throw new HttpError('errors.abac_policy.not_found', 404);
  }
  return serializeAbacPolicy(policy);
};

const createAbacPolicy = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const record = await abacPolicyRepository.create({
    tenant_id: tenantId,
    facility_id: await resolveIdentifierForPayload({
      value: payload.facility_id ?? context.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    branch_id: await resolveIdentifierForPayload({
      value: payload.branch_id ?? context.branch_id,
      field: 'branch_id',
      model: 'branch',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    department_id: await resolveIdentifierForPayload({
      value: payload.department_id,
      field: 'department_id',
      model: 'department',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    name: payload.name,
    description: payload.description || null,
    resource_type: payload.resource_type,
    action: payload.action,
    effect: payload.effect,
    priority: payload.priority ?? 100,
    subject_conditions_json: payload.subject_conditions_json || null,
    object_conditions_json: payload.object_conditions_json || null,
    environment_conditions_json: payload.environment_conditions_json || null,
    reason_template: payload.reason_template || null,
    is_active: payload.is_active !== false,
    created_by_user_id: context.user_id || null,
    updated_by_user_id: context.user_id || null,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'abac_policy',
    entity_id: record.id,
    diff: { after: serializeAbacPolicy(record) },
    ip_address: context.ip_address,
  }).catch(() => {});

  return serializeAbacPolicy(record);
};

const updateAbacPolicy = async (id, payload = {}, context = {}) => {
  const resolvedId = await resolveEntityId({ model: 'abac_policy', identifier: id });
  const existing = await abacPolicyRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.abac_policy.not_found', 404);
  }

  const tenantId = existing.tenant_id;
  const next = await abacPolicyRepository.update(existing.id, {
    facility_id: Object.prototype.hasOwnProperty.call(payload, 'facility_id')
      ? await resolveIdentifierForPayload({
          value: payload.facility_id,
          field: 'facility_id',
          model: 'facility',
          nullable: true,
          where: { tenant_id: tenantId },
        })
      : undefined,
    branch_id: Object.prototype.hasOwnProperty.call(payload, 'branch_id')
      ? await resolveIdentifierForPayload({
          value: payload.branch_id,
          field: 'branch_id',
          model: 'branch',
          nullable: true,
          where: { tenant_id: tenantId },
        })
      : undefined,
    department_id: Object.prototype.hasOwnProperty.call(payload, 'department_id')
      ? await resolveIdentifierForPayload({
          value: payload.department_id,
          field: 'department_id',
          model: 'department',
          nullable: true,
          where: { tenant_id: tenantId },
        })
      : undefined,
    name: payload.name,
    description: payload.description,
    resource_type: payload.resource_type,
    action: payload.action,
    effect: payload.effect,
    priority: payload.priority,
    subject_conditions_json: payload.subject_conditions_json,
    object_conditions_json: payload.object_conditions_json,
    environment_conditions_json: payload.environment_conditions_json,
    reason_template: payload.reason_template,
    is_active: payload.is_active,
    updated_by_user_id: context.user_id || existing.updated_by_user_id || null,
    version: Number(existing.version || 1) + 1,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'abac_policy',
    entity_id: existing.id,
    diff: { before: serializeAbacPolicy(existing), after: serializeAbacPolicy(next) },
    ip_address: context.ip_address,
  }).catch(() => {});

  return serializeAbacPolicy(next);
};

const deleteAbacPolicy = async (id, context = {}) => {
  const resolvedId = await resolveEntityId({ model: 'abac_policy', identifier: id });
  const existing = await abacPolicyRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.abac_policy.not_found', 404);
  }

  await abacPolicyRepository.softDelete(existing.id);
  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'abac_policy',
    entity_id: existing.id,
    diff: { before: serializeAbacPolicy(existing) },
    ip_address: context.ip_address,
  }).catch(() => {});
};

module.exports = {
  createAbacPolicy,
  deleteAbacPolicy,
  getAbacPolicyById,
  listAbacPolicies,
  updateAbacPolicy,
};

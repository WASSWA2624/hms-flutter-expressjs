/**
 * Unit service
 *
 * @module modules/unit/services
 * @description Business logic for unit operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const unitRepository = require('@repositories/unit/unit.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier} = require('@lib/identifiers/resolve-entity-id');
const { publishCrudRealtimeEvent, FACILITY_LAYOUT_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');

const FACILITY_LAYOUT_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.NURSE]);

const publishFacilityLayoutRealtimeEvent = async (resource, resourceType, actorUserId, payload = {}) => {
  await publishCrudRealtimeEvent({
    event: FACILITY_LAYOUT_EVENTS.FACILITY_LAYOUT_UPDATED,
    resource,
    resource_type: resourceType,
    actor_user_id: actorUserId,
    recipient_roles: FACILITY_LAYOUT_RECIPIENT_ROLES,
    affected: {
      unit_id: resource?.id || null,
      department_id: resource?.department_id || null},
    payload: {
      layout_entity: resourceType,
      ...payload}});
};

const emptyListResult = (page, limit) => ({
  units: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1}});

const resolveUnitId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'unit',
      identifier: normalized,
      includeDeleted: true});
    return resolved || normalized;
  }

  return resolveEntityId({
    model: 'unit',
    identifier: normalized,
    where: { deleted_at: null }});
};

const resolveUnitFilterId = async (filters, field, model) => {
  if (!filters?.[field]) return undefined;
  const resolved = await resolveIdentifierForFilter({
    value: filters[field],
    model,
    where: { deleted_at: null }});
  if (resolved === null) return null;
  return resolved;
};

const normalizeCreatePayload = async (data = {}) => ({
  ...data,
  tenant_id: await resolveIdentifierForPayload({
    value: data.tenant_id,
    model: 'tenant',
    field: 'tenant_id',
    where: { deleted_at: null }}),
  facility_id: await resolveIdentifierForPayload({
    value: data.facility_id,
    model: 'facility',
    field: 'facility_id',
    where: { deleted_at: null },
    nullable: true}),
  department_id: await resolveIdentifierForPayload({
    value: data.department_id,
    model: 'department',
    field: 'department_id',
    where: { deleted_at: null },
    nullable: true})});

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      where: { deleted_at: null },
      nullable: true});
  }

  if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
    payload.department_id = await resolveIdentifierForPayload({
      value: data.department_id,
      model: 'department',
      field: 'department_id',
      where: { deleted_at: null },
      nullable: true});
  }

  return payload;
};

/**
 * List units with pagination and filters
 */
const listUnits = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';
  const repoFilters = {};

  const tenantId = await resolveUnitFilterId(filters, 'tenant_id', 'tenant');
  if (filters.tenant_id && tenantId === null) return emptyListResult(page, limit);
  if (tenantId) repoFilters.tenant_id = tenantId;

  const facilityId = await resolveUnitFilterId(filters, 'facility_id', 'facility');
  if (filters.facility_id && facilityId === null) return emptyListResult(page, limit);
  if (facilityId) repoFilters.facility_id = facilityId;

  const departmentId = await resolveUnitFilterId(filters, 'department_id', 'department');
  if (filters.department_id && departmentId === null) return emptyListResult(page, limit);
  if (departmentId) repoFilters.department_id = departmentId;

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  if (filters.search) {
    repoFilters.name = { contains: filters.search, mode: 'insensitive' };
  }

  const skip = (page - 1) * limit;
  const orderBy = includeDeleted
    ? [{ deleted_at: 'asc' }, { [sort_by]: order }]
    : { [sort_by]: order };
  const listOptions = { includeDeleted };

  const [units, total] = await Promise.all([
    unitRepository.findMany(repoFilters, skip, limit, orderBy, listOptions),
    unitRepository.count(repoFilters, listOptions)]);

  const totalPages = Math.ceil(total / limit);

  return {
    units,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1}};
};

/**
 * Get unit by ID
 */
const getUnitById = async (id) => {
  const resolvedId = await resolveUnitId(id);
  const unit = await unitRepository.findById(resolvedId);

  if (!unit) {
    throw new HttpError('errors.unit.not_found', 404);
  }

  return unit;
};

/**
 * Create new unit
 */
const createUnit = async (data, context = {}) => {
  const payload = await normalizeCreatePayload(data);
  const unit = await unitRepository.create(payload);

  await createAuditLog({
    action: 'UNIT_CREATED',
    entity: 'unit',
    entity_id: unit.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: unit.tenant_id,
      facility_id: unit.facility_id,
      department_id: unit.department_id,
      name: unit.name,
      is_active: unit.is_active}});

  await publishFacilityLayoutRealtimeEvent(unit, 'unit', context.user_id, {
    operation: 'created',
    name: unit.name});

  return unit;
};

/**
 * Update unit
 */
const updateUnit = async (id, data, context = {}) => {
  const resolvedId = await resolveUnitId(id);
  const beforeUnit = await unitRepository.findById(resolvedId);

  if (!beforeUnit) {
    throw new HttpError('errors.unit.not_found', 404);
  }

  const payload = await normalizeUpdatePayload(data);
  const unit = await unitRepository.update(beforeUnit.id, payload);

  await createAuditLog({
    action: 'UNIT_UPDATED',
    entity: 'unit',
    entity_id: beforeUnit.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeUnit.facility_id,
        department_id: beforeUnit.department_id,
        name: beforeUnit.name,
        is_active: beforeUnit.is_active},
      after: {
        facility_id: unit.facility_id,
        department_id: unit.department_id,
        name: unit.name,
        is_active: unit.is_active}}});

  await publishFacilityLayoutRealtimeEvent(unit, 'unit', context.user_id, {
    operation: 'updated',
    name: unit.name});

  return unit;
};

/**
 * Delete unit (soft delete)
 */
const deleteUnit = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const resolvedId = await resolveUnitId(normalizedId);
  const unit = await unitRepository.findById(resolvedId);

  if (!unit) {
    const lookupIds = [...new Set([resolvedId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedUnit = await resolveModelRecordByIdentifier({
        model: 'unit',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true }});
      if (deletedUnit?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.unit.not_found', 404);
  }

  await unitRepository.softDelete(unit.id);

  await createAuditLog({
    action: 'UNIT_DELETED',
    entity: 'unit',
    entity_id: unit.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: unit.tenant_id,
      facility_id: unit.facility_id,
      department_id: unit.department_id,
      name: unit.name}});

  await publishFacilityLayoutRealtimeEvent(unit, 'unit', context.user_id, {
    operation: 'deleted',
    name: unit.name});
};

/**
 * Restore soft-deleted unit
 */
const restoreUnit = async (id, context = {}) => {
  const unitId = await resolveUnitId(id, { includeDeleted: true });
  const unit = await unitRepository.restore(unitId);

  await createAuditLog({
    action: 'UNIT_RESTORED',
    entity: 'unit',
    entity_id: unitId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: unit.tenant_id,
      facility_id: unit.facility_id,
      department_id: unit.department_id,
      name: unit.name}});

  await publishFacilityLayoutRealtimeEvent(unit, 'unit', context.user_id, {
    operation: 'restored',
    name: unit.name});

  return unit;
};

module.exports = {
  listUnits,
  getUnitById,
  createUnit,
  updateUnit,
  deleteUnit,
  restoreUnit};

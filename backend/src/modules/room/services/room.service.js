/**
 * Room service
 *
 * @module modules/room/services
 * @description Business logic for room operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const roomRepository = require('@repositories/room/room.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter } = require('@lib/identifiers/service-identifier-resolution');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier} = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { publishCrudRealtimeEvent, FACILITY_LAYOUT_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');

const FACILITY_LAYOUT_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.NURSE
]);

const normalizeRoomRecord = (room) => {
  if (!room || typeof room !== 'object') {
    return room;
  }

  return {
    ...room,
    resource_uuid: room.id,
    display_id: resolvePublicIdentifier(room.human_friendly_id) || null
  };
};

const publishFacilityLayoutRealtimeEvent = async (resource, resourceType, actorUserId, payload = {}) => {
  await publishCrudRealtimeEvent({
    event: FACILITY_LAYOUT_EVENTS.FACILITY_LAYOUT_UPDATED,
    resource,
    resource_type: resourceType,
    actor_user_id: actorUserId,
    recipient_roles: FACILITY_LAYOUT_RECIPIENT_ROLES,
    affected: {
      ward_id: resource?.ward_id || null,
      room_id: resource?.id || resource?.room_id || null
    },
    payload: {
      layout_entity: resourceType,
      ...payload
    }
  });
};

/**
 * List rooms with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.ward_id] - Filter by ward ID
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated rooms
 */
const buildRoomListResult = (rooms, page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    rooms,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1}};
};

const resolveRoomFilterId = async (filters, field, model) => {
  if (!filters?.[field]) return undefined;
  return resolveIdentifierForFilter({
    value: filters[field],
    model,
    where: { deleted_at: null }});
};

const resolveRoomId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'room',
      identifier: normalized,
      includeDeleted: true});
    return resolved || normalized;
  }

  return resolveIdentifierForFilter({
    value: normalized,
    model: 'room',
    where: { deleted_at: null }}) || normalized;
};

const listRooms = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';
  const repoFilters = {};

  const tenantId = await resolveRoomFilterId(filters, 'tenant_id', 'tenant');
  if (tenantId === null) return buildRoomListResult([], page, limit, 0);
  if (tenantId !== undefined) repoFilters.tenant_id = tenantId;

  const facilityId = await resolveRoomFilterId(filters, 'facility_id', 'facility');
  if (facilityId === null) return buildRoomListResult([], page, limit, 0);
  if (facilityId !== undefined) repoFilters.facility_id = facilityId;

  const wardId = await resolveRoomFilterId(filters, 'ward_id', 'ward');
  if (wardId === null) return buildRoomListResult([], page, limit, 0);
  if (wardId !== undefined) repoFilters.ward_id = wardId;

  if (filters.search) {
    repoFilters.name = {
      contains: String(filters.search || '').trim(),
      mode: 'insensitive'};
  }

  const skip = (page - 1) * limit;
  const orderBy = includeDeleted
    ? [{ deleted_at: 'asc' }, { [sort_by]: order }]
    : { [sort_by]: order };
  const listOptions = { includeDeleted };

  const [rooms, total] = await Promise.all([
    roomRepository.findMany(repoFilters, skip, limit, orderBy, listOptions),
    roomRepository.count(repoFilters, listOptions)]);

  return buildRoomListResult(
    rooms.map((room) => normalizeRoomRecord(room)),
    page,
    limit,
    total
  );
};

/**
 * Get room by ID
 *
 * @param {string} id - Room ID
 * @returns {Promise<Object>} Room data
 */
const getRoomById = async (id) => {
  const roomId = await resolveRoomId(id);
  const room = await roomRepository.findById(roomId);
  
  if (!room) {
    throw new HttpError('errors.room.not_found', 404);
  }

  return normalizeRoomRecord(room);
};

/**
 * Create new room
 *
 * @param {Object} data - Room data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} data.facility_id - Facility ID
 * @param {string} [data.ward_id] - Ward ID
 * @param {string} data.name - Room name
 * @param {string} [data.floor] - Floor
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created room
 */
const createRoom = async (data, context = {}) => {
  // Create room
  const room = await roomRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'ROOM_CREATED',
    entity: 'room',
    entity_id: room.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: room.tenant_id,
      facility_id: room.facility_id,
      ward_id: room.ward_id,
      name: room.name,
      floor: room.floor
    }
  });

  await publishFacilityLayoutRealtimeEvent(room, 'room', context.user_id, {
    operation: 'created',
    name: room.name,
    ward_id: room.ward_id
  });

  return normalizeRoomRecord(room);
};

/**
 * Update room
 *
 * @param {string} id - Room ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.ward_id] - Ward ID
 * @param {string} [data.name] - Room name
 * @param {string} [data.floor] - Floor
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated room
 */
const updateRoom = async (id, data, context = {}) => {
  const roomId = await resolveRoomId(id);
  const beforeRoom = await roomRepository.findById(roomId);
  
  if (!beforeRoom) {
    throw new HttpError('errors.room.not_found', 404);
  }

  // Update room
  const room = await roomRepository.update(roomId, data);

  // Create audit log
  await createAuditLog({
    action: 'ROOM_UPDATED',
    entity: 'room',
    entity_id: roomId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeRoom.facility_id,
        ward_id: beforeRoom.ward_id,
        name: beforeRoom.name,
        floor: beforeRoom.floor
      },
      after: {
        facility_id: room.facility_id,
        ward_id: room.ward_id,
        name: room.name,
        floor: room.floor
      }
    }
  });

  await publishFacilityLayoutRealtimeEvent(room, 'room', context.user_id, {
    operation: 'updated',
    name: room.name,
    ward_id: room.ward_id
  });

  return normalizeRoomRecord(room);
};

/**
 * Delete room (soft delete)
 *
 * @param {string} id - Room ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteRoom = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const roomId = await resolveRoomId(normalizedId);
  const room = await roomRepository.findById(roomId);
  
  if (!room) {
    const lookupIds = [...new Set([roomId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedRoom = await resolveModelRecordByIdentifier({
        model: 'room',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true }});
      if (deletedRoom?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.room.not_found', 404);
  }

  await roomRepository.softDelete(roomId);

  await createAuditLog({
    action: 'ROOM_DELETED',
    entity: 'room',
    entity_id: roomId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: room.tenant_id,
      facility_id: room.facility_id,
      ward_id: room.ward_id,
      name: room.name
    }
  });

  await publishFacilityLayoutRealtimeEvent(room, 'room', context.user_id, {
    operation: 'deleted',
    name: room.name,
    ward_id: room.ward_id
  });
};

/**
 * Restore soft-deleted room
 */
const restoreRoom = async (id, context = {}) => {
  const roomId = await resolveRoomId(id, { includeDeleted: true });
  const room = await roomRepository.restore(roomId);

  await createAuditLog({
    action: 'ROOM_RESTORED',
    entity: 'room',
    entity_id: roomId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: room.tenant_id,
      facility_id: room.facility_id,
      ward_id: room.ward_id,
      name: room.name}});

  await publishFacilityLayoutRealtimeEvent(room, 'room', context.user_id, {
    operation: 'restored',
    name: room.name,
    ward_id: room.ward_id});

  return normalizeRoomRecord(room);
};

module.exports = {
  listRooms,
  getRoomById,
  createRoom,
  updateRoom,
  deleteRoom,
  restoreRoom};

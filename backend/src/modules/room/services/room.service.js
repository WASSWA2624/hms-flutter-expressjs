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
      hasPreviousPage: page > 1,
    },
  };
};

const resolveRoomFilterId = async (filters, field, model) => {
  if (!filters?.[field]) return undefined;
  return resolveIdentifierForFilter({
    value: filters[field],
    model,
    where: { deleted_at: null },
  });
};

const listRooms = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
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
    repoFilters.name = { contains: String(filters.search || '').trim() };
  }

  const skip = (page - 1) * limit;
  const orderBy = {};
  orderBy[sort_by] = order;

  const [rooms, total] = await Promise.all([
    roomRepository.findMany(repoFilters, skip, limit, orderBy),
    roomRepository.count(repoFilters),
  ]);

  return buildRoomListResult(rooms, page, limit, total);
};

/**
 * Get room by ID
 *
 * @param {string} id - Room ID
 * @returns {Promise<Object>} Room data
 */
const getRoomById = async (id) => {
  const room = await roomRepository.findById(id);
  
  if (!room) {
    throw new HttpError('errors.room.not_found', 404);
  }

  return room;
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

  return room;
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
  // Check if room exists and get before state
  const beforeRoom = await roomRepository.findById(id);
  
  if (!beforeRoom) {
    throw new HttpError('errors.room.not_found', 404);
  }

  // Update room
  const room = await roomRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'ROOM_UPDATED',
    entity: 'room',
    entity_id: id,
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

  return room;
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
  // Check if room exists
  const room = await roomRepository.findById(id);
  
  if (!room) {
    throw new HttpError('errors.room.not_found', 404);
  }

  // Soft delete room
  await roomRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'ROOM_DELETED',
    entity: 'room',
    entity_id: id,
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
};

module.exports = {
  listRooms,
  getRoomById,
  createRoom,
  updateRoom,
  deleteRoom
};

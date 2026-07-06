const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { toPublicIdentifier, toText } = require('@lib/identifiers');
const { resolveIdentifierForPayload } = require('@lib/identifiers/service-identifier-resolution');
const pharmacyStorageRepository = require('@repositories/pharmacy-workspace/pharmacy-storage.repository');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const {
  resolveScopedUserContext,
  buildTenantScopeWhere,
} = require('@services/pharmacy-workspace/pharmacy.shared');

const mapStorageRoomRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    tenant_id: toPublicIdentifier(record.tenant_id),
    facility_id: toPublicIdentifier(record.facility_id),
    name: toText(record.name) || null,
    code: toText(record.code) || null,
    is_active: Boolean(record.is_active),
    shelves: Array.isArray(record.shelves)
      ? record.shelves.map(mapStorageShelfRecord).filter(Boolean)
      : [],
  };
};

const mapStorageShelfRecord = (record) => {
  if (!record || typeof record !== 'object') return null;
  const publicId = toPublicIdentifier(record.human_friendly_id, record.id);
  return {
    id: publicId,
    display_id: publicId,
    tenant_id: toPublicIdentifier(record.tenant_id),
    facility_id: toPublicIdentifier(record.facility_id),
    storage_room_id: toPublicIdentifier(record.storage_room_id),
    shelf_code: toText(record.shelf_code) || null,
    label: toText(record.label) || null,
    is_active: Boolean(record.is_active),
    storage_room_label: toText(record.storage_room?.name) || null,
  };
};

const mapStorageLocationFields = (room = null, shelf = null) => {
  const roomLabel = toText(room?.name) || null;
  const shelfCode = toText(shelf?.label) || toText(shelf?.shelf_code) || null;
  const locationLabel =
    roomLabel && shelfCode ? `${roomLabel} · ${shelfCode}` : roomLabel || shelfCode || null;

  return {
    storage_room_id: room ? toPublicIdentifier(room.human_friendly_id, room.id) : null,
    storage_room_label: roomLabel,
    storage_shelf_id: shelf ? toPublicIdentifier(shelf.human_friendly_id, shelf.id) : null,
    storage_shelf_code: toText(shelf?.shelf_code) || null,
    storage_location_label: locationLabel,
  };
};

const resolveStorageRoomId = async (identifier, scope, facilityId) => {
  if (!identifier) return null;
  return resolveIdentifierForPayload({
    value: identifier,
    field: 'storage_room_id',
    model: 'pharmacy_storage_room',
    where: {
      deleted_at: null,
      ...buildTenantScopeWhere(scope),
      facility_id: facilityId,
    },
  });
};

const resolveStorageShelfId = async (identifier, scope, facilityId, storageRoomId = null) => {
  if (!identifier) return null;
  return resolveIdentifierForPayload({
    value: identifier,
    field: 'storage_shelf_id',
    model: 'pharmacy_storage_shelf',
    where: {
      deleted_at: null,
      ...buildTenantScopeWhere(scope),
      facility_id: facilityId,
      ...(storageRoomId ? { storage_room_id: storageRoomId } : {}),
    },
  });
};

const resolveStorageAssignment = async (payload = {}, scope, facilityId) => {
  const roomIdentifier = payload.storage_room_id || null;
  const shelfIdentifier = payload.storage_shelf_id || null;
  if (!roomIdentifier && !shelfIdentifier) {
    return { storageRoomId: null, storageShelfId: null, room: null, shelf: null };
  }
  if (shelfIdentifier && !roomIdentifier) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'storage_room_id' }]);
  }

  const storageRoomId = await resolveStorageRoomId(roomIdentifier, scope, facilityId);
  const room = await pharmacyStorageRepository.findStorageRoomById(storageRoomId, true);
  if (!room || room.facility_id !== facilityId) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'storage_room_id' }]);
  }

  let storageShelfId = null;
  let shelf = null;
  if (shelfIdentifier) {
    storageShelfId = await resolveStorageShelfId(
      shelfIdentifier,
      scope,
      facilityId,
      storageRoomId
    );
    shelf = await pharmacyStorageRepository.findStorageShelfById(storageShelfId, true);
    if (!shelf || shelf.storage_room_id !== storageRoomId) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'storage_shelf_id' }]);
    }
  }

  return { storageRoomId, storageShelfId, room, shelf };
};

const buildPrimaryBatchStorageSummary = (batches = []) => {
  const active = (batches || []).filter((batch) => Number(batch.quantity || 0) > 0);
  const withShelf = active.find((batch) => batch.storage_shelf_id || batch.storage_room_id);
  const selected = withShelf || active[0] || batches[0] || null;
  if (!selected) return mapStorageLocationFields();
  return mapStorageLocationFields(selected.storage_room, selected.storage_shelf);
};

const attachDrugStorageSummaries = async (drugs = []) => {
  if (!Array.isArray(drugs) || !drugs.length) return drugs;
  const drugIds = drugs.map((drug) => drug.id).filter(Boolean);
  const batches = await pharmacyStorageRepository.findDrugBatchesWithStorageByDrugIds(drugIds);
  const batchesByDrugId = batches.reduce((acc, batch) => {
    if (!acc.has(batch.drug_id)) acc.set(batch.drug_id, []);
    acc.get(batch.drug_id).push(batch);
    return acc;
  }, new Map());

  return drugs.map((drug) => ({
    ...drug,
    ...buildPrimaryBatchStorageSummary(batchesByDrugId.get(drug.id) || []),
  }));
};

const getPharmacyStorageLayout = async (filters = {}, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const facilityId =
    filters.facility_id ||
    scope.facility_id ||
    (await resolveIdentifierForPayload({
      value: null,
      field: 'facility_id',
      model: 'facility',
      where: { deleted_at: null, ...buildTenantScopeWhere(scope) },
      allowNull: true,
    }));

  if (!facilityId) {
    return { rooms: [], summary: { room_count: 0, shelf_count: 0 } };
  }

  const includeInactive = filters.include_inactive === true;
  const rooms = await pharmacyStorageRepository.findManyStorageRooms(
    {
      ...buildTenantScopeWhere(scope),
      facility_id: facilityId,
      ...(includeInactive ? {} : { is_active: true }),
    },
    0,
    500,
    { name: 'asc' }
  );

  const mappedRooms = rooms
    .map((room) => {
      const mapped = mapStorageRoomRecord(room);
      if (!mapped) return null;
      if (!includeInactive) {
        mapped.shelves = mapped.shelves.filter((shelf) => shelf.is_active);
      }
      return mapped;
    })
    .filter(Boolean);

  const shelfCount = mappedRooms.reduce(
    (total, room) => total + (room.shelves?.length || 0),
    0
  );

  return {
    rooms: mappedRooms,
    summary: {
      room_count: mappedRooms.length,
      shelf_count: shelfCount,
    },
  };
};

const createPharmacyStorageRoom = async (payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  let tenantId = scope.tenant_id;
  if (scope.can_manage_all_tenants) {
    tenantId = await resolveIdentifierForPayload({
      value: payload.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
      where: { deleted_at: null },
    });
  }
  const facilityId = await resolveIdentifierForPayload({
    value: payload.facility_id || scope.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: { deleted_at: null, ...buildTenantScopeWhere(scope) },
  });

  const room = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txCreateStorageRoom(tx, {
      tenant_id: tenantId,
      facility_id: facilityId,
      name: String(payload.name || '').trim(),
      code: toText(payload.code) || null,
      is_active: payload.is_active !== false,
    })
  );

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'pharmacy_storage_room',
    entity_id: room.id,
    ip_address: ipAddress,
  }).catch(() => {});

  return mapStorageRoomRecord({ ...room, shelves: [] });
};

const updatePharmacyStorageRoom = async (identifier, payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const existingLookup = await pharmacyStorageRepository.findStorageRoomById(identifier, true);
  if (!existingLookup || !matchesTenantScope(existingLookup, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }
  const roomId = existingLookup.id;

  const updated = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txUpdateStorageRoom(tx, roomId, {
      ...(payload.name !== undefined ? { name: String(payload.name || '').trim() } : {}),
      ...(payload.code !== undefined ? { code: toText(payload.code) || null } : {}),
      ...(payload.is_active !== undefined ? { is_active: Boolean(payload.is_active) } : {}),
    })
  );

  createAuditLog({
    tenant_id: existingLookup.tenant_id,
    user_id: userId,
    action: 'UPDATE',
    entity: 'pharmacy_storage_room',
    entity_id: roomId,
    ip_address: ipAddress,
  }).catch(() => {});

  return mapStorageRoomRecord({ ...updated, shelves: existingLookup.shelves || [] });
};

const createPharmacyStorageShelf = async (
  roomIdentifier,
  payload = {},
  userId,
  ipAddress,
  user = {}
) => {
  const scope = resolveScopedUserContext(user);
  const room = await pharmacyStorageRepository.findStorageRoomById(roomIdentifier, true);
  if (!room || !matchesTenantScope(room, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  const shelf = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txCreateStorageShelf(tx, {
      tenant_id: room.tenant_id,
      facility_id: room.facility_id,
      storage_room_id: room.id,
      shelf_code: String(payload.shelf_code || '').trim(),
      label: toText(payload.label) || null,
      is_active: payload.is_active !== false,
    })
  );

  createAuditLog({
    tenant_id: room.tenant_id,
    user_id: userId,
    action: 'CREATE',
    entity: 'pharmacy_storage_shelf',
    entity_id: shelf.id,
    ip_address: ipAddress,
  }).catch(() => {});

  return mapStorageShelfRecord({ ...shelf, storage_room: room });
};

const updatePharmacyStorageShelf = async (identifier, payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const existing = await pharmacyStorageRepository.findStorageShelfById(identifier, true);
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  const updated = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txUpdateStorageShelf(tx, existing.id, {
      ...(payload.shelf_code !== undefined
        ? { shelf_code: String(payload.shelf_code || '').trim() }
        : {}),
      ...(payload.label !== undefined ? { label: toText(payload.label) || null } : {}),
      ...(payload.is_active !== undefined ? { is_active: Boolean(payload.is_active) } : {}),
    })
  );

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'UPDATE',
    entity: 'pharmacy_storage_shelf',
    entity_id: existing.id,
    ip_address: ipAddress,
  }).catch(() => {});

  return mapStorageShelfRecord({ ...updated, storage_room: existing.storage_room });
};

const matchesTenantScope = (record, scope) => {
  if (!record) return false;
  if (scope?.can_manage_all_tenants) return true;
  return !scope?.tenant_id || record.tenant_id === scope.tenant_id;
};

module.exports = {
  mapStorageRoomRecord,
  mapStorageShelfRecord,
  mapStorageLocationFields,
  resolveStorageAssignment,
  buildPrimaryBatchStorageSummary,
  attachDrugStorageSummaries,
  getPharmacyStorageLayout,
  createPharmacyStorageRoom,
  updatePharmacyStorageRoom,
  createPharmacyStorageShelf,
  updatePharmacyStorageShelf,
};

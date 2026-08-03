const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { resolveIdentifierForPayload } = require('@lib/identifiers/service-identifier-resolution');
const {
  checkPharmacyStorageRoomDuplicates} = require('@lib/pharmacy/pharmacy-storage-room-similarity');
const {
  checkPharmacyStorageShelfDuplicates} = require('@lib/pharmacy/pharmacy-storage-shelf-similarity');
const pharmacyStorageRepository = require('@repositories/pharmacy-workspace/pharmacy-storage.repository');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const {
  resolveScopedUserContext,
  buildTenantScopeWhere,
  resolveModelRecordOrThrow} = require('@services/pharmacy-workspace/pharmacy.shared');

const STORAGE_ROOM_SIMILARITY_LOOKUP_LIMIT = 500;
const STORAGE_SHELF_SIMILARITY_LOOKUP_LIMIT = 500;

const toText = (value) => (value == null ? '' : String(value).trim());

const toPublicIdentifier = (...candidates) => {
  for (const candidate of candidates) {
    const normalized = toText(candidate);
    if (!normalized) continue;
    if (isUuidLike(normalized)) continue;
    return normalized;
  }
  return null;
};

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
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    deleted_at: record.deleted_at || null,
    shelves: Array.isArray(record.shelves)
      ? record.shelves.map(mapStorageShelfRecord).filter(Boolean)
      : []};
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
    storage_room_label: toText(record.storage_room?.name) || null};
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
    storage_location_label: locationLabel};
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
      facility_id: facilityId}});
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
      ...(storageRoomId ? { storage_room_id: storageRoomId } : {})}});
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

const resolveDefaultStorageShelfId = async (identifier, scope, facilityId) => {
  if (!identifier) return null;
  const storageShelfId = await resolveStorageShelfId(identifier, scope, facilityId);
  const shelf = await pharmacyStorageRepository.findStorageShelfById(storageShelfId, true);
  if (!shelf || shelf.storage_room?.facility_id !== facilityId) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'default_storage_shelf_id' }]);
  }
  return storageShelfId;
};

const INTERNAL_UNLABELED_BATCH = 'UNLABELED';

const toIsoDateTime = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
};

const hasBatchIdentityMeta = (batch) => {
  if (!batch) return false;
  const batchNumber = toText(batch.batch_number);
  const labeled =
    Boolean(batchNumber) && batchNumber.toUpperCase() !== INTERNAL_UNLABELED_BATCH;
  return (
    labeled ||
    Boolean(batch.manufactured_at) ||
    Boolean(batch.expiry_date) ||
    batch.expiry_alert_lead_days != null ||
    Boolean(batch.storage_shelf_id || batch.storage_room_id)
  );
};

const pickPrimaryBatch = (batches = []) => {
  const list = Array.isArray(batches) ? batches : [];
  if (!list.length) return null;

  const withQuantity = list.filter((batch) => Number(batch.quantity || 0) > 0);
  const withMeta = list.filter(hasBatchIdentityMeta);
  const pool = withQuantity.length ? withQuantity : withMeta.length ? withMeta : list;

  const withShelf = pool.find((batch) => batch.storage_shelf_id || batch.storage_room_id);
  const dated = pool
    .filter((batch) => batch.expiry_date)
    .sort((left, right) => new Date(left.expiry_date) - new Date(right.expiry_date));

  return withShelf || dated[0] || pool[0] || null;
};

const buildPrimaryBatchStorageSummary = (batches = []) => {
  const selected = pickPrimaryBatch(batches);
  if (!selected) {
    return {
      ...mapStorageLocationFields(),
      batch_number: null,
      manufactured_at: null,
      expiry_date: null,
      next_expiry: null,
      expiry_alert_lead_days: null};
  }

  const rawBatchNumber = toText(selected.batch_number);
  const batchNumber =
    rawBatchNumber && rawBatchNumber.toUpperCase() !== INTERNAL_UNLABELED_BATCH
      ? rawBatchNumber
      : null;
  const expiryDate = toIsoDateTime(selected.expiry_date);

  return {
    ...mapStorageLocationFields(selected.storage_room, selected.storage_shelf),
    batch_number: batchNumber,
    manufactured_at: toIsoDateTime(selected.manufactured_at),
    expiry_date: expiryDate,
    next_expiry: expiryDate,
    expiry_alert_lead_days:
      selected.expiry_alert_lead_days == null
        ? null
        : Number(selected.expiry_alert_lead_days)};
};

const buildPublicIdToUuidMap = (resolvedRows = [], requestedIds = []) => {
  const map = new Map();
  for (const id of requestedIds) {
    const normalized = toText(id);
    if (!normalized) continue;
    if (isUuidLike(normalized)) {
      map.set(normalized, normalized);
    }
  }
  for (const row of resolvedRows || []) {
    if (!row?.id) continue;
    map.set(row.id, row.id);
    const friendly = toText(row.human_friendly_id);
    if (friendly) {
      map.set(friendly, row.id);
      map.set(friendly.toUpperCase(), row.id);
    }
  }
  return map;
};

const attachDrugStorageSummaries = async (drugs = []) => {
  if (!Array.isArray(drugs) || !drugs.length) return drugs;
  const drugIds = drugs.map((drug) => drug.id).filter(Boolean);
  const resolvedRows = await pharmacyStorageRepository.resolveDrugIdsByIdentifiers(drugIds);
  const publicIdToUuid = buildPublicIdToUuidMap(resolvedRows, drugIds);
  const uuidIds = Array.from(new Set(Array.from(publicIdToUuid.values()).filter(Boolean)));
  const batches = await pharmacyStorageRepository.findDrugBatchesWithStorageByDrugIds(uuidIds);
  const batchesByDrugId = batches.reduce((acc, batch) => {
    if (!acc.has(batch.drug_id)) acc.set(batch.drug_id, []);
    acc.get(batch.drug_id).push(batch);
    return acc;
  }, new Map());

  return drugs.map((drug) => {
    const uuid = publicIdToUuid.get(toText(drug.id)) || publicIdToUuid.get(toText(drug.id).toUpperCase());
    const fromBatch = buildPrimaryBatchStorageSummary(batchesByDrugId.get(uuid) || []);
    const hasBatchStorage = Boolean(fromBatch.storage_shelf_id || fromBatch.storage_room_id);
    const hasBatchIdentity =
      Boolean(fromBatch.batch_number) ||
      Boolean(fromBatch.manufactured_at) ||
      Boolean(fromBatch.expiry_date) ||
      fromBatch.expiry_alert_lead_days != null;

    if (!hasBatchStorage && !hasBatchIdentity) {
      return drug;
    }

    return {
      ...drug,
      // Prefer batch location when present; otherwise keep offering/mapped storage.
      ...(hasBatchStorage
        ? {
            storage_room_id: fromBatch.storage_room_id,
            storage_room_label: fromBatch.storage_room_label,
            storage_shelf_id: fromBatch.storage_shelf_id,
            storage_shelf_code: fromBatch.storage_shelf_code,
            storage_location_label: fromBatch.storage_location_label}
        : {}),
      ...(hasBatchIdentity
        ? {
            batch_number: fromBatch.batch_number,
            manufactured_at: fromBatch.manufactured_at,
            expiry_date: fromBatch.expiry_date,
            next_expiry: fromBatch.next_expiry,
            expiry_alert_lead_days: fromBatch.expiry_alert_lead_days}
        : {})};
  });
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
      allowNull: true}));

  if (!facilityId) {
    return { rooms: [], summary: { room_count: 0, shelf_count: 0 } };
  }

  const includeInactive = filters.include_inactive === true;
  const includeDeleted = filters.include_deleted === true;
  const rooms = await pharmacyStorageRepository.findManyStorageRooms(
    {
      ...buildTenantScopeWhere(scope),
      facility_id: facilityId,
      ...(includeInactive || includeDeleted ? {} : { is_active: true })},
    0,
    500,
    { name: 'asc' },
    {
      includeDeleted,
      includeDeletedShelves: includeDeleted}
  );

  const mappedRooms = rooms
    .map((room) => {
      const mapped = mapStorageRoomRecord(room);
      if (!mapped) return null;
      if (!includeInactive && !includeDeleted) {
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
      shelf_count: shelfCount}};
};

const stripSimilarityPayloadFields = (data = {}) => {
  const { confirm_similar: _confirmSimilar, ...payload } = data;
  return payload;
};

const assertPharmacyStorageRoomUniqueness = async ({
  name,
  code,
  facilityId,
  confirmSimilar = false,
  excludeRoomId = null}) => {
  if (!facilityId) {
    return null;
  }

  const existing = await pharmacyStorageRepository.findManyStorageRooms(
    { facility_id: facilityId },
    0,
    STORAGE_ROOM_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    { includeDeleted: false }
  );

  const duplicateCheck = checkPharmacyStorageRoomDuplicates({
    name,
    code,
    existing,
    excludeRoomId});

  if (!confirmSimilar && duplicateCheck.exactNameConflict) {
    throw new HttpError('errors.pharmacy_storage_room.duplicate_name', 409, [
      {
        field: 'name',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_name_conflict)
          .slice(0, 5)}]);
  }

  if (!confirmSimilar && duplicateCheck.exactCodeConflict) {
    throw new HttpError('errors.pharmacy_storage_room.duplicate_code', 409, [
      {
        field: 'code',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_code_conflict)
          .slice(0, 5)}]);
  }

  const reviewMatches = duplicateCheck.similarMatches
    .filter((match) => !match.is_exact)
    .slice(0, 8);

  if (!confirmSimilar && reviewMatches.length > 0) {
    throw new HttpError('errors.pharmacy_storage_room.similar_exists', 409, [
      {
        field: 'name',
        matches: reviewMatches,
        closest_score: duplicateCheck.closestScore}]);
  }

  return duplicateCheck;
};

const checkPharmacyStorageRoomSimilarity = async (payload = {}, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const facilityId = await resolveIdentifierForPayload({
    value: payload.facility_id || scope.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: { deleted_at: null, ...buildTenantScopeWhere(scope) }});

  const name = String(payload.name || '').trim();
  const code = toText(payload.code) || null;
  const excludeRoomId = toText(payload.exclude_room_id) || null;

  const existing = await pharmacyStorageRepository.findManyStorageRooms(
    {
      ...buildTenantScopeWhere(scope),
      facility_id: facilityId},
    0,
    STORAGE_ROOM_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    { includeDeleted: false }
  );

  let excludeInternalId = null;
  if (excludeRoomId) {
    const existingRoom = await pharmacyStorageRepository.findStorageRoomById(excludeRoomId, {
      includeInactive: true,
      includeDeleted: true});
    excludeInternalId = existingRoom?.id || excludeRoomId;
  }

  const duplicateCheck = checkPharmacyStorageRoomDuplicates({
    name,
    code,
    existing,
    excludeRoomId: excludeInternalId});

  return {
    exact_name_conflict: duplicateCheck.exactNameConflict,
    exact_code_conflict: duplicateCheck.exactCodeConflict,
    closest_score: duplicateCheck.closestScore,
    matches: duplicateCheck.similarMatches.slice(0, 8).map((match) => ({
      ...match,
      room: mapStorageRoomRecord({
        ...match.room,
        shelves: []}) || match.room}))};
};

const createPharmacyStorageRoom = async (payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const confirmSimilar = payload?.confirm_similar === true;
  const data = stripSimilarityPayloadFields(payload);
  const facilityId = await resolveIdentifierForPayload({
    value: data.facility_id || scope.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: { deleted_at: null, ...buildTenantScopeWhere(scope) }});

  let tenantId = scope.tenant_id;
  if (scope.can_manage_all_tenants && data.tenant_id) {
    tenantId = await resolveIdentifierForPayload({
      value: data.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
      where: { deleted_at: null }});
  }

  if (!tenantId) {
    const facility = await resolveModelRecordOrThrow({
      identifier: facilityId,
      model: 'facility',
      where: { deleted_at: null },
      select: { id: true, tenant_id: true },
      errorKey: 'errors.facility.not_found'});
    tenantId = facility.tenant_id;
  }

  if (!tenantId) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'tenant_id' }]);
  }

  const name = String(data.name || '').trim();
  const requestedCode = toText(data.code) || null;

  await assertPharmacyStorageRoomUniqueness({
    name,
    code: requestedCode,
    facilityId,
    confirmSimilar});

  if (requestedCode) {
    const collision = await pharmacyStorageRepository.findStorageRoomByCode(
      facilityId,
      requestedCode
    );
    if (collision) {
      throw new HttpError('errors.pharmacy_storage_room.duplicate_code', 409, [
        { field: 'code' }]);
    }
  }

  let room = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txCreateStorageRoom(tx, {
      tenant_id: tenantId,
      facility_id: facilityId,
      name,
      code: requestedCode,
      is_active: data.is_active !== false})
  );

  // When the caller omits code, adopt the auto-assigned HFID as the unique room code.
  if (!requestedCode) {
    const generatedCode =
      toPublicIdentifier(room.human_friendly_id, room.id) || `SR-${room.id.slice(0, 8)}`;
    room = await pharmacyWorkspaceRepository.withTransaction((tx) =>
      pharmacyStorageRepository.txUpdateStorageRoom(tx, room.id, {
        code: generatedCode})
    );
  }

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'pharmacy_storage_room',
    entity_id: room.id,
    ip_address: ipAddress}).catch(() => {});

  return mapStorageRoomRecord({ ...room, shelves: [] });
};

const updatePharmacyStorageRoom = async (identifier, payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const confirmSimilar = payload?.confirm_similar === true;
  const data = stripSimilarityPayloadFields(payload);
  const existingLookup = await pharmacyStorageRepository.findStorageRoomById(identifier, true);
  if (!existingLookup || !matchesTenantScope(existingLookup, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }
  const roomId = existingLookup.id;

  const nextName =
    data.name !== undefined ? String(data.name || '').trim() : existingLookup.name;
  const nextCode =
    data.code !== undefined ? toText(data.code) || null : toText(existingLookup.code) || null;

  await assertPharmacyStorageRoomUniqueness({
    name: nextName,
    code: nextCode,
    facilityId: existingLookup.facility_id,
    confirmSimilar,
    excludeRoomId: roomId});

  if (nextCode) {
    const collision = await pharmacyStorageRepository.findStorageRoomByCode(
      existingLookup.facility_id,
      nextCode,
      { excludeRoomId: roomId }
    );
    if (collision) {
      throw new HttpError('errors.pharmacy_storage_room.duplicate_code', 409, [
        { field: 'code' }]);
    }
  }

  const updated = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txUpdateStorageRoom(tx, roomId, {
      ...(data.name !== undefined ? { name: nextName } : {}),
      ...(data.code !== undefined ? { code: nextCode } : {}),
      ...(data.is_active !== undefined ? { is_active: Boolean(data.is_active) } : {})})
  );

  createAuditLog({
    tenant_id: existingLookup.tenant_id,
    user_id: userId,
    action: 'UPDATE',
    entity: 'pharmacy_storage_room',
    entity_id: roomId,
    ip_address: ipAddress}).catch(() => {});

  return mapStorageRoomRecord({ ...updated, shelves: existingLookup.shelves || [] });
};

const assertPharmacyStorageShelfUniqueness = async ({
  label,
  shelfCode,
  storageRoomId,
  confirmSimilar = false,
  excludeShelfId = null}) => {
  if (!storageRoomId) {
    return null;
  }

  const existing = await pharmacyStorageRepository.findManyStorageShelves(
    storageRoomId,
    { includeDeleted: false },
    0,
    STORAGE_SHELF_SIMILARITY_LOOKUP_LIMIT
  );

  const duplicateCheck = checkPharmacyStorageShelfDuplicates({
    label,
    shelfCode,
    existing,
    excludeShelfId});

  if (!confirmSimilar && duplicateCheck.exactLabelConflict) {
    throw new HttpError('errors.pharmacy_storage_shelf.duplicate_label', 409, [
      {
        field: 'label',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_label_conflict)
          .slice(0, 5)}]);
  }

  if (!confirmSimilar && duplicateCheck.exactCodeConflict) {
    throw new HttpError('errors.pharmacy_storage_shelf.duplicate_code', 409, [
      {
        field: 'shelf_code',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_code_conflict)
          .slice(0, 5)}]);
  }

  const reviewMatches = duplicateCheck.similarMatches
    .filter((match) => !match.is_exact)
    .slice(0, 8);

  if (!confirmSimilar && reviewMatches.length > 0) {
    throw new HttpError('errors.pharmacy_storage_shelf.similar_exists', 409, [
      {
        field: 'label',
        matches: reviewMatches,
        closest_score: duplicateCheck.closestScore}]);
  }

  return duplicateCheck;
};

const checkPharmacyStorageShelfSimilarity = async (
  roomIdentifier,
  payload = {},
  user = {}
) => {
  const scope = resolveScopedUserContext(user);
  const roomId = roomIdentifier || payload.room_id;
  const room = await pharmacyStorageRepository.findStorageRoomById(roomId, true);
  if (!room || !matchesTenantScope(room, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  const label = String(payload.label || '').trim();
  const shelfCode = toText(payload.shelf_code) || null;
  const excludeShelfId = toText(payload.exclude_shelf_id) || null;

  const existing = await pharmacyStorageRepository.findManyStorageShelves(
    room.id,
    { includeDeleted: false },
    0,
    STORAGE_SHELF_SIMILARITY_LOOKUP_LIMIT
  );

  let excludeInternalId = null;
  if (excludeShelfId) {
    const existingShelf = await pharmacyStorageRepository.findStorageShelfById(
      excludeShelfId,
      true
    );
    excludeInternalId = existingShelf?.id || excludeShelfId;
  }

  const duplicateCheck = checkPharmacyStorageShelfDuplicates({
    label,
    shelfCode,
    existing,
    excludeShelfId: excludeInternalId});

  return {
    exact_label_conflict: duplicateCheck.exactLabelConflict,
    exact_code_conflict: duplicateCheck.exactCodeConflict,
    closest_score: duplicateCheck.closestScore,
    matches: duplicateCheck.similarMatches.slice(0, 8).map((match) => ({
      ...match,
      shelf: mapStorageShelfRecord({
        ...match.shelf,
        storage_room: room}) || match.shelf}))};
};

const createPharmacyStorageShelf = async (
  roomIdentifier,
  payload = {},
  userId,
  ipAddress,
  user = {}
) => {
  const scope = resolveScopedUserContext(user);
  const confirmSimilar = payload?.confirm_similar === true;
  const data = stripSimilarityPayloadFields(payload);
  const room = await pharmacyStorageRepository.findStorageRoomById(roomIdentifier, true);
  if (!room || !matchesTenantScope(room, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  const label = String(data.label || '').trim();
  if (!label) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'label' }]);
  }
  const requestedCode = toText(data.shelf_code) || null;

  await assertPharmacyStorageShelfUniqueness({
    label,
    shelfCode: requestedCode,
    storageRoomId: room.id,
    confirmSimilar});

  if (requestedCode) {
    const collision = await pharmacyStorageRepository.findStorageShelfByCode(
      room.id,
      requestedCode
    );
    if (collision) {
      throw new HttpError('errors.pharmacy_storage_shelf.duplicate_code', 409, [
        { field: 'shelf_code' }]);
    }
  }

  let shelf = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txCreateStorageShelf(tx, {
      tenant_id: room.tenant_id,
      facility_id: room.facility_id,
      storage_room_id: room.id,
      // shelf_code is NOT NULL; use a temp unique value when auto-generating.
      shelf_code:
        requestedCode ||
        `TMP-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`,
      label,
      is_active: data.is_active !== false})
  );

  if (!requestedCode) {
    const generatedCode =
      toPublicIdentifier(shelf.human_friendly_id, shelf.id) ||
      `SH-${shelf.id.slice(0, 8)}`;
    shelf = await pharmacyWorkspaceRepository.withTransaction((tx) =>
      pharmacyStorageRepository.txUpdateStorageShelf(tx, shelf.id, {
        shelf_code: generatedCode})
    );
  }

  createAuditLog({
    tenant_id: room.tenant_id,
    user_id: userId,
    action: 'CREATE',
    entity: 'pharmacy_storage_shelf',
    entity_id: shelf.id,
    ip_address: ipAddress}).catch(() => {});

  return mapStorageShelfRecord({ ...shelf, storage_room: room });
};

const updatePharmacyStorageShelf = async (identifier, payload = {}, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const confirmSimilar = payload?.confirm_similar === true;
  const data = stripSimilarityPayloadFields(payload);
  const existing = await pharmacyStorageRepository.findStorageShelfById(identifier, true);
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  const nextLabel =
    data.label !== undefined ? String(data.label || '').trim() : toText(existing.label);
  if (!nextLabel) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'label' }]);
  }
  const nextCode =
    data.shelf_code !== undefined
      ? toText(data.shelf_code) || null
      : toText(existing.shelf_code) || null;

  await assertPharmacyStorageShelfUniqueness({
    label: nextLabel,
    shelfCode: nextCode,
    storageRoomId: existing.storage_room_id,
    confirmSimilar,
    excludeShelfId: existing.id});

  if (nextCode) {
    const collision = await pharmacyStorageRepository.findStorageShelfByCode(
      existing.storage_room_id,
      nextCode,
      { excludeShelfId: existing.id }
    );
    if (collision) {
      throw new HttpError('errors.pharmacy_storage_shelf.duplicate_code', 409, [
        { field: 'shelf_code' }]);
    }
  }

  const updated = await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txUpdateStorageShelf(tx, existing.id, {
      ...(data.shelf_code !== undefined ? { shelf_code: nextCode } : {}),
      ...(data.label !== undefined ? { label: nextLabel } : {}),
      ...(data.is_active !== undefined ? { is_active: Boolean(data.is_active) } : {})})
  );

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'UPDATE',
    entity: 'pharmacy_storage_shelf',
    entity_id: existing.id,
    ip_address: ipAddress}).catch(() => {});

  return mapStorageShelfRecord({ ...updated, storage_room: existing.storage_room });
};

const deletePharmacyStorageRoom = async (identifier, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const existing = await pharmacyStorageRepository.findStorageRoomById(identifier, true);
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }
  const roomId = existing.id;

  await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
    await pharmacyStorageRepository.txSoftDeleteShelvesForRoom(tx, roomId);
    await pharmacyStorageRepository.txSoftDeleteStorageRoom(tx, roomId);
  });

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'DELETE',
    entity: 'pharmacy_storage_room',
    entity_id: roomId,
    ip_address: ipAddress}).catch(() => {});

  return { id: toPublicIdentifier(existing.human_friendly_id, existing.id), deleted: true };
};

const restorePharmacyStorageRoom = async (identifier, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const existing = await pharmacyStorageRepository.findStorageRoomById(identifier, {
    includeInactive: true,
    includeDeleted: true,
    includeDeletedShelves: true});
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }
  if (!existing.deleted_at) {
    throw new HttpError('errors.pharmacy_storage_room.restore_requires_soft_delete', 400);
  }

  const restored = await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
    await pharmacyStorageRepository.txRestoreShelvesForRoom(tx, existing.id);
    return pharmacyStorageRepository.txRestoreStorageRoom(tx, existing.id);
  });

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'RESTORE',
    entity: 'pharmacy_storage_room',
    entity_id: existing.id,
    ip_address: ipAddress}).catch(() => {});

  const fresh = await pharmacyStorageRepository.findStorageRoomById(existing.id, true);
  return mapStorageRoomRecord(fresh || { ...restored, shelves: existing.shelves || [] });
};

const permanentDeletePharmacyStorageRoom = async (
  identifier,
  userId,
  ipAddress,
  user = {}
) => {
  const scope = resolveScopedUserContext(user);
  const existing = await pharmacyStorageRepository.findStorageRoomById(identifier, {
    includeInactive: true,
    includeDeleted: true,
    includeDeletedShelves: true});
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }
  if (!existing.deleted_at) {
    throw new HttpError(
      'errors.pharmacy_storage_room.permanent_delete_requires_soft_delete',
      400
    );
  }

  // Batches reference storage via nullable FKs (ON DELETE SET NULL). Clear them
  // explicitly first, then hard-delete shelves and the room.
  await pharmacyWorkspaceRepository.withTransaction(async (tx) => {
    await pharmacyStorageRepository.txClearBatchStorageForRoom(tx, existing.id);
    await pharmacyStorageRepository.txHardDeleteShelvesForRoom(tx, existing.id);
    await pharmacyStorageRepository.txHardDeleteStorageRoom(tx, existing.id);
  });

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'PERMANENT_DELETE',
    entity: 'pharmacy_storage_room',
    entity_id: existing.id,
    ip_address: ipAddress}).catch(() => {});

  return {
    id: toPublicIdentifier(existing.human_friendly_id, existing.id),
    permanently_deleted: true};
};

const deletePharmacyStorageShelf = async (identifier, userId, ipAddress, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const existing = await pharmacyStorageRepository.findStorageShelfById(identifier, true);
  if (!existing || !matchesTenantScope(existing, scope)) {
    throw new HttpError('errors.resource.not_found', 404);
  }

  await pharmacyWorkspaceRepository.withTransaction((tx) =>
    pharmacyStorageRepository.txSoftDeleteStorageShelf(tx, existing.id)
  );

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: userId,
    action: 'DELETE',
    entity: 'pharmacy_storage_shelf',
    entity_id: existing.id,
    ip_address: ipAddress}).catch(() => {});

  return { id: toPublicIdentifier(existing.human_friendly_id, existing.id), deleted: true };
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
  resolveDefaultStorageShelfId,
  buildPrimaryBatchStorageSummary,
  attachDrugStorageSummaries,
  getPharmacyStorageLayout,
  checkPharmacyStorageRoomSimilarity,
  checkPharmacyStorageShelfSimilarity,
  createPharmacyStorageRoom,
  updatePharmacyStorageRoom,
  createPharmacyStorageShelf,
  updatePharmacyStorageShelf,
  deletePharmacyStorageRoom,
  restorePharmacyStorageRoom,
  permanentDeletePharmacyStorageRoom,
  deletePharmacyStorageShelf};

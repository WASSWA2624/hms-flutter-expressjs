const staffAvailabilityRepository = require('@repositories/staff-availability/staff-availability.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const {
  normalizeSlotList,
  slotsOverlap} = require('../lib/availability-slots');
const {
  serializeStaffAvailability,
  serializeStaffAvailabilityList} = require('../lib/staff-availability.serializer');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1};
};

const normalizeTimeSlotsPayload = (data = {}) => {
  const payload = { ...data };
  const timeSlots = Array.isArray(payload.time_slots)
    ? normalizeSlotList(payload.time_slots)
    : null;

  if (timeSlots?.length) {
    if (slotsOverlap(timeSlots)) {
      throw new HttpError('errors.validation.failed', 400, [{
        field: 'time_slots',
        message: 'Time slots on the same day must not overlap'}]);
    }

    payload.start_time = timeSlots[0].start_time;
    payload.end_time = timeSlots[0].end_time;
    payload.time_slots_json = timeSlots;
  } else if (payload.start_time && payload.end_time) {
    payload.time_slots_json = normalizeSlotList([
      {
        start_time: String(payload.start_time).trim(),
        end_time: String(payload.end_time).trim()}]);
    payload.start_time = payload.time_slots_json[0]?.start_time;
    payload.end_time = payload.time_slots_json[0]?.end_time;
  }

  payload.status = payload.status || payload.preference || 'AVAILABLE';
  delete payload.time_slots;
  delete payload.days;
  return payload;
};

const emptyResult = (page, limit) => ({
  items: [],
  pagination: buildPagination(page, limit, 0)});

const list = async (filters, page, limit, sortBy, order) => {
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order } : { effective_from: 'desc' };
  const whereClause = {};

  const staffProfileId = await resolveIdentifierForFilter({
    value: filters.staff_profile_id,
    model: 'staff_profile',
    where: { deleted_at: null }});
  if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
  if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

  if (filters.day_of_week !== undefined) whereClause.day_of_week = parseInt(filters.day_of_week, 10);
  if (filters.preference) whereClause.preference = filters.preference;
  if (filters.status) whereClause.status = filters.status;

  const [items, total] = await Promise.all([
    staffAvailabilityRepository.findMany(whereClause, skip, limit, orderBy),
    staffAvailabilityRepository.count(whereClause)]);
  return {
    items: serializeStaffAvailabilityList(items),
    pagination: buildPagination(page, limit, total)};
};

const getById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null }});
  const item = await staffAvailabilityRepository.findById(resolvedId);
  if (!item) throw new HttpError('errors.staff_availability.not_found', 404);
  return serializeStaffAvailability(item);
};

const create = async (data, userId, ipAddress) => {
  const payload = {
    ...normalizeTimeSlotsPayload(data),
    staff_profile_id: await resolveIdentifierForPayload({
      value: data.staff_profile_id,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null }})};

  const item = await staffAvailabilityRepository.create(payload);
  createAuditLog({
    user_id: userId,
    action: 'CREATE',
    entity: 'staff_availability',
    entity_id: item.id,
    diff: { after: item },
    ip_address: ipAddress}).catch(() => {});
  return serializeStaffAvailability(item);
};

const createBatch = async (data, userId, ipAddress) => {
  const staffProfileId = await resolveIdentifierForPayload({
    value: data.staff_profile_id,
    model: 'staff_profile',
    field: 'staff_profile_id',
    where: { deleted_at: null }});

  const sharedFields = {
    staff_profile_id: staffProfileId,
    preference: data.preference || 'AVAILABLE',
    status: data.status || data.preference || 'AVAILABLE',
    effective_from: data.effective_from,
    effective_to: data.effective_to ?? null};

  const createdItems = [];
  for (const day of data.days) {
    const item = await staffAvailabilityRepository.create(
      normalizeTimeSlotsPayload({
        ...sharedFields,
        day_of_week: day.day_of_week,
        time_slots: day.time_slots})
    );
    createdItems.push(item);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_availability',
      entity_id: item.id,
      diff: { after: item },
      ip_address: ipAddress}).catch(() => {});
  }

  return serializeStaffAvailabilityList(createdItems);
};

const update = async (id, data, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null }});
  const before = await staffAvailabilityRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.staff_availability.not_found', 404);
  const item = await staffAvailabilityRepository.update(before.id, normalizeTimeSlotsPayload(data));
  createAuditLog({
    user_id: userId,
    action: 'UPDATE',
    entity: 'staff_availability',
    entity_id: before.id,
    diff: { before, after: item },
    ip_address: ipAddress}).catch(() => {});
  return serializeStaffAvailability(item);
};

const remove = async (id, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null }});
  const before = await staffAvailabilityRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.staff_availability.not_found', 404);
  await staffAvailabilityRepository.softDelete(before.id);
  createAuditLog({
    user_id: userId,
    action: 'DELETE',
    entity: 'staff_availability',
    entity_id: before.id,
    diff: { before },
    ip_address: ipAddress}).catch(() => {});
};

module.exports = { list, getById, create, createBatch, update, remove };

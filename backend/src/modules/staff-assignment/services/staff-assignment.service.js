const staffAssignmentRepository = require('@repositories/staff-assignment/staff-assignment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { syncStaffProfilePrimaryDepartment } = require('@lib/hr/staff-department-sync');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
  resolvePublicIdentifier} = require('@lib/billing/identifiers');

const STAFF_ASSIGNMENT_INCLUDE = {
  department: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      short_name: true}},
  unit: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true}},
  room: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true}},
  staff_profile: {
    select: {
      id: true,
      human_friendly_id: true,
      staff_number: true,
      tenant_id: true}}};

const mapStaffAssignmentForDisplay = (record) => {
  if (!record || typeof record !== 'object') {
    return record;
  }

  return {
    ...record,
    display_id: resolvePublicIdentifier(
      record?.display_id,
      record?.human_friendly_id,
      record?.id
    ),
    department_display_id: resolvePublicIdentifier(
      record?.department_display_id,
      record?.department?.human_friendly_id,
      record?.department_id
    ),
    staff_profile_display_id: resolvePublicIdentifier(
      record?.staff_profile_display_id,
      record?.staff_profile?.human_friendly_id,
      record?.staff_profile?.staff_number,
      record?.staff_profile_id
    ),
    tenant_id: record?.staff_profile?.tenant_id || record?.tenant_id || null};
};

const mapStaffAssignmentsForDisplay = (records = []) =>
  records.map(mapStaffAssignmentForDisplay);

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

const emptyResult = (page, limit) => ({
  staffAssignments: [],
  pagination: buildPagination(page, limit, 0)});

const resolveCreatePayload = async (data = {}) => ({
  ...data,
  staff_profile_id: await resolveIdentifierForPayload({
    value: data.staff_profile_id,
    model: 'staff_profile',
    field: 'staff_profile_id',
    where: { deleted_at: null }}),
  department_id: await resolveIdentifierForPayload({
    value: data.department_id,
    model: 'department',
    field: 'department_id',
    where: { deleted_at: null },
    nullable: true}),
  unit_id: await resolveIdentifierForPayload({
    value: data.unit_id,
    model: 'unit',
    field: 'unit_id',
    where: { deleted_at: null },
    nullable: true}),
  room_id: await resolveIdentifierForPayload({
    value: data.room_id,
    model: 'room',
    field: 'room_id',
    where: { deleted_at: null },
    nullable: true})});

const persistStaffAssignment = async (payload, userId, ipAddress) => {
  const staffAssignment = await staffAssignmentRepository.create(payload);
  await syncStaffProfilePrimaryDepartment(payload.staff_profile_id);
  const withRelations = await staffAssignmentRepository.findById(
    staffAssignment.id,
    STAFF_ASSIGNMENT_INCLUDE
  );
  createAuditLog({
    user_id: userId,
    action: 'CREATE',
    entity: 'staff_assignment',
    entity_id: staffAssignment.id,
    diff: { after: staffAssignment },
    ip_address: ipAddress}).catch(() => {});
  return mapStaffAssignmentForDisplay(withRelations || staffAssignment);
};

const listStaffAssignments = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const staffProfileId = await resolveIdentifierForFilter({
      value: filters.staff_profile_id,
      model: 'staff_profile',
      where: { deleted_at: null }});
    if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
    if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null }});
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    const unitId = await resolveIdentifierForFilter({
      value: filters.unit_id,
      model: 'unit',
      where: { deleted_at: null }});
    if (filters.unit_id && unitId === null) return emptyResult(page, limit);
    if (unitId) whereClause.unit_id = unitId;

    const roomId = await resolveIdentifierForFilter({
      value: filters.room_id,
      model: 'room',
      where: { deleted_at: null }});
    if (filters.room_id && roomId === null) return emptyResult(page, limit);
    if (roomId) whereClause.room_id = roomId;

    const [staffAssignments, total] = await Promise.all([
      staffAssignmentRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        STAFF_ASSIGNMENT_INCLUDE
      ),
      staffAssignmentRepository.count(whereClause)]);

    return {
      staffAssignments: mapStaffAssignmentsForDisplay(staffAssignments),
      pagination: buildPagination(page, limit, total)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getStaffAssignmentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const staffAssignment = await staffAssignmentRepository.findById(
      resolvedId,
      STAFF_ASSIGNMENT_INCLUDE
    );
    if (!staffAssignment) throw new HttpError('errors.staff_assignment.not_found', 404);
    return mapStaffAssignmentForDisplay(staffAssignment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createStaffAssignment = async (data, userId, ipAddress) => {
  try {
    const roomIds = Array.isArray(data.room_ids)
      ? data.room_ids.filter((entry) => String(entry || '').trim())
      : [];
    const baseData = { ...data };
    delete baseData.room_ids;

    const resolvedBase = await resolveCreatePayload(baseData);

    if (roomIds.length > 0) {
      const assignments = [];
      for (const roomIdentifier of roomIds) {
        const roomId = await resolveIdentifierForPayload({
          value: roomIdentifier,
          model: 'room',
          field: 'room_id',
          where: { deleted_at: null },
          nullable: true});
        const assignment = await persistStaffAssignment(
          {
            ...resolvedBase,
            room_id: roomId},
          userId,
          ipAddress
        );
        assignments.push(assignment);
      }

      return assignments.length === 1
        ? assignments[0]
        : {
            assignments,
            count: assignments.length};
    }

    return persistStaffAssignment(resolvedBase, userId, ipAddress);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateStaffAssignment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const before = await staffAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_assignment.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true});
    }
    if (Object.prototype.hasOwnProperty.call(data, 'unit_id')) {
      payload.unit_id = await resolveIdentifierForPayload({
        value: data.unit_id,
        model: 'unit',
        field: 'unit_id',
        where: { deleted_at: null },
        nullable: true});
    }
    if (Object.prototype.hasOwnProperty.call(data, 'room_id')) {
      payload.room_id = await resolveIdentifierForPayload({
        value: data.room_id,
        model: 'room',
        field: 'room_id',
        where: { deleted_at: null },
        nullable: true});
    }

    const staffAssignment = await staffAssignmentRepository.update(before.id, payload);
    await syncStaffProfilePrimaryDepartment(before.staff_profile_id);
    const withRelations = await staffAssignmentRepository.findById(
      staffAssignment.id,
      STAFF_ASSIGNMENT_INCLUDE
    );
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_assignment',
      entity_id: staffAssignment.id,
      diff: { before, after: staffAssignment },
      ip_address: ipAddress}).catch(() => {});
    return mapStaffAssignmentForDisplay(withRelations || staffAssignment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteStaffAssignment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const before = await staffAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_assignment.not_found', 404);

    await staffAssignmentRepository.softDelete(before.id);
    await syncStaffProfilePrimaryDepartment(before.staff_profile_id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_assignment',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listStaffAssignments,
  getStaffAssignmentById,
  createStaffAssignment,
  updateStaffAssignment,
  deleteStaffAssignment};

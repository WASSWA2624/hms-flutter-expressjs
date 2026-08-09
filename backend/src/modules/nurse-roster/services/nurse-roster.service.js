const nurseRosterRepository = require('@repositories/nurse-roster/nurse-roster.repository');
const shiftRepository = require('@repositories/shift/shift.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { generateRosterAssignments } = require('@services/hr-workspace/hr-roster-engine');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const prisma = require('@prisma/client');

const WEEKDAY_TO_UTC_DAY = {
  SUN: 0,
  MON: 1,
  TUE: 2,
  WED: 3,
  THU: 4,
  FRI: 5,
  SAT: 6,
};

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
  rosters: [],
  pagination: buildPagination(page, limit, 0)});

const toDateKey = (value) => {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
};

const parseTimeParts = (value, fallbackHour, fallbackMinute) => {
  const match = String(value || '').match(/^(\d{2}):(\d{2})$/);
  if (!match) {
    return { hour: fallbackHour, minute: fallbackMinute };
  }
  return {
    hour: Number(match[1]),
    minute: Number(match[2]),
  };
};

const overlaps = (leftStart, leftEnd, rightStart, rightEnd) => {
  const aStart = new Date(leftStart).getTime();
  const aEnd = new Date(leftEnd).getTime();
  const bStart = new Date(rightStart).getTime();
  const bEnd = new Date(rightEnd).getTime();
  if ([aStart, aEnd, bStart, bEnd].some((value) => Number.isNaN(value))) {
    return false;
  }
  return aStart < bEnd && bStart < aEnd;
};

const normalizeConstraints = (constraints = {}) => {
  const source = constraints && typeof constraints === 'object' ? constraints : {};
  return {
    ...source,
    respect_public_holidays: source.respect_public_holidays !== false,
    public_holidays: Array.isArray(source.public_holidays)
      ? source.public_holidays.map(String)
      : [],
    working_days: Array.isArray(source.working_days) && source.working_days.length
      ? source.working_days.map((day) => String(day).toUpperCase())
      : ['MON', 'TUE', 'WED', 'THU', 'FRI'],
    default_start_time: source.default_start_time || '08:00',
    default_end_time: source.default_end_time || '17:00',
    attached_staff_ids: Array.isArray(source.attached_staff_ids)
      ? [...new Set(source.attached_staff_ids.map(String))]
      : [],
    shift_type: source.shift_type || 'DAY',
  };
};

const materializeRosterShifts = async (roster) => {
  const constraints = normalizeConstraints(roster.constraints);
  const holidaySet = new Set(constraints.public_holidays);
  const allowedDays = new Set(
    constraints.working_days
      .map((day) => WEEKDAY_TO_UTC_DAY[day])
      .filter((day) => day !== undefined)
  );
  const startParts = parseTimeParts(constraints.default_start_time, 8, 0);
  const endParts = parseTimeParts(constraints.default_end_time, 17, 0);

  const cursor = new Date(roster.period_start);
  cursor.setUTCHours(0, 0, 0, 0);
  const end = new Date(roster.period_end);
  end.setUTCHours(23, 59, 59, 999);

  const created = [];
  while (cursor <= end) {
    const dateKey = toDateKey(cursor);
    const isHoliday = holidaySet.has(dateKey);
    const isWorkingDay = allowedDays.has(cursor.getUTCDay());
    const skipHoliday = constraints.respect_public_holidays && isHoliday;

    if (isWorkingDay && !skipHoliday && dateKey) {
      const startTime = new Date(Date.UTC(
        cursor.getUTCFullYear(),
        cursor.getUTCMonth(),
        cursor.getUTCDate(),
        startParts.hour,
        startParts.minute,
        0,
        0
      ));
      let endTime = new Date(Date.UTC(
        cursor.getUTCFullYear(),
        cursor.getUTCMonth(),
        cursor.getUTCDate(),
        endParts.hour,
        endParts.minute,
        0,
        0
      ));
      if (endTime <= startTime) {
        endTime = new Date(endTime.getTime() + 24 * 60 * 60 * 1000);
      }

      const shift = await shiftRepository.create({
        tenant_id: roster.tenant_id,
        facility_id: roster.facility_id || null,
        nurse_roster_id: roster.id,
        shift_type: constraints.shift_type,
        status: 'SCHEDULED',
        start_time: startTime,
        end_time: endTime,
      });
      created.push(shift);
    }

    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return created;
};

const mapAttachedStaff = async (roster) => {
  const constraints = normalizeConstraints(roster.constraints);
  const attachedIds = new Set(constraints.attached_staff_ids);
  const assignmentStaff = new Map();

  const staffDisplayName = (profile = {}) => {
    const userProfile = profile.user?.profile;
    const parts = [userProfile?.first_name, userProfile?.last_name]
      .map((part) => (part || '').trim())
      .filter(Boolean);
    if (parts.length) return parts.join(' ');
    return profile.user?.email || profile.staff_number || null;
  };

  for (const shift of roster.shifts || []) {
    for (const assignment of shift.assignments || []) {
      if (!assignment?.staff_profile_id) continue;
      const profile = assignment.staff_profile || {};
      assignmentStaff.set(assignment.staff_profile_id, {
        staff_profile_id: assignment.staff_profile_id,
        display_id: profile.human_friendly_id || assignment.staff_profile_id,
        staff_number: profile.staff_number || null,
        name: staffDisplayName(profile),
        source: 'assignment',
        assignment_id: assignment.id,
        shift_id: shift.id,
      });
      attachedIds.add(assignment.staff_profile_id);
    }
  }

  const missingIds = [...attachedIds].filter((id) => !assignmentStaff.has(id));
  if (missingIds.length) {
    const profiles = await prisma.staff_profile.findMany({
      where: {
        deleted_at: null,
        OR: [
          { id: { in: missingIds } },
          { human_friendly_id: { in: missingIds } },
        ],
      },
      include: {
        user: {
          include: {
            profile: true,
          },
        },
      },
    });
    for (const profile of profiles) {
      assignmentStaff.set(profile.id, {
        staff_profile_id: profile.id,
        display_id: profile.human_friendly_id || profile.id,
        staff_number: profile.staff_number || null,
        name: staffDisplayName(profile),
        source: 'attached',
        assignment_id: null,
        shift_id: null,
      });
    }
  }

  return [...assignmentStaff.values()];
};

const assertNoScheduleConflict = async ({
  staffProfileId,
  periodStart,
  periodEnd,
  excludeRosterId = null,
}) => {
  const overlapping = await prisma.shift_assignment.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: staffProfileId,
      shift: {
        deleted_at: null,
        ...(excludeRosterId
          ? { NOT: { nurse_roster_id: excludeRosterId } }
          : {}),
        start_time: { lt: periodEnd },
        end_time: { gt: periodStart },
      },
    },
    take: 1,
    include: {
      shift: {
        select: {
          id: true,
          human_friendly_id: true,
          start_time: true,
          end_time: true,
          nurse_roster_id: true,
        },
      },
    },
  });

  if (overlapping.length) {
    throw new HttpError('errors.nurse_roster.staff_schedule_conflict', 409, [
      {
        staff_profile_id: staffProfileId,
        conflicting_shift_id: overlapping[0].shift?.human_friendly_id || overlapping[0].shift_id,
      },
    ]);
  }
};

const listNurseRosters = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null }});
    if (filters.tenant_id && tenantId === null) return emptyResult(page, limit);
    if (tenantId) whereClause.tenant_id = tenantId;

    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: { deleted_at: null }});
    if (filters.facility_id && facilityId === null) return emptyResult(page, limit);
    if (facilityId) whereClause.facility_id = facilityId;

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null }});
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    if (filters.status) whereClause.status = filters.status;
    if (filters.period_start_from || filters.period_start_to) {
      whereClause.period_start = {};
      if (filters.period_start_from) whereClause.period_start.gte = new Date(filters.period_start_from);
      if (filters.period_start_to) whereClause.period_start.lte = new Date(filters.period_start_to);
    }

    const [rosters, total] = await Promise.all([
      nurseRosterRepository.findMany(whereClause, skip, limit, orderBy, {
        shifts: {
          where: { deleted_at: null },
          select: {
            id: true,
            assignments: {
              where: { deleted_at: null },
              select: { staff_profile_id: true },
            },
          },
        },
      }),
      nurseRosterRepository.count(whereClause)]);

    return {
      rosters,
      pagination: buildPagination(page, limit, total)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getNurseRosterById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const roster = await nurseRosterRepository.findById(resolvedId, {
      shifts: {
        where: { deleted_at: null },
        include: {
          assignments: {
            where: { deleted_at: null },
            include: {
              staff_profile: {
                include: {
                  user: {
                    include: {
                      profile: true,
                    },
                  },
                },
              },
            },
          },
        },
      },
    });
    if (!roster) throw new HttpError('errors.nurse_roster.not_found', 404);
    const staff = await mapAttachedStaff(roster);
    return {
      ...roster,
      staff,
      assignment_count: staff.length,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createNurseRoster = async (data, userId, ipAddress) => {
  try {
    const { materialize_shifts: materializeShifts = true, ...rest } = data;
    const periodStart = new Date(rest.period_start);
    const periodEnd = new Date(rest.period_end);
    const defaultName = `${toDateKey(periodStart) || 'roster'} – ${toDateKey(periodEnd) || ''}`.trim();
    const payload = {
      ...rest,
      name: (rest.name && String(rest.name).trim()) || defaultName,
      is_recurring: Boolean(rest.is_recurring),
      constraints: normalizeConstraints(rest.constraints),
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
        nullable: true})};

    delete payload.materialize_shifts;

    const roster = await nurseRosterRepository.create(payload);
    let shifts = [];
    if (materializeShifts !== false) {
      shifts = await materializeRosterShifts(roster);
    }

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { after: roster, metadata: { shifts_created: shifts.length } },
      ip_address: ipAddress}).catch(() => {});
    return {
      ...roster,
      shifts_created: shifts.length,
      assignment_count: normalizeConstraints(roster.constraints).attached_staff_ids.length,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateNurseRoster = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);

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
    if (Object.prototype.hasOwnProperty.call(data, 'constraints')) {
      payload.constraints = normalizeConstraints({
        ...(before.constraints || {}),
        ...(data.constraints || {}),
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'is_recurring')) {
      payload.is_recurring = Boolean(data.is_recurring);
    }
    if (Object.prototype.hasOwnProperty.call(data, 'status') && data.status === 'PUBLISHED') {
      payload.published_at = before.published_at || new Date();
    }

    const roster = await nurseRosterRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { before, after: roster },
      ip_address: ipAddress}).catch(() => {});
    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteNurseRoster = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);

    await nurseRosterRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'nurse_roster',
      entity_id: before.id,
      tenant_id: before.tenant_id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const publishNurseRoster = async (id, notifyStaff, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.nurse_roster.already_published', 400);

    const roster = await nurseRosterRepository.update(before.id, {
      status: 'PUBLISHED',
      published_at: new Date()});

    createAuditLog({
      user_id: userId,
      action: 'PUBLISH',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { before, after: roster, metadata: { notifyStaff } },
      ip_address: ipAddress}).catch(() => {});

    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const generateNurseRoster = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.nurse_roster.cannot_generate_published', 400);

    const updateData = {
      status: 'DRAFT',
      published_at: null};

    if (Object.prototype.hasOwnProperty.call(data, 'period_start')) {
      updateData.period_start = new Date(data.period_start);
    }
    if (Object.prototype.hasOwnProperty.call(data, 'period_end')) {
      updateData.period_end = new Date(data.period_end);
    }
    if (Object.prototype.hasOwnProperty.call(data, 'constraints')) {
      updateData.constraints = normalizeConstraints({
        ...(before.constraints || {}),
        ...(data.constraints || {}),
      });
    }

    const roster = await nurseRosterRepository.update(before.id, updateData);
    const generation = await generateRosterAssignments({
      rosterIdentifier: roster.id,
      constraints: Object.prototype.hasOwnProperty.call(data, 'constraints') ? data.constraints : undefined,
      replaceExistingAssignments: true,
      dryRun: false,
      userId,
      ipAddress});

    createAuditLog({
      user_id: userId,
      action: 'GENERATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before,
        after: roster,
        metadata: {
          generation_summary: generation.generation_summary,
          coverage: generation.coverage,
          unassigned_shifts: generation.unassigned_shifts}},
      ip_address: ipAddress}).catch(() => {});

    return {
      ...roster,
      generation_summary: generation.generation_summary,
      coverage: generation.coverage,
      assignments: generation.assignments,
      unassigned_shifts: generation.unassigned_shifts};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const attachRosterStaff = async (id, staffProfileIdentifier, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const roster = await nurseRosterRepository.findById(resolvedId);
    if (!roster) throw new HttpError('errors.nurse_roster.not_found', 404);

    const staffProfileId = await resolveIdentifierForPayload({
      value: staffProfileIdentifier,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null }});

    const constraints = normalizeConstraints(roster.constraints);
    if (constraints.attached_staff_ids.includes(staffProfileId)) {
      throw new HttpError('errors.nurse_roster.duplicate_staff', 409, [
        { staff_profile_id: staffProfileId },
      ]);
    }

    await assertNoScheduleConflict({
      staffProfileId,
      periodStart: roster.period_start,
      periodEnd: roster.period_end,
      excludeRosterId: roster.id,
    });

    const nextConstraints = {
      ...constraints,
      attached_staff_ids: [...constraints.attached_staff_ids, staffProfileId],
    };
    const updated = await nurseRosterRepository.update(roster.id, {
      constraints: nextConstraints,
    });

    createAuditLog({
      user_id: userId,
      action: 'ATTACH_STAFF',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before: roster,
        after: updated,
        metadata: { staff_profile_id: staffProfileId },
      },
      ip_address: ipAddress}).catch(() => {});

    return getNurseRosterById(roster.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const detachRosterStaff = async (id, staffProfileIdentifier, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null }});
    const roster = await nurseRosterRepository.findById(resolvedId, {
      shifts: {
        where: { deleted_at: null },
        include: {
          assignments: {
            where: { deleted_at: null },
          },
        },
      },
    });
    if (!roster) throw new HttpError('errors.nurse_roster.not_found', 404);

    const staffProfileId = await resolveIdentifierForPayload({
      value: staffProfileIdentifier,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null }});

    const constraints = normalizeConstraints(roster.constraints);
    const nextAttached = constraints.attached_staff_ids.filter((value) => value !== staffProfileId);

    for (const shift of roster.shifts || []) {
      for (const assignment of shift.assignments || []) {
        if (assignment.staff_profile_id === staffProfileId && !assignment.deleted_at) {
          await prisma.shift_assignment.update({
            where: { id: assignment.id },
            data: { deleted_at: new Date() },
          });
        }
      }
    }

    const updated = await nurseRosterRepository.update(roster.id, {
      constraints: {
        ...constraints,
        attached_staff_ids: nextAttached,
      },
    });

    createAuditLog({
      user_id: userId,
      action: 'DETACH_STAFF',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before: roster,
        after: updated,
        metadata: { staff_profile_id: staffProfileId },
      },
      ip_address: ipAddress}).catch(() => {});

    return getNurseRosterById(roster.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listNurseRosters,
  getNurseRosterById,
  createNurseRoster,
  updateNurseRoster,
  deleteNurseRoster,
  publishNurseRoster,
  generateNurseRoster,
  attachRosterStaff,
  detachRosterStaff,
  overlaps,
};

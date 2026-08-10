const rosterRepository = require('@repositories/roster/roster.repository');
const shiftRepository = require('@repositories/shift/shift.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { generateRosterAssignments } = require('@services/hr-workspace/hr-roster-engine');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const prisma = require('@prisma/client');
const {
  normalizeWeeklySchedule,
} = require('@modules/shift-template/lib/weekly-schedule');
const {
  checkRosterDuplicates,
  normalizeMonthDays,
} = require('@lib/roster/roster-similarity');

const WEEKDAY_TO_UTC_DAY = {
  SUN: 0,
  MON: 1,
  TUE: 2,
  WED: 3,
  THU: 4,
  FRI: 5,
  SAT: 6,
};

const UTC_DAY_TO_WEEKDAY = {
  0: 'SUN',
  1: 'MON',
  2: 'TUE',
  3: 'WED',
  4: 'THU',
  5: 'FRI',
  6: 'SAT',
};

const ROSTER_SIMILARITY_LOOKUP_LIMIT = 200;

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

const stripSimilarityPayloadFields = (data = {}) => {
  const {
    confirm_similar: _confirmSimilar,
    materialize_shifts: _materializeShifts,
    ...payload
  } = data;
  return payload;
};

const normalizeConstraints = (constraints = {}) => {
  const source = constraints && typeof constraints === 'object' ? constraints : {};
  const weeklySchedule = normalizeWeeklySchedule(source.weekly_schedule_json);
  const monthDays = normalizeMonthDays(source.month_days);
  const workingDays =
    Array.isArray(source.working_days) && source.working_days.length
      ? source.working_days.map((day) => String(day).toUpperCase())
      : weeklySchedule.length
        ? [
            ...new Set(
              weeklySchedule.map((day) => UTC_DAY_TO_WEEKDAY[day.day_of_week]).filter(Boolean)
            ),
          ]
        : ['MON', 'TUE', 'WED', 'THU', 'FRI'];

  let defaultStart = source.default_start_time || '08:00';
  let defaultEnd = source.default_end_time || '17:00';
  if (weeklySchedule.length) {
    const firstSlot = weeklySchedule[0]?.time_slots?.[0];
    if (firstSlot?.start_time) defaultStart = String(firstSlot.start_time).slice(0, 5);
    if (firstSlot?.end_time) defaultEnd = String(firstSlot.end_time).slice(0, 5);
  }

  return {
    ...source,
    respect_public_holidays: source.respect_public_holidays !== false,
    respect_weekends: source.respect_weekends !== false,
    public_holidays: Array.isArray(source.public_holidays)
      ? source.public_holidays.map(String)
      : [],
    working_days: workingDays,
    month_days: monthDays,
    weekly_schedule_json: weeklySchedule,
    default_start_time: defaultStart,
    default_end_time: defaultEnd,
    attached_staff_ids: Array.isArray(source.attached_staff_ids)
      ? [...new Set(source.attached_staff_ids.map(String))]
      : [],
    attached_staff_meta: Array.isArray(source.attached_staff_meta)
      ? source.attached_staff_meta
          .filter((entry) => entry && typeof entry === 'object' && entry.staff_profile_id)
          .map((entry) => ({
            staff_profile_id: String(entry.staff_profile_id),
            staff_category: entry.staff_category
              ? String(entry.staff_category).toUpperCase()
              : null,
            inactive: entry.inactive === true,
          }))
      : [],
    template_inactive: source.template_inactive === true,
    shift_type: source.shift_type || 'DAY',
  };
};

const setRosterTemplateInactive = (constraints = {}, inactive) => {
  const normalized = normalizeConstraints(constraints);
  return {
    ...normalized,
    template_inactive: inactive === true,
    attached_staff_meta: normalized.attached_staff_meta.map((entry) => ({
      ...entry,
      inactive: inactive === true,
    })),
  };
};

const slotsForUtcDay = (constraints, utcDay) => {
  const weekly = Array.isArray(constraints.weekly_schedule_json)
    ? constraints.weekly_schedule_json
    : [];
  const dayEntry = weekly.find((entry) => Number(entry.day_of_week) === utcDay);
  if (dayEntry?.time_slots?.length) {
    return dayEntry.time_slots
      .map((slot) => ({
        start_time: String(slot.start_time || '').slice(0, 5),
        end_time: String(slot.end_time || '').slice(0, 5),
      }))
      .filter((slot) => slot.start_time && slot.end_time);
  }

  const allowedDays = new Set(
    (constraints.working_days || [])
      .map((day) => WEEKDAY_TO_UTC_DAY[day])
      .filter((day) => day !== undefined)
  );
  if (!allowedDays.has(utcDay)) {
    return [];
  }
  return [
    {
      start_time: constraints.default_start_time || '08:00',
      end_time: constraints.default_end_time || '17:00',
    },
  ];
};

const materializeRosterShifts = async (roster) => {
  const constraints = normalizeConstraints(roster.constraints);
  const holidaySet = new Set(constraints.public_holidays);
  const monthDaySet = new Set(constraints.month_days || []);
  const restrictMonthDays = monthDaySet.size > 0;

  const cursor = new Date(roster.period_start);
  cursor.setUTCHours(0, 0, 0, 0);
  const end = new Date(roster.period_end);
  end.setUTCHours(23, 59, 59, 999);

  const created = [];
  while (cursor <= end) {
    const dateKey = toDateKey(cursor);
    const utcDay = cursor.getUTCDay();
    const dayOfMonth = cursor.getUTCDate();
    const isWeekend = utcDay === 0 || utcDay === 6;
    const isHoliday = holidaySet.has(dateKey);
    const skipHoliday = constraints.respect_public_holidays && isHoliday;
    const skipWeekend = constraints.respect_weekends && isWeekend;
    const skipMonthDay = restrictMonthDays && !monthDaySet.has(dayOfMonth);

    if (!skipHoliday && !skipWeekend && !skipMonthDay && dateKey) {
      const slots = slotsForUtcDay(constraints, utcDay);
      for (const slot of slots) {
        const startParts = parseTimeParts(slot.start_time, 8, 0);
        const endParts = parseTimeParts(slot.end_time, 17, 0);
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
          roster_id: roster.id,
          shift_type: constraints.shift_type,
          status: 'SCHEDULED',
          start_time: startTime,
          end_time: endTime,
        });
        created.push(shift);
      }
    }

    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return created;
};

const resolveStaffProfileIds = async (identifiers = []) => {
  const resolved = [];
  for (const identifier of identifiers) {
    if (identifier == null || String(identifier).trim() === '') {
      continue;
    }
    const id = await resolveIdentifierForPayload({
      value: identifier,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null },
      nullable: true,
    });
    if (id) {
      resolved.push(id);
    }
  }
  return [...new Set(resolved)];
};

const resolveAttachedStaffConstraints = async (constraints = {}) => {
  const normalized = normalizeConstraints(constraints);
  const attachedIds = await resolveStaffProfileIds(normalized.attached_staff_ids);
  const idSet = new Set(attachedIds);
  const meta = [];
  for (const entry of normalized.attached_staff_meta) {
    const resolvedId = await resolveIdentifierForPayload({
      value: entry.staff_profile_id,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null },
      nullable: true,
    });
    if (!resolvedId || !idSet.has(resolvedId)) {
      continue;
    }
    meta.push({
      ...entry,
      staff_profile_id: resolvedId,
    });
  }
  return {
    ...normalized,
    attached_staff_ids: attachedIds,
    attached_staff_meta: meta,
  };
};

const loadActiveRosterShifts = async (rosterId) => {
  return prisma.shift.findMany({
    where: {
      roster_id: rosterId,
      deleted_at: null,
    },
    select: {
      id: true,
      start_time: true,
      end_time: true,
    },
    orderBy: { start_time: 'asc' },
  });
};

/**
 * Ensures roster shifts exist, then assigns each staff member to every active
 * shift so staff-detail Rosters reflects the attachment immediately.
 */
const assignStaffToRosterShifts = async (roster, staffProfileIds, shifts = null) => {
  const ids = [...new Set((staffProfileIds || []).filter(Boolean).map(String))];
  if (!ids.length) {
    return { assignments_created: 0, shifts: shifts || [] };
  }

  let rosterShifts = Array.isArray(shifts) ? shifts : null;
  if (!rosterShifts || rosterShifts.length === 0) {
    rosterShifts = await loadActiveRosterShifts(roster.id);
  }
  if (!rosterShifts.length) {
    rosterShifts = await materializeRosterShifts(roster);
  }
  if (!rosterShifts.length) {
    return { assignments_created: 0, shifts: rosterShifts };
  }

  for (const staffProfileId of ids) {
    await assertNoScheduleConflict({
      staffProfileId,
      periodStart: roster.period_start,
      periodEnd: roster.period_end,
      excludeRosterId: roster.id,
    });
  }

  const shiftIds = rosterShifts.map((shift) => shift.id);
  const existing = await prisma.shift_assignment.findMany({
    where: {
      deleted_at: null,
      staff_profile_id: { in: ids },
      shift_id: { in: shiftIds },
    },
    select: {
      shift_id: true,
      staff_profile_id: true,
    },
  });
  const existingKeys = new Set(
    existing.map((row) => `${row.staff_profile_id}:${row.shift_id}`)
  );

  const now = new Date();
  const rows = [];
  for (const staffProfileId of ids) {
    for (const shift of rosterShifts) {
      const key = `${staffProfileId}:${shift.id}`;
      if (existingKeys.has(key)) {
        continue;
      }
      rows.push({
        shift_id: shift.id,
        staff_profile_id: staffProfileId,
        assigned_at: now,
      });
    }
  }

  if (rows.length) {
    await prisma.shift_assignment.createMany({ data: rows });
  }

  return { assignments_created: rows.length, shifts: rosterShifts };
};

const assertRosterUniqueness = async ({
  data,
  tenantId,
  facilityId = null,
  confirmSimilar = false,
  excludeRosterId = null,
}) => {
  if (!tenantId) {
    return null;
  }

  const existing = await rosterRepository.findMany(
    { tenant_id: tenantId },
    0,
    ROSTER_SIMILARITY_LOOKUP_LIMIT,
    { created_at: 'desc' }
  );

  const duplicateCheck = checkRosterDuplicates({
    name: data.name,
    facilityId,
    departmentId: data.department_id,
    isRecurring: Boolean(data.is_recurring),
    periodStart: data.period_start,
    periodEnd: data.period_end,
    constraints: data.constraints || {},
    existing,
    excludeRosterId,
  });

  if (duplicateCheck.hasFullExactDuplicate) {
    throw new HttpError('errors.roster.duplicate_name', 409, [
      {
        field: 'name',
        matches: (duplicateCheck.blockingMatches || []).slice(0, 5),
      },
    ]);
  }

  const reviewMatches = duplicateCheck.overridableMatches.slice(0, 5);
  if (reviewMatches.length > 0 && !confirmSimilar) {
    throw new HttpError('errors.roster.similar_exists', 409, [
      {
        field: 'name',
        matches: reviewMatches,
      },
    ]);
  }

  return duplicateCheck;
};

const mapAttachedStaff = async (roster) => {
  const constraints = normalizeConstraints(roster.constraints);
  const attachedIds = new Set(constraints.attached_staff_ids);
  const categoryByStaffId = new Map(
    constraints.attached_staff_meta.map((entry) => [
      entry.staff_profile_id,
      entry.staff_category,
    ])
  );
  const assignmentStaff = new Map();

  const staffDisplayName = (profile = {}) => {
    const userProfile = profile.user?.profile;
    const parts = [userProfile?.first_name, userProfile?.last_name]
      .map((part) => (part || '').trim())
      .filter(Boolean);
    if (parts.length) return parts.join(' ');
    return profile.user?.email || profile.staff_number || null;
  };

  const mapProfileFields = (profile = {}) => ({
    staff_profile_id: profile.id,
    display_id: profile.human_friendly_id || profile.id,
    staff_number: profile.staff_number || null,
    name: staffDisplayName(profile),
    position: profile.position || null,
    practitioner_type: profile.practitioner_type || null,
    staff_category: categoryByStaffId.get(profile.id) || null,
  });

  for (const shift of roster.shifts || []) {
    for (const assignment of shift.assignments || []) {
      if (!assignment?.staff_profile_id) continue;
      const profile = assignment.staff_profile || {};
      const mapped = mapProfileFields({
        ...profile,
        id: assignment.staff_profile_id,
      });
      assignmentStaff.set(assignment.staff_profile_id, {
        ...mapped,
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
        ...mapProfileFields(profile),
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
          ? { NOT: { roster_id: excludeRosterId } }
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
          roster_id: true,
        },
      },
    },
  });

  if (overlapping.length) {
    throw new HttpError('errors.roster.staff_schedule_conflict', 409, [
      {
        staff_profile_id: staffProfileId,
        conflicting_shift_id: overlapping[0].shift?.human_friendly_id || overlapping[0].shift_id,
      },
    ]);
  }
};

const listRosters = async (filters, page, limit, sortBy, order) => {
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
      rosterRepository.findMany(whereClause, skip, limit, orderBy, {
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
      rosterRepository.count(whereClause)]);

    return {
      rosters,
      pagination: buildPagination(page, limit, total)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getRosterById = async (id, { includeDeleted = false } = {}) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: includeDeleted ? {} : { deleted_at: null },
      includeDeleted,
    });
    const roster = await rosterRepository.findById(
      resolvedId,
      {
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        department: { select: { id: true, human_friendly_id: true, name: true } },
        shifts: {
          where: includeDeleted ? {} : { deleted_at: null },
          include: {
            assignments: {
              where: includeDeleted ? {} : { deleted_at: null },
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
      },
      { includeDeleted }
    );
    if (!roster) throw new HttpError('errors.roster.not_found', 404);
    const staff = await mapAttachedStaff(roster);
    const periodStartKey = toDateKey(roster.period_start);
    const periodEndKey = toDateKey(roster.period_end);
    return {
      ...roster,
      period_label: periodStartKey && periodEndKey
        ? `${periodStartKey} - ${periodEndKey}`
        : null,
      facility_name: roster.facility?.name || null,
      department_name: roster.department?.name || null,
      staff,
      assignment_count: staff.length,
      is_deleted: Boolean(roster.deleted_at),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createRoster = async (data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const materializeShifts = data?.materialize_shifts !== false;
    const rest = stripSimilarityPayloadFields(data);
    const periodStart = new Date(rest.period_start);
    const periodEnd = new Date(rest.period_end);
    const defaultName = `${toDateKey(periodStart) || 'roster'} – ${toDateKey(periodEnd) || ''}`.trim();
    const payload = {
      ...rest,
      name: (rest.name && String(rest.name).trim()) || defaultName,
      is_recurring: Boolean(rest.is_recurring),
      constraints: await resolveAttachedStaffConstraints(rest.constraints),
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

    await assertRosterUniqueness({
      data: payload,
      tenantId: payload.tenant_id,
      facilityId: payload.facility_id,
      confirmSimilar,
    });

    const roster = await rosterRepository.create(payload);
    let shifts = [];
    let assignmentsCreated = 0;
    if (materializeShifts) {
      shifts = await materializeRosterShifts(roster);
    }
    const attachedIds = normalizeConstraints(roster.constraints).attached_staff_ids;
    if (attachedIds.length) {
      const assignmentResult = await assignStaffToRosterShifts(
        roster,
        attachedIds,
        shifts
      );
      shifts = assignmentResult.shifts;
      assignmentsCreated = assignmentResult.assignments_created;
    }

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        after: roster,
        metadata: {
          shifts_created: shifts.length,
          assignments_created: assignmentsCreated,
        },
      },
      ip_address: ipAddress}).catch(() => {});
    return {
      ...roster,
      shifts_created: shifts.length,
      assignment_count: attachedIds.length,
      assignments_created: assignmentsCreated,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateRoster = async (id, data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const materializeShifts = data?.materialize_shifts === true;
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await rosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.roster.not_found', 404);

    const payload = stripSimilarityPayloadFields({ ...data });
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

    const nextName = Object.prototype.hasOwnProperty.call(payload, 'name')
      ? payload.name
      : before.name;
    const nextFacilityId = Object.prototype.hasOwnProperty.call(payload, 'facility_id')
      ? payload.facility_id
      : before.facility_id;
    const nextDepartmentId = Object.prototype.hasOwnProperty.call(payload, 'department_id')
      ? payload.department_id
      : before.department_id;
    const nextIsRecurring = Object.prototype.hasOwnProperty.call(payload, 'is_recurring')
      ? payload.is_recurring
      : before.is_recurring;
    const nextPeriodStart = Object.prototype.hasOwnProperty.call(payload, 'period_start')
      ? payload.period_start
      : before.period_start;
    const nextPeriodEnd = Object.prototype.hasOwnProperty.call(payload, 'period_end')
      ? payload.period_end
      : before.period_end;
    const nextConstraints = Object.prototype.hasOwnProperty.call(payload, 'constraints')
      ? payload.constraints
      : before.constraints;

    await assertRosterUniqueness({
      data: {
        name: nextName,
        department_id: nextDepartmentId,
        is_recurring: nextIsRecurring,
        period_start: nextPeriodStart,
        period_end: nextPeriodEnd,
        constraints: nextConstraints,
      },
      tenantId: before.tenant_id,
      facilityId: nextFacilityId,
      confirmSimilar,
      excludeRosterId: before.id,
    });

    const roster = await rosterRepository.update(before.id, payload);

    let shiftsCreated = 0;
    if (materializeShifts) {
      // Soft-delete existing unassigned schedule slots for this roster before rebuild.
      await prisma.shift.updateMany({
        where: {
          roster_id: roster.id,
          deleted_at: null,
          assignments: { none: { deleted_at: null } },
        },
        data: { deleted_at: new Date() },
      });
      const shifts = await materializeRosterShifts(roster);
      shiftsCreated = shifts.length;
    }

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before,
        after: roster,
        metadata: materializeShifts ? { shifts_created: shiftsCreated } : undefined,
      },
      ip_address: ipAddress}).catch(() => {});
    return materializeShifts
      ? { ...roster, shifts_created: shiftsCreated }
      : roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteRoster = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await rosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.roster.not_found', 404);

    const inactiveConstraints = setRosterTemplateInactive(before.constraints, true);
    const result = await rosterRepository.softDelete(before.id, {
      constraints: inactiveConstraints,
    });
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'roster',
      entity_id: before.id,
      tenant_id: before.tenant_id,
      diff: {
        before,
        after: result.roster,
        metadata: {
          mode: 'soft',
          inactivated_shifts: result.inactivated_shifts,
          inactivated_assignments: result.inactivated_assignments,
          inactivated_day_offs: result.inactivated_day_offs,
        },
      },
      ip_address: ipAddress}).catch(() => {});
    return result.roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const restoreRoster = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: {},
      includeDeleted: true,
    });
    const before = await rosterRepository.findById(resolvedId, {}, { includeDeleted: true });
    if (!before || !before.deleted_at) {
      throw new HttpError('errors.roster.not_found', 404);
    }

    const activeConstraints = setRosterTemplateInactive(before.constraints, false);
    const result = await rosterRepository.restore(before.id, {
      constraints: activeConstraints,
    });
    createAuditLog({
      user_id: userId,
      action: 'RESTORE',
      entity: 'roster',
      entity_id: before.id,
      tenant_id: before.tenant_id,
      diff: {
        before,
        after: result.roster,
        metadata: {
          restored_shifts: result.restored_shifts,
          restored_assignments: result.restored_assignments,
          restored_day_offs: result.restored_day_offs,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return getRosterById(before.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const permanentDeleteRoster = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: {},
      includeDeleted: true,
    });
    const before = await rosterRepository.findById(resolvedId, {}, { includeDeleted: true });
    if (!before) throw new HttpError('errors.roster.not_found', 404);
    if (!before.deleted_at) {
      throw new HttpError('errors.roster.permanent_delete_requires_soft_delete', 400);
    }

    const result = await rosterRepository.permanentDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'PERMANENT_DELETE',
      entity: 'roster',
      entity_id: before.id,
      tenant_id: before.tenant_id,
      diff: {
        before,
        metadata: {
          removed_staff_ids: result.removed_staff_ids,
          removed_shifts: result.removed_shifts,
          removed_assignments: result.removed_assignments,
          removed_day_offs: result.removed_day_offs,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});
    return result;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const publishRoster = async (id, notifyStaff, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await rosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.roster.already_published', 400);

    const roster = await rosterRepository.update(before.id, {
      status: 'PUBLISHED',
      published_at: new Date()});

    createAuditLog({
      user_id: userId,
      action: 'PUBLISH',
      entity: 'roster',
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

const generateRoster = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const before = await rosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.roster.cannot_generate_published', 400);

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

    const roster = await rosterRepository.update(before.id, updateData);
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
      entity: 'roster',
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

const attachRosterStaff = async (id, staffProfileIdentifier, userId, ipAddress, options = {}) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const roster = await rosterRepository.findById(resolvedId);
    if (!roster) throw new HttpError('errors.roster.not_found', 404);

    const staffProfileId = await resolveIdentifierForPayload({
      value: staffProfileIdentifier,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null }});

    const constraints = normalizeConstraints(roster.constraints);
    if (constraints.attached_staff_ids.includes(staffProfileId)) {
      throw new HttpError('errors.roster.duplicate_staff', 409, [
        { staff_profile_id: staffProfileId },
      ]);
    }

    await assertNoScheduleConflict({
      staffProfileId,
      periodStart: roster.period_start,
      periodEnd: roster.period_end,
      excludeRosterId: roster.id,
    });

    const staffCategory = options.staff_category
      ? String(options.staff_category).toUpperCase()
      : null;
    const nextMeta = [
      ...constraints.attached_staff_meta.filter(
        (entry) => entry.staff_profile_id !== staffProfileId
      ),
      {
        staff_profile_id: staffProfileId,
        staff_category: staffCategory,
      },
    ];

    const nextConstraints = {
      ...constraints,
      attached_staff_ids: [...constraints.attached_staff_ids, staffProfileId],
      attached_staff_meta: nextMeta,
    };
    const updated = await rosterRepository.update(roster.id, {
      constraints: nextConstraints,
    });

    const assignmentResult = await assignStaffToRosterShifts(
      updated,
      [staffProfileId]
    );

    createAuditLog({
      user_id: userId,
      action: 'ATTACH_STAFF',
      entity: 'roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before: roster,
        after: updated,
        metadata: {
          staff_profile_id: staffProfileId,
          staff_category: staffCategory,
          assignments_created: assignmentResult.assignments_created,
        },
      },
      ip_address: ipAddress}).catch(() => {});

    return getRosterById(roster.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const detachRosterStaff = async (id, staffProfileIdentifier, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'roster',
      identifier: id,
      where: { deleted_at: null }});
    const roster = await rosterRepository.findById(resolvedId, {
      shifts: {
        where: { deleted_at: null },
        include: {
          assignments: {
            where: { deleted_at: null },
          },
        },
      },
    });
    if (!roster) throw new HttpError('errors.roster.not_found', 404);

    const staffProfileId = await resolveIdentifierForPayload({
      value: staffProfileIdentifier,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null }});

    const constraints = normalizeConstraints(roster.constraints);
    const nextAttached = constraints.attached_staff_ids.filter((value) => value !== staffProfileId);
    const nextMeta = constraints.attached_staff_meta.filter(
      (entry) => entry.staff_profile_id !== staffProfileId
    );

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

    const updated = await rosterRepository.update(roster.id, {
      constraints: {
        ...constraints,
        attached_staff_ids: nextAttached,
        attached_staff_meta: nextMeta,
      },
    });

    createAuditLog({
      user_id: userId,
      action: 'DETACH_STAFF',
      entity: 'roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before: roster,
        after: updated,
        metadata: { staff_profile_id: staffProfileId },
      },
      ip_address: ipAddress}).catch(() => {});

    return getRosterById(roster.id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listRosters,
  getRosterById,
  createRoster,
  updateRoster,
  deleteRoster,
  restoreRoster,
  permanentDeleteRoster,
  publishRoster,
  generateRoster,
  attachRosterStaff,
  detachRosterStaff,
  overlaps,
};
